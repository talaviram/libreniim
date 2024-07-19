import SwiftUI

struct DeviceInfoView: View {
  var info: NiimbotPeripheral.DeviceInfo
  var status: NiimbotPeripheral.DeviceStatus
  var connectionState: String

  var body: some View {
    HStack {
      Text("Model:")
      Spacer()
      Text(info.model?.rawValue ?? "")
        .font(.caption2)
        .fontWeight(.bold)
    }
    HStack {
      Text("Connection")
      Spacer()
      Text(connectionState)
        .font(.caption2)
        .fontWeight(.bold)
    }
    Section("Status") {
      HStack {
        Text("Battery:")
        Spacer()
        Text("\(status.batteryLevel)")
          .font(.caption2)
          .fontWeight(.bold)
      }
      HStack {
        Text("Paper Level:")
        Spacer()
        Text("\(status.paperLevel)")
          .font(.caption2)
          .fontWeight(.bold)
      }
      HStack {
        Text("Paper Compartment State:")
        Spacer()
        Text(status.paperCompartmentState())
          .font(.caption2)
          .fontWeight(.bold)
      }
      HStack {
        Text("RFID Validation:")
        Spacer()
        Text("\(status.rfidState)")
          .font(.caption2)
          .fontWeight(.bold)
      }
    }
    Section("Info") {
      HStack {
        Text("Serial Number:")
        Spacer()
        Text(info.deviceSerial)
          .font(.caption2)
          .fontWeight(.bold)
      }
      HStack {
        Text("Hardware Version:")
        Spacer()
        Text(info.hardwareVersion)
          .font(.caption2)
          .fontWeight(.bold)
      }
      HStack {
        Text("Software Version:")
        Spacer()
        Text(info.softwareVersion)
          .font(.caption2)
          .fontWeight(.bold)
      }
    }
  }
}
