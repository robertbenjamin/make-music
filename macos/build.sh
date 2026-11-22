#!/bin/bash
# Builds "The CAM System.app" (native AppKit + WKWebView, page bundled offline).
set -e
cd "$(dirname "$0")"
APP="build/The CAM System.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/site"
swiftc -O -parse-as-library -target arm64-apple-macos14 main.swift -o build/cam-arm64
swiftc -O -parse-as-library -target x86_64-apple-macos14 main.swift -o build/cam-x86 2>/dev/null && \
  lipo -create build/cam-arm64 build/cam-x86 -output "$APP/Contents/MacOS/CAM" || cp build/cam-arm64 "$APP/Contents/MacOS/CAM"
strip -x "$APP/Contents/MacOS/CAM"
cp ../index.html ../favicon.svg "$APP/Contents/Resources/site/"
swift icon.swift build/AppIcon.iconset && iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>The CAM System</string>
  <key>CFBundleDisplayName</key><string>The CAM System</string>
  <key>CFBundleIdentifier</key><string>co.robertbenjamin.cam</string>
  <key>CFBundleExecutable</key><string>CAM</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Method by Luca Bade. Guide by Robert Benjamin.</string>
</dict></plist>
PL
codesign --force -s - "$APP"
rm -rf build/cam-* build/AppIcon.iconset
du -sh "$APP"
