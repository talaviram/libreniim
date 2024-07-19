import Foundation

// Serial queue to ensure tasks are running sequentially
class SerialQueue {
  private var isShuttingDown = false
  private var queue: [() async -> Void] = []
  private var queueLock = NSLock()
  private var isRunning = false

  func addJob(job: @escaping () async -> Void) -> Bool {
    guard !isShuttingDown else { return false }
    queueLock.lock()
    queue.append(job)

    if !isRunning {
      isRunning = true
      Task {
        while !queue.isEmpty {
          var maybeJob: (() async -> Void)?
          queueLock.withLock({
            maybeJob = queue.removeFirst()
          })
          guard let job = maybeJob else { continue }
          await job()
          queueLock.withLock({
            isRunning = false
          })
        }
      }
    }
    queueLock.unlock()
    return true
  }

  func shutdown() {
    self.isShuttingDown = true
    waitForPendingJobs()
  }

  func waitForPendingJobs() {
    while queue.count > 0 {}
  }
}
