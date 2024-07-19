import AsyncBluetooth
import Foundation

class ScanViewModel: ObservableObject {
  private let centralManager: CentralManager

  @Published private(set) var isScanning = false
  @Published private(set) var peripherals: [ScanViewPeripheralListItem] = []
  @Published private(set) var error: String?

  init(centralManager: CentralManager = CentralManager.shared) {
    self.centralManager = centralManager
  }

  func startScan() {
    self.error = nil
    self.peripherals.removeAll()
    self.isScanning = true

    Task {
      do {
        try await self.centralManager.waitUntilReady()
        let scanDataStream = try await self.centralManager.scanForPeripherals(withServices: nil)
        for await scanData in scanDataStream {
          let identifier = scanData.peripheral.identifier
          guard let name = scanData.peripheral.name else { continue }
          var isSupportedModel = false
          for supportedModel in NiimbotPeripheral.Product.rawValues() {
            if name.starts(with: supportedModel) {
              isSupportedModel = true
            }
          }
          guard
            isSupportedModel && !self.peripherals.contains(where: { $0.identifier == identifier })
          else { continue }
          let peripheral = ScanViewPeripheralListItem(identifier: identifier, name: name)
          DispatchQueue.main.async {
            self.peripherals.append(peripheral)
          }
        }
      } catch {
        DispatchQueue.main.async {
          self.error = error.localizedDescription
          self.isScanning = false
        }
      }
    }
  }

  func stopScan() {
    Task {
      if self.centralManager.isScanning {
        await self.centralManager.stopScan()
      }

      DispatchQueue.main.async {
        self.isScanning = false
      }
    }
  }
}
