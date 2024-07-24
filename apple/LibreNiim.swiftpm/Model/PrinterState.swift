//
//  File.swift
//
//
//  Created by Tal Aviram on 20/07/2024.
//

import Foundation

struct PrinterState {
  var isConnected = false
  var isPrinting = false
  var error: String?
  var jobStatus: NiimbotPeripheral.PrintJobStatus?
}
