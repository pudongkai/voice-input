#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="VoiceInput"
APP="build/${APP_NAME}.app"
DIST="dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"

echo "==> Building ${APP_NAME} ${VERSION}"
./build.sh

rm -rf "$DIST" build/dmg
mkdir -p "$DIST" build/dmg

# DMG 内容：App + 应用程序快捷方式 + 安装说明
ditto "$APP" "build/dmg/${APP_NAME}.app"
ln -s /Applications "build/dmg/Applications"
cp tools/安装说明.txt "build/dmg/安装说明.txt"

echo "==> Creating DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder build/dmg \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

echo "==> Creating ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo
echo "Done:"
echo "  $DMG"
echo "  $ZIP"
echo
shasum -a 256 "$DMG" "$ZIP"

cat <<'EOF'

提示：
- 当前是 ad-hoc 签名，未做 Apple 公证。别人第一次打开需要右键 → 打开，
  或执行：xattr -dr com.apple.quarantine /Applications/VoiceInput.app
- 如果想要双击直接打开、没有安全提示，需要 Apple Developer ID 证书做签名和公证：
  codesign --sign "Developer ID Application: ..." --options runtime --timestamp ...
  xcrun notarytool submit ... --wait
  xcrun stapler staple ...
EOF
