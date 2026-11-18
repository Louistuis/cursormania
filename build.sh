#!/bin/bash
# Builds CursorSpaceX.app (universal: Apple silicon + Intel) and a release zip.
# Needs only the Command Line Tools. The app is ad-hoc signed, not notarized.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/CursorSpaceX.app"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

echo "▸ compiling $VERSION (release)…"
cd "$ROOT"
for ARCH in arm64 x86_64; do
    swift build -c release --triple "$ARCH-apple-macosx26.0" 2>&1 | grep -E "error" || true
done
ARM="$ROOT/.build/arm64-apple-macosx/release/CursorSpaceX"
X86="$ROOT/.build/x86_64-apple-macosx/release/CursorSpaceX"
[ -x "$ARM" ] && [ -x "$X86" ] || { echo "✗ build failed"; exit 1; }
BIN="$BUILD/CursorSpaceX-universal"
mkdir -p "$BUILD"
lipo -create "$ARM" "$X86" -output "$BIN"

echo "▸ assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/CursorSpaceX"

echo "▸ rendering icon…"
"$APP/Contents/MacOS/CursorSpaceX" --render-icon "$BUILD/icon1024.png" >/dev/null
ICONSET="$BUILD/AppIcon.iconset"; rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" \
            "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
    set -- $spec
    sips -z "$1" "$1" "$BUILD/icon1024.png" --out "$ICONSET/icon_$2.png" >/dev/null 2>&1
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>CursorSpaceX</string>
    <key>CFBundleDisplayName</key>          <string>CursorSpaceX</string>
    <key>CFBundleIdentifier</key>           <string>com.lou15.cursorspacex</string>
    <key>CFBundleExecutable</key>           <string>CursorSpaceX</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundleVersion</key>              <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>       <string>26.0</string>
    <key>LSApplicationCategoryType</key>    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSHumanReadableCopyright</key>     <string>Open source, MIT licence.</string>
</dict>
</plist>
PLIST

echo "▸ signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "▸ zipping…"
# One stable name, so releases/latest/download/CursorSpaceX.zip always works.
rm -f "$BUILD/CursorSpaceX.zip"
( cd "$BUILD" && ditto -c -k --keepParent CursorSpaceX.app CursorSpaceX.zip )
( cd "$BUILD" && shasum -a 256 CursorSpaceX.zip | tee CursorSpaceX.zip.sha256 )
echo "✓ $APP"
