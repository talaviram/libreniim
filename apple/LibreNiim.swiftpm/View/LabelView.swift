import SwiftUI

struct LabelPreview: View {
  @ObservedObject var labelModel: LabelModel
  var body: some View {
    Image(uiImage: labelModel.makeImage()!)
  }
}

struct LabelView: View {

  @Binding var labelModel: LabelModel
  @State var selectedSize = 0

  func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
  }

  @State var selectedfont = "Helvetica"

  var body: some View {
    VStack {
      List {
        HStack {
          TextField("Enter label text here...", text: $labelModel.labelText).textFieldStyle(
            .roundedBorder
          ).border(.blue)
            .multilineTextAlignment(.trailing)
        }
        HStack {
          Picker("Font", selection: $selectedfont) {
            ForEach(labelModel.getAvailableFonts(), id: \.self) { string in
              Text(string)
            }
          }.pickerStyle(.wheel)
            .onChange(of: selectedfont) {
              newFont in
              labelModel.textFont = newFont
            }
        }
        HStack {
          Text("Font Size")
          Slider(value: $labelModel.textSize, in: 10...320, step: 1.0)
          Text("\(labelModel.textSize.formatted())")
        }
        HStack {
          Text("Print Area")
          Spacer()
          Text(
            "Pixels: \(labelModel.getWidthInPx().formatted())x\(labelModel.getHeightInPx().formatted())"
          )
        }
      }
    }
  }
}

struct LabelView_Previews: PreviewProvider {
  static var previews: some View {
    @State var labelModel = LabelModel()
    NavigationView {
      LabelView(labelModel: $labelModel)
    }
  }
}
