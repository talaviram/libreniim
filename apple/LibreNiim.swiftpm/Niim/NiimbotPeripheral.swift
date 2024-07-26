import AsyncBluetooth
import Combine
import CoreBluetooth
import CoreGraphics
import Foundation

typealias LabelSize = CGSize

class NiimbotPeripheral: ObservableObject {

  func getConnectionState() -> CBPeripheralState {
    return peripheral.state
  }

  @Published var state = PrinterState()

  let peripheral: Peripheral
  private let characteristic: Characteristic
  private let centralManager: CentralManager

  private var responseNotifications: Set<AnyCancellable> = []
  private var response: NiimbotPacket?
  private var didTimeoutResponse = false
  private var maxSupportPacketSize = 0

  init(
    peripheral: Peripheral, characteristic: Characteristic,
    centralManager: CentralManager = CentralManager.shared
  ) {
    self.centralManager = centralManager
    self.peripheral = peripheral
    self.characteristic = characteristic
    maxSupportPacketSize = peripheral.maximumWriteValueLength(for: .withResponse)
  }

  public enum Density: UInt8, CaseIterable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
  }

  public enum Product: String, CaseIterable {
    case B1, B18, B21, D11, D110, D101, unknown

    public init?(rawValue: String) {
      if rawValue.uppercased() == "B1" {
        self = Product.B1
      } else if rawValue.uppercased() == "B18" {
        self = Product.B18
      } else if rawValue.uppercased() == "B21" {
        self = Product.B21
      } else if rawValue.uppercased() == "D11" {
        self = Product.D11
      } else if rawValue.uppercased() == "D110" {
        self = Product.D110
      } else if rawValue.uppercased() == "D101" {
        self = Product.D101

      } else {
        self = Product.unknown
      }
    }

    static func rawValues() -> [String] {
      var models: [String] = []
      for model in Product.allCases {
        models.append(model.rawValue)
      }
      return models
    }
  }

  // B21, B1, B18: max 384 pixels (almost equal to 50 mm * 8 px/mm = 400)
  // D11: max 96 pixels (almost equal to 15 mm * 8 px/mm = 120)
  static let dpi = 203  // ~203dpi
  static let defaultDensity = Density.three

  static func getEffectivePrintSizeInMillimeters(_ p: Product) -> Double {
    switch p {
    case .B1, .B18, .B21:
      return 48.0
    default:
      return 12.0
    }
  }

  // Some models print vertically (D110, etc), some horizontal (B1,..)
  static func shouldInvertCanvas(_ p: Product) -> Bool {
    switch p {
    case .B1, .B18, .B21:
      return false
    default:
      return true
    }
  }

  struct DeviceInfo {
    let model: NiimbotPeripheral.Product?
    let deviceSerial: String
    let softwareVersion: String
    let hardwareVersion: String
  }

  struct DeviceStatus {
    let batteryLevel: Int
    let paperLevel: Int
    let closingState: Int
    let rfidState: Int

    func paperCompartmentState() -> String {
      switch closingState {
      case 0:
        return "Open"
      case 1:
        return "Close"
      case -1:
        return "Unknown"
      default:
        return "\(closingState)"
      }
    }
  }

  // Niimbot has RFIDs fused to their paper rolls.
  // this seems to be for lock-in intentions.
  // (to make sure you only buy their paper rolls?)
  struct RFIDPaperRollState {
    let uuid: String
    let barcode: String
    let serial: String
    let used: Int
    let total: Int
    let type: Int
  }

  struct PrintJob {
    let data: [[NiimbotPacket]]
    let widthInPx: UInt16
    let heightInPx: UInt16
    let density = defaultDensity
    let quantity: UInt16
    let labelType = UInt8(1)
  }

  struct PrintJobStatus {
    let page: Int
    let progress: [Int]
  }

  enum Info: UInt8 {
    case DENSITY = 1
    case PRINTER_SPEED = 2
    case LABEL_TYPE = 3
    case LANGUAGE_TYPE = 6
    case AUTO_SHUTDOWN_TIME = 7
    case DEVICE_TYPE = 8
    case SW_VERSION = 9
    case BATTERY = 10
    case DEVICE_SERIAL = 11
    case HW_VERSION = 12
  }

  enum CmdType: UInt8 {
    case GET_INFO = 0x40
    case GET_RFID = 0x1A
    case HEARTBEAT = 0xDC
    case SET_LABEL_TYPE = 0x23
    case SET_LABEL_DENSITY = 0x21
    case START_PRINT = 0x1
    case END_PRINT = 0xF3
    case STATE_PAGE_PRINT = 0x3
    case END_PAGE_PRINT = 0xE3
    case ALLOW_PRINT_CLEAR = 0x20
    case SET_DIMENSION = 0x13
    case SET_QUANTITY = 0x15
    case GET_PRINT_STATUS = 0xA3
    case IMAGE_SET = 0x83
    case IMAGE_CLEAR = 132
    case IMAGE_DATA = 0x85
    case IMAGE_RECEIVED = 0xD3  // 16bit offset, byte last line
  }

  //MARK: Abstraction APIs
  func getDeviceInfo() async -> DeviceInfo {
    let model = NiimbotPeripheral.Product(
      rawValue: String(peripheral.name?.split(separator: "-").first ?? "Unknown"))
    return await DeviceInfo(
      model: model, deviceSerial: getDeviceInfoItem(key: .DEVICE_SERIAL),
      softwareVersion: getDeviceInfoItem(key: .SW_VERSION),
      hardwareVersion: getDeviceInfoItem(key: .HW_VERSION))
  }

  func heartbeat() async -> DeviceStatus {
    let packet = await command(requestCode: CmdType.HEARTBEAT, data: [0x01])
    var batteryLevel = -1
    var paperLevel = -1
    var closingState = -1
    var rfidState = -1
    guard let validPacket = packet else {
      return DeviceStatus(batteryLevel: -1, paperLevel: -1, closingState: -1, rfidState: -1)
    }
    switch validPacket.datacount {
    case 20:
      paperLevel = Int(validPacket.byteAt(pos: 18))
      rfidState = Int(validPacket.byteAt(pos: 19))
      break
    case 13:
      closingState = Int(validPacket.byteAt(pos: 9))
      batteryLevel = Int(validPacket.byteAt(pos: 10))
      paperLevel = Int(validPacket.byteAt(pos: 11))
      rfidState = Int(validPacket.byteAt(pos: 12))
      break
    case 19:
      closingState = Int(validPacket.byteAt(pos: 15))
      batteryLevel = Int(validPacket.byteAt(pos: 16))
      paperLevel = Int(validPacket.byteAt(pos: 17))
      rfidState = Int(validPacket.byteAt(pos: 18))
      break
    case 10:
      closingState = Int(validPacket.byteAt(pos: 8))
      batteryLevel = Int(validPacket.byteAt(pos: 9))
      rfidState = Int(validPacket.byteAt(pos: 8))
      break
    case 9:
      closingState = Int(validPacket.byteAt(pos: 8))
      break
    default:
      break
    }
    return DeviceStatus(
      batteryLevel: batteryLevel, paperLevel: paperLevel, closingState: closingState,
      rfidState: rfidState)
  }

  private func getDeviceInfoItem(key: Info) async -> String {
    let result = await command(
      requestCode: CmdType.GET_INFO, data: [key.rawValue], responseOffset: key.rawValue)
    guard let validResult = result else { return "Error" }
    switch key {
    case .DEVICE_SERIAL:
      return validResult.asHex()
    case .SW_VERSION:
      return Int(validResult.asInt() / 100).formatted()
    case .HW_VERSION:
      return Int(validResult.asInt() / 100).formatted()
    default:
      return Int(validResult.asInt()).formatted()
    }
  }

  func getRFIDPaperRollState() async -> RFIDPaperRollState? {
    guard let response = await command(requestCode: CmdType.GET_RFID, data: [0x01]),
      response.byteAt(pos: 0) != 0
    else {
      return nil
    }
    // TODO: sometimes I got incomplete data?
    let count = response.count
    var idx = 0
    let uuid = NiimbotPacket.convertToHex(response.bytesAt(start: idx, inclusiveEnd: idx + 8))
    idx += 8
    guard idx < count else { return nil }
    let barcodeLen = Int(response.byteAt(pos: idx))
    idx += 1
    guard idx < count else { return nil }
    let barcode = response.bytesAt(start: idx, inclusiveEnd: idx + barcodeLen)
    idx += barcodeLen
    guard idx < count else { return nil }
    let serialLen = Int(response.byteAt(pos: idx))
    idx += 1
    guard idx < count else { return nil }
    let serial = response.bytesAt(start: idx, inclusiveEnd: idx + serialLen)
    idx += serialLen
    guard idx < count else { return nil }
    let total = Int(UInt16(response.byteAt(pos: idx)) << 8 | UInt16(response.byteAt(pos: idx + 1)))
    idx += 2
    guard idx < count else { return nil }
    let used = Int(UInt16(response.byteAt(pos: idx)) << 8 | UInt16(response.byteAt(pos: idx + 1)))
    idx += 2
    guard idx < count else { return nil }
    let type = Int(response.byteAt(pos: idx))
    return RFIDPaperRollState(
      uuid: uuid, barcode: barcode.description, serial: serial.description, used: used,
      total: total, type: type)
  }

  func printLabel(_ job: PrintJob) async {
    guard state.isPrinting == false else {
      state.error = "Previous printing is still in progress?"
      return
    }
    state.isPrinting = true
    state.error = await _printLabel(job)
    state.isPrinting = false
  }

  private func _printLabel(_ job: PrintJob) async -> String? {
    state.error = ""
    guard job.data.count > 1 else { return "Unexpected print data." }
    guard
      await setModeCommand(
        requestCode: CmdType.SET_LABEL_TYPE, value: job.labelType, responseOffset: 16) == true
    else { return "Failed setting label type." }
    guard
      await setModeCommand(requestCode: CmdType.SET_LABEL_DENSITY, value: job.density.rawValue)
        == true
    else { return "Failed setting label density." }
    guard await setModeCommand(requestCode: CmdType.START_PRINT, value: 0x01) == true else {
      return "Failed starting print."
    }
    guard
      await setModeCommand(
        requestCode: CmdType.ALLOW_PRINT_CLEAR, value: job.density.rawValue, responseOffset: 16)
        == true
    else { return "Failed setting print clear." }
    guard await setModeCommand(requestCode: CmdType.STATE_PAGE_PRINT, value: 0x01) == true else {
      return "Failed setting start page."
    }
    guard
      await setModeCommand(
        requestCode: CmdType.SET_DIMENSION,
        values: job.widthInPx.toBigEndianAsUInt8() + job.heightInPx.toBigEndianAsUInt8(),
        responseOffset: 16) == true
    else { return "Failed setting dimension to \(job.widthInPx)x\(job.heightInPx) px" }
    guard await setQuantity(job.quantity) else { return "Failed setting quantity." }
    var sentPacket = 0
    for packets in job.data {
      var jumboPacket = Data()
      var sanity: [UInt8] = []
      for packet in packets {
        jumboPacket.append(contentsOf: packet.asBytes())
        sanity += packet.asBytes()
      }
      let res = await transceiveRaw(
        jumboPacket, expectedResponseType: CmdType.IMAGE_RECEIVED.rawValue)
      if res == nil {
        state.error = "Failed sending to printer!"
      } else {
        print(res.debugDescription)
      }
      sentPacket += 1
    }
    while await endPage() != true {
      try? await Task.sleep(seconds: 0.2)
    }
    await busyWaitPrintJobToEnd()
    guard await setModeCommand(requestCode: CmdType.END_PRINT, value: 0x01) == true else {
      return "End print timeout."
    }
    return ""
  }

  private func busyWaitPrintJobToEnd() async {
    while let jobStatus = await getPrintJobStatus() {
      #if DEBUG
        print("jobstatus: \(jobStatus.page) \(jobStatus.progress.description)")
      #endif
      self.state.jobStatus = jobStatus
      try? await Task.sleep(seconds: 0.2)
    }
    self.state.jobStatus = nil
  }

  private func setQuantity(_ quantity: UInt16) async -> Bool {
    return await setModeCommand(
      requestCode: CmdType.SET_QUANTITY, values: quantity.toBigEndianAsUInt8())
  }
  private func endPage() async -> Bool {
    return await setModeCommand(requestCode: CmdType.END_PAGE_PRINT, value: 0x01)
  }

  func getPrintJobStatus() async -> PrintJobStatus? {
    guard
      let res = await command(
        requestCode: CmdType.GET_PRINT_STATUS, data: [0x01], responseOffset: 16)
    else {
      return nil
    }
    let page = Int(UInt16(res.byteAt(pos: 0)) << 8 | UInt16(res.byteAt(pos: 1)))
    let start = Int(res.byteAt(pos: 2))
    let end = Int(res.byteAt(pos: 3))
    return PrintJobStatus(page: page, progress: [start, end])
  }

  //MARK: Printer I/O
  private func onResponse(_ respsone: NiimbotPacket?) {
    Task {
      do {
        try await peripheral.setNotifyValue(false, for: characteristic)
        self.response = respsone
        responseNotifications.removeAll()
      } catch {
        DispatchQueue.main.async {
          // TODO: actually use this
          self.state.error = error.localizedDescription
          print(self.state.error ?? "Missing Error?")
        }
      }
    }
  }

  private func command(requestCode: CmdType, data: [UInt8], responseOffset: UInt8 = 1) async
    -> NiimbotPacket?
  {
    let expectedResponse = responseOffset + requestCode.rawValue
    return await transceive(
      packet: NiimbotPacket(type: requestCode.rawValue, data: data),
      expectedResponseType: expectedResponse)
  }

  private func setModeCommand(requestCode: CmdType, value: UInt8, responseOffset: UInt8 = 1) async
    -> Bool
  {
    return await setModeCommand(
      requestCode: requestCode, values: [value], responseOffset: responseOffset)
  }

  private func setModeCommand(requestCode: CmdType, values: [UInt8], responseOffset: UInt8 = 1)
    async -> Bool
  {
    guard
      let res = await command(
        requestCode: requestCode, data: values, responseOffset: responseOffset)
    else { return false }
    return res.asBool()
  }

  func transceive(packet: NiimbotPacket, expectedResponseType: UInt8, chunkSize: Int = 150) async
    -> NiimbotPacket?
  {
    guard let data = packet.toData() else {
      assertionFailure("Empty Packet?")
      return nil
    }
    return await transceiveRaw(data, expectedResponseType: expectedResponseType)
  }

  func transceiveRaw(_ data: Data, expectedResponseType: UInt8, chunkSize: Int = 150) async
    -> NiimbotPacket?
  {
    guard chunkSize > 0 else {
      assertionFailure("Unexpected chunksize!")
      return nil
    }
    do {
      if peripheral.state != .connected {
        try await self.centralManager.connect(peripheral)
      }
      try await peripheral.setNotifyValue(true, for: characteristic)
      await sendPacket(data, chunkSize: chunkSize)
      guard let response = await receivePacket() else { return nil }

      return response
    } catch {
      reportError(error)
      return nil
    }
  }

  func validateResponse(_ response: NiimbotPacket?, expectedResponse: UInt8) async throws
    -> NiimbotPacket?
  {
    guard let response = response else { return nil }
    if response.responseType == NiimbotPacket.errorTypePacket {
      throw NSError(domain: "Received NiimbotPacket Error", code: NiimbotPacket.errorTypePacket)
    }
    if response.responseType == NiimbotPacket.invalidTypePacket {
      throw NSError(domain: "Received Invalid NiimbotPacket", code: NiimbotPacket.invalidTypePacket)
    }
    if response.responseType == expectedResponse {
      return response
    }
    return try? await validateResponse(await receivePacket(), expectedResponse: expectedResponse)
  }

  func sendPacket(_ data: Data, chunkSize: Int = 150) async {
    guard chunkSize > 0 && data.count > 0 else {
      assertionFailure("Chunk size and/or data must be greater than 0!")
      return
    }
    do {
      if peripheral.state != .connected {
        try await self.centralManager.connect(peripheral)
      }
      var offset = 0
      while offset < data.count {
        let remainingBytes = data.count - offset
        let chunkLength = min(chunkSize, remainingBytes)
        let chunk = data.subdata(in: offset..<offset + chunkLength)
        assert(chunkSize <= maxSupportPacketSize)
        #if DEBUG
          print("TX \(chunk.bytesString())")
        #endif
        try await peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
        offset += chunkLength
      }
    } catch {
      reportError(error)
    }
  }

  func receivePacket(timeoutInSeconds: Float = 10.0) async -> NiimbotPacket? {
    do {
      if peripheral.state != .connected {
        try await self.centralManager.connect(peripheral)
      }
      didTimeoutResponse = false
      response = nil
      #if DEBUG
        print("RX - Waiting...")
      #endif
      peripheral.characteristicValueUpdatedPublisher
        .filter { $0.uuid == self.characteristic.uuid }
        .map { try? $0.parsedValue() as NiimbotPacket? }
        .sink { response in
          self.onResponse(response)
        }
        .store(in: &responseNotifications)
      Task {
        try? await Task.sleep(seconds: timeoutInSeconds)
        didTimeoutResponse = true
        #if DEBUG
          print("RX - Timeout!")
        #endif
        throw NSError(domain: "command response timeout", code: 0)
      }
      // busy waiting
      while response == nil && !didTimeoutResponse {}
      #if DEBUG
        if response != nil {
          print("RX - \(response!.asBytes())")
        }
      #endif
      return response
    } catch {
      reportError(error)
      return nil
    }
  }

  func reportError(_ error: Error) {
    // TODO: make it better
    print("Failed \(error.localizedDescription)")
    DispatchQueue.main.async {
      self.state.error = error.localizedDescription
    }
  }

  //MARK: Utility
  static func millimetersToPixels(_ mm: CGFloat) -> Int {
    let mmInInch = 25.4
    return Int(ceil(mm / mmInInch * Double(NiimbotPeripheral.dpi)))
  }

  func disconnect() async {
    do {
      try await centralManager.cancelPeripheralConnection(peripheral)
    } catch {
      // error!
    }
  }

}

extension CBPeripheral {
  func description() -> String {
    switch self.state {
    case .connected:
      return "Connected"
    case .connecting:
      return "Connecting"
    case .disconnected:
      return "Disconnected"
    case .disconnecting:
      return "Disconnecting"
    @unknown default:
      return "Unknown"
    }
  }
}

extension Data {
  func bytesString() -> String {
    let byteArray = self.map { String(format: "%02x", $0) }
    return byteArray.joined(separator: ",")
  }
}

extension LabelSize {
  func asPixels() -> LabelSize {
    return LabelSize(
      width: NiimbotPeripheral.millimetersToPixels(self.width),
      height: NiimbotPeripheral.millimetersToPixels(self.height))
  }
}

extension UInt16 {
  func toBigEndianAsUInt8() -> [UInt8] {
    let highByte = UInt8(self >> 8)
    let lowByte = UInt8(self & 0x00ff)
    return [highByte, lowByte]
  }
}

extension Task where Success == Never, Failure == Never {
  static func sleep(seconds: Float) async throws {
    try await Task.sleep(nanoseconds: UInt64((seconds * 1_000_000_000).rounded()))
  }
}
