#!/bin/zsh
# Builds TouchFix.app and dist/TouchFix.dmg.
# Signed ad hoc (no developer identity), so the app is not tied to anyone's certificate.
set -e
cd "${0:A:h}"
VERSION=${1:-1.0}
APP=build/TouchFix.app
rm -rf build dist; mkdir -p $APP/Contents/MacOS dist
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.touchfix</string>
  <key>CFBundleName</key><string>TouchFix</string>
  <key>CFBundleExecutable</key><string>TouchFix</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
swiftc -O -swift-version 5 Sources/TouchFix.swift -o $APP/Contents/MacOS/TouchFix
codesign --force --sign - $APP
# DMG: the app plus an Applications shortcut to drag it onto.
mkdir build/dmg && cp -R $APP build/dmg/ && ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname TouchFix -srcfolder build/dmg -ov -format UDZO dist/TouchFix.dmg
echo "built $PWD/dist/TouchFix.dmg"
