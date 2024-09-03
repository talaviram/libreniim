import CoreGraphics
import SwiftUI
import UIKit

//MARK: Image Encoding
func encodeImageToPackets(image: Bitmap) -> [[NiimbotPacket]] {
  assert(((image.width % 8) == 0))

  var packets: [[NiimbotPacket]] = []
  let sliceSize = 200
  for ySlice in stride(from: 0, to: image.height, by: sliceSize) {
    let hSlice = min(image.height, ySlice + sliceSize)
    var imagePackets: [NiimbotPacket] = []
    var yNext = ySlice

    let start = ySlice * image.width
    let end = (ySlice + 1) * image.width

    var dataNext = image.data[start..<end]
    while yNext < hSlice {
      let y = yNext
      let data = dataNext

      // find how many the same lines are being send
      while yNext + 1 <= hSlice {
        yNext += 1
        if yNext == hSlice {
          break
        }
        dataNext = image.data[(yNext * image.width)..<((yNext + 1) * image.width)]
        if data != dataNext {
          break
        }
      }
      imagePackets.append(
        encodeImageBytes(pixels: data, yStart: y, width: image.width, n: yNext - y))
    }
    packets.append(imagePackets)
  }
  return packets
}

func encodeImageBytes(pixels: ArraySlice<Bool>, yStart: Int, width: Int, n: Int = 1)
  -> NiimbotPacket
{

  assert(pixels.count <= 200)

  let startOffset = pixels.startIndex
  var packetData: [UInt8] = []
  // image inner header
  packetData += UInt16(yStart).toBigEndianAsUInt8()

  var indexes: [UInt16] = []
  for x in stride(from: 0, to: width, by: 32) {
    let start_indexes = indexes.count
    for b in 0..<32 {
      if pixels[startOffset + x + b] {
        indexes.append(UInt16(x + b))
      }
    }
    // image inner header
    packetData.append(UInt8(indexes.count - start_indexes))
  }
  packetData.append(UInt8(n))

  // push empty row data
  if indexes.count == 0 {
    // header info
    var clearData = UInt16(yStart).toBigEndianAsUInt8()
    clearData.append(UInt8(n))
    return NiimbotPacket(type: NiimbotPeripheral.CmdType.IMAGE_CLEAR.rawValue, data: clearData)
  }

  // send as indexes
  if indexes.count * 2 < width / 8 {
    for index in indexes {
      packetData += index.toBigEndianAsUInt8()
    }
    return NiimbotPacket(type: NiimbotPeripheral.CmdType.IMAGE_SET.rawValue, data: packetData)
  }

  let numBitsInByte = 8
  for x in stride(from: 0, to: width, by: numBitsInByte) {
    var bits: UInt8 = 0
    for b in 0..<8 {
      let pixel = pixels[startOffset + x + b]
      if pixel {
        bits |= 1 << (7 - b)
      }
    }
    packetData.append(bits)
  }
  return NiimbotPacket(type: NiimbotPeripheral.CmdType.IMAGE_DATA.rawValue, data: packetData)
}

struct Bitmap {
  let data: [Bool]
  let height: Int
  let width: Int

  func getPixel(x: Int, y: Int) -> Bool {
    let index = y * width + x
    return data[index]
  }

  func flipped() -> Bitmap {
    let flippedData = data.map(!)
    return Bitmap(data: flippedData, height: height, width: width)
  }
}

extension UIImage {
  func replacingAlphaWithWhite() -> UIImage? {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = self.scale  // Preserve the original scale
    format.opaque = true  // Make the renderer opaque

    let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
    let image = renderer.image { context in
      UIColor.white.setFill()  // Set white color as fill
      context.fill(CGRect(origin: .zero, size: self.size))  // Fill the background with white

      self.draw(at: .zero)  // Draw the original image
    }

    return image
  }
}

extension CGImage {
  func asBitmap() -> Bitmap {
    var bitmapData: [Bool] = []
    let bmp = self.dataProvider!.data
    let data: UnsafePointer<UInt8> = CFDataGetBytePtr(bmp)

    let bytesPerPixel = self.bitsPerPixel / self.bitsPerComponent
    for y in 0..<height {
      for x in 0..<width {
        let offset = y * bytesPerRow + x * bytesPerPixel
        var isBlack = false
        for c in 0..<bytesPerPixel {
          isBlack = isBlack || data[offset + c] != 255
        }
        bitmapData.append(isBlack)
      }
    }
    assert(bitmapData.count == width * height)

    return Bitmap(data: bitmapData, height: self.height, width: self.width)
  }

  func rescale(by scale: CGFloat) -> CGImage? {
    guard scale != 1.0 else { return self }
    let newWidth = CGFloat(width) / scale
    let newHeight = CGFloat(height) / scale

    let bitmapInfo = self.bitmapInfo
    let colorSpace = self.colorSpace

    guard
      let context = CGContext(
        data: nil,
        width: Int(newWidth),
        height: Int(newHeight),
        bitsPerComponent: self.bitsPerComponent,
        bytesPerRow: self.bytesPerRow,
        space: colorSpace!,
        bitmapInfo: bitmapInfo.rawValue)
    else { return nil }
    context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
    return context.makeImage()
  }

  func roatatedBy90() -> CGImage? {

    let rotatedSize = CGSize(width: height, height: width)
    let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
    guard
      let context = CGContext(
        data: nil,
        width: Int(rotatedSize.width),
        height: Int(rotatedSize.height),
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue)
    else { return nil }

    // Rotate the context 90 degrees clockwise
    context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
    context.rotate(by: .pi / 2)
    context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)

    // Draw the image in the transformed context
    context.draw(self, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    return context.makeImage()
  }
}

extension View {
  func snapshot() -> UIImage {
    let controller = UIHostingController(rootView: self)
    let view = controller.view

    let targetSize = controller.view.intrinsicContentSize
    view?.bounds = CGRect(origin: .zero, size: targetSize)
    view?.backgroundColor = .white

    let renderer = UIGraphicsImageRenderer(size: targetSize)

    return renderer.image { _ in
      view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
  }
}
