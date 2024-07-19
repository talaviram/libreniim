import AsyncBluetooth
import Foundation

class NiimbotPacket: PeripheralDataConvertible {

  static func fromData(_ data: Data) -> Self? {
    return fromBytes([UInt8](data)) as? Self
  }

  private var type: UInt8
  private var data: [UInt8]

  init(type: UInt8, data: [UInt8]) {
    self.type = type
    self.data = data
    assert(data.count < 255)
  }

  var datacount: Int {
    return data.count
  }

  var count: Int {
    let headerChecksumAndFooterSizeInBytes = 7
    return headerChecksumAndFooterSizeInBytes + data.count
  }

  var responseType: UInt8 {
    return self.type
  }

  func byteAt(pos: Int) -> UInt8 {
    return data[pos]
  }

  func bytesAt(start: Int, inclusiveEnd: Int) -> [UInt8] {
    return Array(data[start..<inclusiveEnd])
  }

  func asInt() -> Int {
    return data.reduce(0) { ($0 << 8) | Int($1) }
  }

  func asBool() -> Bool {
    guard !data.isEmpty else { return false }
    return data[0] > 0
  }

  func asHex() -> String {
    return NiimbotPacket.convertToHex(self.data)
  }

  static func convertToHex(_ input: [UInt8]) -> String {
    return input.map { String(format: "%02X", $0) }.joined()
  }

  static func fromBytes(_ pkt: [UInt8]) -> NiimbotPacket? {
    return fromBytes(pkt, checksumMode: .validate)
  }

  enum ChecksumMode {
    case skip, validate
  }

  static func fromBytes(_ pkt: [UInt8], checksumMode: ChecksumMode) -> NiimbotPacket? {
    guard pkt.count >= 6,
      pkt[0] == 0x55, pkt[1] == 0x55,
      pkt[pkt.count - 2] == 0xAA, pkt[pkt.count - 1] == 0xAA
    else {
      return nil
    }

    let type = pkt[2]
    let len = pkt[3]
    let data = Array(pkt[4..<4 + Int(len)])

    if checksumMode == .validate {
      var checksum: UInt8 = type ^ len
      for byte in data {
        checksum ^= byte
      }
      guard checksum == pkt[pkt.count - 3] else {
        return nil
      }
    }

    return NiimbotPacket(type: type, data: data)
  }

  func asBytes() -> [UInt8] {
    var checksum: UInt8 = type ^ UInt8(data.count)
    for byte in data {
      checksum ^= byte
    }

    let packet: [UInt8] = [0x55, 0x55, type, UInt8(data.count)] + data + [checksum, 0xaa, 0xaa]
    return packet
  }

  func toData() -> Data? {
    guard !data.isEmpty else {
      return nil
    }
    return Data(asBytes())
  }

  static let errorTypePacket = 219
  static let invalidTypePacket = 0

  var description: String {
    return "[NiimbotPacket type=\(type) data=\(data)]"
  }
}
