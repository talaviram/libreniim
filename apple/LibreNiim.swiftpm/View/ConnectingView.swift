import Combine
import SwiftUI

struct ConnectingView: View {
  @ObservedObject var model = PrinterController.shared
  var body: some View {
    VStack {
      NavigationLink(
        "",
        destination: PrinterView(model: model),
        isActive: self.$showPrinterView
      )
      Spacer()
      Text("Connecting...")
        .font(.largeTitle)
      Text(self.viewModel.peripheralID.uuidString)
        .font(.callout)

      if let error = self.viewModel.error {
        Text("ERROR: \(error)")
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
          .padding(1)
      } else {
        ProgressView()
      }
      Spacer()

      Button("Cancel") { self.onCancelTapped() }
        .font(.title2)
        .padding(10)
    }
    .navigationBarBackButtonHidden(true)
    .onAppear {
      self.onDidAppear()
    }
  }

  @Environment(\.presentationMode) private var presentationMode
  @ObservedObject private var viewModel: ConnectingViewModel
  @State private var showPrinterView = false

  @State private var cancellableBag = Set<AnyCancellable>()

  init(peripheralID: UUID) {
    let viewModel = ConnectingViewModel(peripheralID: peripheralID)
    self.init(viewModel: viewModel)
  }

  fileprivate init(viewModel: ConnectingViewModel) {
    self.viewModel = viewModel
  }

  private func onCancelTapped() {
    self.viewModel.cancel()
    self.presentationMode.wrappedValue.dismiss()
  }

  private func onDidAppear() {
    self.viewModel.$isConnected
      .sink { _ in
        // Note we trigger async because the view model publishes before changes happen
        DispatchQueue.main.async {
          self.showPrinterView = self.viewModel.isConnected
        }
      }
      .store(in: &self.cancellableBag)

    self.viewModel.connect()
  }
}

struct ConnectingView_Previews: PreviewProvider {
  class MockViewModel: ConnectingViewModel {
    override func connect() {}
  }

  static var previews: some View {
    ConnectingView(viewModel: MockViewModel(peripheralID: UUID()))
      .preferredColorScheme(.dark)
  }
}
