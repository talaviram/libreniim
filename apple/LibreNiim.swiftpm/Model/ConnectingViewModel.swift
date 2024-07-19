import AsyncBluetooth
import Foundation

class ConnectingViewModel: ObservableObject {
  let peripheralID: UUID

  @Published private(set) var isConnected = false
  @Published private(set) var error: String?

  private let centralManager: CentralManager
  private let core: PrinterController

  private lazy var peripheral: Peripheral? = {
    self.centralManager.retrievePeripherals(withIdentifiers: [self.peripheralID]).first
  }()

  init(
    peripheralID: UUID, core: PrinterController = PrinterController.shared,
    centralManager: CentralManager = CentralManager.shared
  ) {
    self.core = core
    self.peripheralID = peripheralID
    self.centralManager = centralManager
  }

  func connect() {
    guard let peripheral = self.peripheral else {
      self.error = "Unknown peripheral. Did you forget to scan?"
      return
    }
    Task {
      do {
        if self.centralManager.isScanning {
          await self.centralManager.stopScan()
        }

        try await self.centralManager.connect(peripheral)

        try await peripheral.discoverServices(nil)
        let discoveredServices = peripheral.discoveredServices ?? []
        for service in discoveredServices {
          try await peripheral.discoverCharacteristics(nil, for: service)
          guard let characters = service.discoveredCharacteristics, characters.count == 1 else {
            continue
          }
          let properties = characters[0].properties
          guard
            properties.contains(.read) && properties.contains(.writeWithoutResponse)
              && properties.contains(.notify)
          else { continue }
          await MainActor.run {
            core.setCurrentPeripheral(
              peripheral: NiimbotPeripheral(peripheral: peripheral, characteristic: characters[0]))
          }
        }
        DispatchQueue.main.async {
          self.isConnected = true
        }
      } catch {
        DispatchQueue.main.async {
          self.error = error.localizedDescription
        }
      }
    }
  }

  func cancel() {
    guard let peripheral = self.peripheral else {
      self.error = "Unknown peripheral. Did you forget to scan?"
      return
    }
    Task {
      do {
        try await self.centralManager.connect(peripheral)
      } catch {}
    }
  }
}
