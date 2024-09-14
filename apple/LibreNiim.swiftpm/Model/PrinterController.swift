import AsyncBluetooth
import Combine
import Foundation
import UIKit

class PrinterController: ObservableObject {
  static let shared = PrinterController()

  var isPaired: Bool {
    return printer != nil
  }
  var isConnected: Bool {
    return printer?.getConnectionState() == .connected
  }

  var isPrinting: Bool {
    return printer?.state.isPrinting ?? false
  }

  var error: String? {
    return printer?.state.error
  }

  init() {
    #if !DEBUG
      AsyncBluetoothLogging.isEnabled = false
    #endif
  }

  func connectionState() -> String {
    return printer?.peripheral.cbPeripheral.description() ?? "Unknown"
  }

  func printStatus() -> NiimbotPeripheral.PrintJobStatus? {
    return printer?.state.jobStatus
  }

  func reconnect() {
    guard let pairedPrinter = printer, !isConnected else { return }
    // TODO: mark UI disabled?
    Task {
      do {
        try await CentralManager.shared.connect(pairedPrinter.peripheral)
      } catch {

      }
    }
  }

  func getEffectivePrintSize() -> Double {
    guard let model = deviceInfo?.model else {
      return NiimbotPeripheral.getEffectivePrintSizeInMillimeters(NiimbotPeripheral.Product.unknown)
    }
    return NiimbotPeripheral.getEffectivePrintSizeInMillimeters(model)
  }

  func tryPrint(_ image: UIImage, verticalPrint: Bool, quantity: Int = 1) {
    // TODO: avoid if no paper available!

      guard let noAlphaImage = image.replacingAlphaWithWhite() else { return }
      guard let cgImage = noAlphaImage.cgImage, let scaledImage = cgImage.rescale(by: noAlphaImage.scale)?.monochrome else {
      return
    }
    let printImage = verticalPrint ? scaledImage.roatatedBy90() : scaledImage
    let imageAsPackets = encodeImageToPackets(image: printImage!.asBitmap())
      return;
    guard printer != nil, imageAsPackets.count > 1, quantity > 0 else {
      assertionFailure("Image encoding failed?")
      return
    }
    let job = NiimbotPeripheral.PrintJob(
      data: imageAsPackets, widthInPx: UInt16(image.size.width),
      heightInPx: UInt16(image.size.height), quantity: UInt16(quantity))
    _ = serialQueue.addJob {
      await self.printer?.printLabel(job)
    }
  }

  func disconnect() {
    guard isPaired && isConnected else { return }
    serialQueue.shutdown()
    // TODO: disable UI until disconnected...
    Task {
      await printer?.disconnect()
    }
  }

  private var printer: NiimbotPeripheral?
  var deviceInfo: NiimbotPeripheral.DeviceInfo?
  var paperRfidState: NiimbotPeripheral.RFIDPaperRollState?
  var deviceStatus: NiimbotPeripheral.DeviceStatus?

  private var serialQueue = SerialQueue()
  private var btNotifications: Set<AnyCancellable> = []
  private var printerNotifications: AnyCancellable?

  private func pollHeartbeat() {
    let timeToPollInSeconds = 3.0
    let shouldInvalidateRollRfid: Int? = deviceStatus?.closingState
    if isPrinting == false {
      _ = serialQueue.addJob {
        guard let validPrinter = self.printer, self.isConnected, !self.isPrinting else { return }
        let status = await validPrinter.heartbeat()
        if shouldInvalidateRollRfid == nil || shouldInvalidateRollRfid != status.closingState {
          _ = self.serialQueue.addJob {
            guard !self.isPrinting else { return }
            let rfidState = await self.printer?.getRFIDPaperRollState()
            guard let validState = rfidState else { return }
            await MainActor.run {
              self.paperRfidState = validState
              self.objectWillChange.send()
            }
          }
        }
        await MainActor.run {
          self.deviceStatus = status
          self.objectWillChange.send()
        }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + timeToPollInSeconds) {
      self.pollHeartbeat()
    }
  }

  private func safelyRemovePeripheral() {
    serialQueue.shutdown()
    printer = nil
    btNotifications.removeAll()
    // clear status/info
    deviceInfo = nil
    deviceStatus = nil
    printerNotifications = nil
    DispatchQueue.main.async {
      self.objectWillChange.send()
    }
  }

  private func notifyIfSamePeripheral(_ peripheral: Peripheral) {
    DispatchQueue.main.sync {
      guard self.printer?.peripheral.cbPeripheral == peripheral.cbPeripheral else { return }
      self.objectWillChange.send()
    }
  }

  func setCurrentPeripheral(peripheral: NiimbotPeripheral?) {
    guard let validPrinter = peripheral else {
      return
    }
    if printer != nil {
      safelyRemovePeripheral()
    }
    printer = validPrinter
    printerNotifications = validPrinter.$state.sink(receiveValue: {
      newState in
      DispatchQueue.main.async {
        self.objectWillChange.send()
      }
    })
    serialQueue = SerialQueue()
    _ = serialQueue.addJob {
      guard let info = await self.printer?.getDeviceInfo() else { return }
      DispatchQueue.main.async {
        self.deviceInfo = info
        self.pollHeartbeat()
      }
    }
    CentralManager.shared.eventPublisher
      .sink {
        switch $0 {
        case .didConnectPeripheral(let peripheral):
          self.notifyIfSamePeripheral(peripheral)
          break
        case .didDisconnectPeripheral(let peripheral, _, _):
          self.notifyIfSamePeripheral(peripheral)
          break
        default:
          break
        }
      }
      .store(in: &btNotifications)
  }
}

extension CentralManager {
  static let shared = CentralManager()
}
