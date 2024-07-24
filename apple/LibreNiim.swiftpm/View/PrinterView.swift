import Combine
import SwiftUI

struct PrinterView: View {

  @ObservedObject var model: PrinterController
  @State var scanDevicesView = false
  @State var showDeviceInfo = false
  @State private var labelModel = LabelModel()

  var body: some View {
    ZStack(alignment: .center) {
      VStack {
        if showDeviceInfo {
          List {
            if let validDeviceInfo = model.deviceInfo, let validDeviceStatus = model.deviceStatus {
              DeviceInfoView(
                info: validDeviceInfo, status: validDeviceStatus,
                connectionState: model.connectionState()
              ).frame(maxWidth: .infinity, maxHeight: .infinity)
              if let validRfid = model.paperRfidState {
                LabelRollView(state: validRfid)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else {
                Text("Label Info Unavailable")
              }
            } else {
              Text("Device Info Unavailable")
            }
          }
        } else {
          LabelPreview(labelModel: labelModel).border(.black)
          LabelView(labelModel: $labelModel).disabled(model.isPrinting)
          Button(
            "Print",
            action: {
              if let image = labelModel.makeImage() {
                model.tryPrint(image, verticalPrint: labelModel.isInverted)
              }
            }
          )
          .buttonStyle(.borderedProminent)
          .tint(.blue)
          .disabled(model.isPrinting || !model.isConnected)
          .frame(width: 120, height: 40)
        }
        Spacer()
        HStack {
          Button(
            model.isConnected ? "Disconnect" : "Connect",
            action: {
              if model.isConnected {
                model.disconnect()
              } else {
                model.reconnect()

              }
            }
          ).buttonStyle(.bordered)
          Spacer()
          if let deviceStatus = model.deviceStatus {
            switch deviceStatus.batteryLevel {
            case 3:
              Image(systemName: "battery.100")
            case 2:
              Image(systemName: "battery.50")
            case 1:
              Image(systemName: "battery.25")
            default:
              Image(systemName: "battery.0")
            }
          }
          Button(action: { showDeviceInfo.toggle() }) {
            Label("Connection Info", systemImage: "info.circle").labelStyle(.iconOnly)
              .foregroundStyle(.blue).padding()
          }
        }
      }.padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
        .onAppear {
          labelModel.printSize = CGFloat(
            NiimbotPeripheral.millimetersToPixels(model.getEffectivePrintSize()))
          labelModel.isInverted = NiimbotPeripheral.shouldInvertCanvas(
            model.deviceInfo?.model ?? NiimbotPeripheral.Product.unknown)
        }
        .overlay(alignment: .top) {
          if let error = model.error {
            Text("Error: \(error)")
              .foregroundStyle(.white)
              .background(.red)
              .font(.title2)
          }
        }
        .navigationBarBackButtonHidden(true)
      if model.isPrinting, let status = model.printStatus() {
        // TODO: support quantity
        PrintJobStatusView(job: status, quantity: 1)
          .padding()
          .frame(maxHeight: .infinity)
          .background(.black.opacity(0.5))
      }
    }
  }
}

struct PrinterView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      PrinterView(model: PrinterController())
    }
  }
}
