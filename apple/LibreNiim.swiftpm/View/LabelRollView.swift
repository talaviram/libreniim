import SwiftUI

struct LabelRollView: View {

  let state: NiimbotPeripheral.RFIDPaperRollState

  var body: some View {
    Section("Label Roll") {
      HStack {
        Text("Barcode")
        Spacer()
        Text(state.barcode)
      }
      HStack {
        Text("Serial")
        Spacer()
        Text(state.serial)
      }
      HStack {
        Text("UUID")
        Spacer()
        Text(state.uuid)
      }
      HStack {
        Text("Type")
        Spacer()
        Text(state.type.description)
      }
      HStack {
        let consumedLabel = Float(state.used) / Float(state.total)
        Text("Used: \(state.used) of \(state.total)")
        Spacer()
        ProgressView(value: consumedLabel)
      }
    }
  }
}
