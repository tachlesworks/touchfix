import IOKit.hid
import Foundation
let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 3823, kIOHIDProductIDKey: 49152] as CFDictionary)
let cb: IOHIDReportCallback = { _, _, sender, _, id, rep, len in
  let b = (0..<len).map { String(format: "%02x", rep[$0]) }.joined()
  print("id=\(id) len=\(len) \(b)"); fflush(stdout)
}
var bufs: [UnsafeMutablePointer<UInt8>] = []
IOHIDManagerRegisterDeviceMatchingCallback(m, { _, _, _, dev in
  let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 2048); bufs.append(p)
  IOHIDDeviceRegisterInputReportCallback(dev, p, 2048, cb, nil)
}, nil)
IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
let r = IOHIDManagerOpen(m, 0)
print("open:", String(r, radix: 16))
CFRunLoopRunInMode(.defaultMode, 45, false)
