import SwiftUI

struct PrintJobStatusView: View {
  let job: NiimbotPeripheral.PrintJobStatus
  let quantity: Int

  func calcProgress() -> Float {
    let steps = job.progress.count
    var total = 0
    for progress in job.progress {
      total += progress
    }
    return (Float(total) / Float(steps)) / 100.0
  }

  var body: some View {
    VStack {
      Text("Printing... \(job.page)/\(quantity)").foregroundStyle(.blue)
      ProgressView(value: calcProgress())
    }
  }
}

struct PrintJobStatusView_Previews: PreviewProvider {
  static var previews: some View {
    PrintJobStatusView(
      job: NiimbotPeripheral.PrintJobStatus(page: 1, progress: [25, 50]), quantity: 1)
  }
}
