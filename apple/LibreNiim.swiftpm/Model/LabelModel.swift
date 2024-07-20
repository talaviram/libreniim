import SwiftUI

class LabelModel: ObservableObject {
  @Published var labelText = ""
  @Published var rows: CGFloat = 240
  @Published var printSize: CGFloat = 96
  @Published var isInverted = true
  @Published var textFont = "Helvetica"
  @Published var textPos = CGPoint(x: 50, y: 50)
  @Published var textSize = 20.0
  @Published var textWeight = Font.Weight.regular

  func getAvailableFonts() -> [String] {
    var fonts: [String] = []
    let familyNames = UIFont.familyNames
    for family in familyNames {
      let fontNames = UIFont.fontNames(forFamilyName: family)
      for font in fontNames {
        fonts.append(font)
      }
    }
    return fonts
  }

  func getWidthInPx() -> CGFloat {
    isInverted ? rows : printSize
  }
  func getHeightInPx() -> CGFloat {
    isInverted ? printSize : rows
  }

  func makeImage() -> UIImage? {
    let frame = CGRect(x: 0, y: 0, width: getWidthInPx(), height: getHeightInPx())
    let nameLabel = UILabel(frame: frame)
    nameLabel.numberOfLines = 3
    nameLabel.textAlignment = .center
    nameLabel.backgroundColor = .white
    nameLabel.textColor = .black
    nameLabel.font = UIFont(name: textFont, size: textSize)
    nameLabel.text = labelText
    UIGraphicsBeginImageContext(frame.size)
    if let currentContext = UIGraphicsGetCurrentContext() {
      nameLabel.layer.render(in: currentContext)
      let nameImage = UIGraphicsGetImageFromCurrentImageContext()
      return nameImage
    }
    return nil
  }
}
