// touchfix: userspace driver for eGalaxTouch (0eef:c000) -> macOS mouse events.
// Run `touchfix cal` once (touch top-left, top-right, bottom-right), then `touchfix`.
import IOKit.hid
import CoreGraphics
import Foundation

let cfgPath = NSHomeDirectory() + "/.touchfix"
let calMode = CommandLine.arguments.contains("cal")
var swap = false, x0 = 0.0, x1 = 4095.0, y0 = 0.0, y1 = 4095.0
if let t = try? String(contentsOfFile: cfgPath, encoding: .utf8), case let v = t.split(separator: " ").compactMap({ Double($0) }), v.count == 5 {
  swap = v[0] == 1; x0 = v[1]; x1 = v[2]; y0 = v[3]; y1 = v[4]
}

func extDisplay() -> CGRect {
  var ids = [CGDirectDisplayID](repeating: 0, count: 8); var n: UInt32 = 0
  CGGetActiveDisplayList(8, &ids, &n)
  let d = ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) == 0 } ?? CGMainDisplayID()
  return CGDisplayBounds(d)
}

var pending: CGPoint? = nil, press: Timer? = nil, swallow = false, lastD = 0.0, acc = 0.0
var scrolling = false, lastC: CGPoint? = nil, down = false, last = (0.0, 0.0), pts: [(Double, Double)] = []
let prompts = ["top-left corner", "top-right corner", "bottom-right corner"]
if calMode { print("Touch the \(prompts[0]) and lift.") }

func post(_ t: CGEventType, _ p: CGPoint) {
  let right = t == .rightMouseDown || t == .rightMouseUp
  CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: right ? .right : .left)?.post(tap: .cghidEventTap)
}

func handle(_ r: UnsafeMutablePointer<UInt8>, _ len: Int) {
  guard len >= 8, r[0] == 6 else { return }
  if calMode {
    let tip = r[2] & 1 == 1
    let rx = Double(Int(r[4]) | Int(r[5]) << 8), ry = Double(Int(r[6]) | Int(r[7]) << 8)
    if tip { last = (rx, ry); down = true }
    else if down {
      down = false; pts.append(last)
      if pts.count < 3 { print("Touch the \(prompts[pts.count]) and lift.") } else { finishCal() }
    }
    return
  }
  let f = extDisplay()
  func map(_ i: Int) -> (CGPoint, Bool) {
    let o = 2 + 10 * i
    let rx = Double(Int(r[o + 2]) | Int(r[o + 3]) << 8), ry = Double(Int(r[o + 4]) | Int(r[o + 5]) << 8)
    let (a, b) = swap ? (ry, rx) : (rx, ry)
    return (CGPoint(x: f.minX + min(max((a - x0) / (x1 - x0), 0), 1) * f.width,
                    y: f.minY + min(max((b - y0) / (y1 - y0), 0), 1) * f.height), r[o] & 1 == 1)
  }
  let n = Int(r[1])
  if n >= 2 && len >= 22 && r[2] & 1 == 1 && r[12] & 1 == 1 {
    let (p, q) = (map(0).0, map(1).0), c = CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
    let d = hypot(p.x - q.x, p.y - q.y)
    cancelPress(); if down { post(.leftMouseUp, c); down = false }
    if let l = lastC {
      let (dx, dy, dd) = (c.x - l.x, c.y - l.y, d - lastD)
      if abs(dd) > 1.5 * max(abs(dx), abs(dy)) {      // pinch: zoom with Cmd +/-
        acc += dd
        if abs(acc) > 80 { key(acc > 0 ? 24 : 27); acc = 0 }
      } else {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)?.post(tap: .cghidEventTap)
      }
    }
    lastC = c; lastD = d; scrolling = true; return
  }
  let (p, tip) = map(0)
  if !tip {
    lastC = nil; acc = 0
    if scrolling { scrolling = false; return }
    if swallow { swallow = false; return }
    if let s = pending { cancelPress(); post(.leftMouseDown, s); post(.leftMouseUp, s) }   // tap
    else if down { post(.leftMouseUp, p); down = false }
    return
  }
  if scrolling || swallow { return }
  if down { post(.leftMouseDragged, p); return }
  if let s = pending {
    if hypot(p.x - s.x, p.y - s.y) > 12 { cancelPress(); post(.leftMouseDown, s); post(.leftMouseDragged, p); down = true }
  } else {
    pending = p
    press = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { _ in   // long press = right click
      guard let s = pending else { return }
      pending = nil; swallow = true
      post(.rightMouseDown, s); post(.rightMouseUp, s)
    }
  }
}

func cancelPress() { press?.invalidate(); press = nil; pending = nil }
func key(_ k: CGKeyCode) {
  for dn in [true, false] {
    let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: dn); e?.flags = .maskCommand; e?.post(tap: .cghidEventTap)
  }
}

func finishCal() {
  let (p1, p2, p3) = (pts[0], pts[1], pts[2])
  let sw = abs(p2.1 - p1.1) > abs(p2.0 - p1.0)
  let g = { (p: (Double, Double)) in sw ? (p.1, p.0) : p }
  let (a1, a2, a3) = (g(p1), g(p2), g(p3))
  try? "\(sw ? 1 : 0) \(a1.0) \(a2.0) \(a2.1) \(a3.1)".write(toFile: cfgPath, atomically: true, encoding: .utf8)
  print("Saved \(cfgPath). Now run touchfix without cal."); exit(0)
}

let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0x0eef, kIOHIDProductIDKey: 0xc000] as CFDictionary)
var bufs: [UnsafeMutablePointer<UInt8>] = []
IOHIDManagerRegisterDeviceMatchingCallback(m, { _, _, _, dev in
  let p = UnsafeMutablePointer<UInt8>.allocate(capacity: 2048); bufs.append(p)
  IOHIDDeviceRegisterInputReportCallback(dev, p, 2048, { _, _, _, _, _, rep, len in handle(rep, len) }, nil)
}, nil)
IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
guard IOHIDManagerOpen(m, 0) == 0 else { print("cannot open HID (grant Input Monitoring)"); exit(1) }
CFRunLoopRun()
