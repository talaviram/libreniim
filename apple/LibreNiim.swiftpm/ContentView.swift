import CoreBluetooth
import SwiftUI

struct ContentView: View {
  @ObservedObject var model = PrinterController.shared

  var body: some View {
    NavigationView {
      if !model.isConnected {
        VStack {
          VStack {
            Text("Welcome to LIBRENIIM").frame(maxWidth: .infinity, alignment: .center)
            Text(
              "To start, make sure your device is turned on.\nUsually this is done by long-press the button on the printer."
            )
          }
          .foregroundStyle(.white)
          .padding()
          .background(.blue, in: RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
          ScanView()
        }
      }
    }.navigationBarTitleDisplayMode(.large)
      .navigationViewStyle(.stack)
  }
}
