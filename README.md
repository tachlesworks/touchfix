# TouchFix

A tiny menu bar app that makes **eGalaxTouch touchscreens work on macOS**. macOS ignores these screens' touch data, so they behave like a plain monitor. TouchFix reads the touches over USB and turns them into mouse events. It is a lightweight userspace replacement for a kernel touch driver (no kernel extension, no sudo).

## What you get

| Gesture | Result |
|---|---|
| Tap | Left click |
| Drag one finger | Click and drag |
| Hold one finger still ~0.6 s | Right click |
| Drag two fingers | Scroll |
| Pinch two fingers | Zoom: sends ⌘+ / ⌘−, so it works in apps that support those shortcuts, in steps rather than smoothly |

The menu bar icon (a tapping hand) has **Touch enabled**, **Calibrate…**, **Launch at login** and **Quit**.

## Supported screens

TouchFix talks to one touch controller:

**eGalax Inc. USB controller, vendor ID `0x0eef`, product ID `0xc000`.**

- **Tested:** ASUS MB16AHT (ZenScreen Touch 15.6") with the `eGalaxTouch EXC3200` controller, on macOS 27.
- **Should work, untested:** any other touch monitor, portable monitor or all-in-one that uses the same controller and shows up with the same IDs. Many touch displays from several brands use eGalax controllers, but the brand tells you nothing: check the IDs below.
- **Will not work without code changes:** screens with a different controller or product ID, even if they are also eGalax. Screens that macOS already supports natively do not need this.

**Check your screen:** connect it by USB (the touch signal is a separate USB cable from the video), then run

```bash
ioreg -p IOUSB -l | grep -B2 -A12 -i egalax
```

You are looking for `"idVendor" = 3823` (0x0eef) and `"idProduct" = 49152` (0xc000). The same entry is in System Information → USB. If your IDs differ, see [Adding another screen](#adding-another-screen).

The touch data format this app understands: a report starting with ID `6`, a finger count, then 10 bytes per finger (tip state, X, Y), up to 3 fingers. The screen is calibrated, not assumed: any resolution, orientation or position works, and TouchFix maps touches to the external display.

## Install

1. Download `dist/TouchFix.dmg` from this repo, open it, and drag **TouchFix** onto **Applications**.
2. The app is signed ad hoc, not notarized, so macOS blocks the first launch. Right-click **TouchFix** → **Open** → **Open**. If that is still blocked, run `xattr -dr com.apple.quarantine /Applications/TouchFix.app` once.
3. Grant **Accessibility** and **Input Monitoring** to TouchFix in System Settings → Privacy & Security, then quit and reopen it. Without them macOS silently drops the clicks.
4. Choose **Calibrate…** from the menu bar icon and touch the screen's **top-left**, **top-right** and **bottom-right** corners, as you see them now. The prompts appear next to the icon. Calibrate again after rotating the screen. The result is saved in `~/.touchfix`.
5. Turn on **Launch at login**.

## Build from source

Needs the Xcode command line tools.

```bash
./build.sh          # builds build/TouchFix.app and dist/TouchFix.dmg
```

## Adding another screen

If your controller has other IDs or a different report format:

```bash
swiftc Tools/dump.swift -o dump && ./dump
```

Edit the vendor and product IDs in `Tools/dump.swift`, run it, and touch the screen for 45 seconds. It prints every raw report as hex. The report layout is parsed in `handle()` in `Sources/TouchFix.swift`; adjust the IDs in `startHID()` and the byte offsets to match, then rebuild. Pull requests for other controllers are welcome.

## How it works

- `IOHIDManager` listens for the controller's raw reports.
- `CGEvent` posts the mouse clicks, drags, scroll-wheel events and key presses.
- A 3-corner calibration maps raw coordinates to the screen and detects swapped or inverted axes.
- `NSStatusItem` is the menu bar icon; `SMAppService` handles Launch at login.

`Tools/touchfix-cli.swift` is the same driver as a terminal program (`touchfix cal`, then `touchfix`).

## Limitations

- Pinch zooms with ⌘+ / ⌘− keystrokes, not true pinch gestures, which macOS cannot take from a touchscreen.
- Touches always go to the external (non-built-in) display.
- Not notarized, so the first launch needs the steps above.

## License

MIT. See [LICENSE](LICENSE).
