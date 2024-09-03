import Combine
import SwiftUI

struct PrinterView: View {

  @ObservedObject var model: PrinterController
  @State var scanDevicesView = false
  @State var showDeviceInfo = false
  @State private var labelModel = LabelModel()
    static var webView = WebView()

    func onImageCaptured (_ image: UIImage?) {
        guard let gotImage = image else { return }
        model.tryPrint(gotImage, verticalPrint: labelModel.isInverted)
    }

    init(model: PrinterController, scanDevicesView: Bool = false, showDeviceInfo: Bool = false, labelModel: LabelModel = LabelModel()) {
        self.model = model
        self.scanDevicesView = scanDevicesView
        self.showDeviceInfo = showDeviceInfo
        self.labelModel = labelModel
        WebView.shared.onImageAvailable = onImageCaptured
    }

  var body: some View {
    GeometryReader {
      area in
      ZStack(alignment: .center) {
        VStack {
          if showDeviceInfo {
            List {
              if let validDeviceInfo = model.deviceInfo, let validDeviceStatus = model.deviceStatus
              {
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
              PrinterView.webView
//            LabelPreview(labelModel: labelModel).border(.black)
//            LabelView(labelModel: $labelModel).disabled(model.isPrinting)
            Button(
              "Print",
              action: {
                  PrinterView.webView.exportCanvas()
//                if let image = labelModel.makeImage() {
//                  model.tryPrint(image, verticalPrint: labelModel.isInverted)
//                }
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
          .blur(radius: model.isPrinting ? 5 : 0)
          .overlay(alignment: .top) {
            if let error = model.error {
              Text("Error: \(error)")
                .foregroundStyle(.white)
                .background(.red)
                .font(.title2)
            }
          }
          .navigationBarBackButtonHidden(true)
        if model.isPrinting {
          // TODO: support quantity
          let rectSize = min(area.size.width, area.size.height) * 0.60
            PrintJobStatusView(job: model.printStatus(), quantity: 1)
            .frame(width: rectSize, height: rectSize)
        }
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
