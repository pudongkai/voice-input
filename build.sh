#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="build/VoiceInput.app"
BIN="$APP/Contents/MacOS/VoiceInput"
MIN_MACOS="13.0"
SDK="$(xcrun --show-sdk-path)"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

# 图标（只在缺失时生成）
if [[ ! -f Resources/AppIcon.icns ]]; then
    echo "Generating app icon ..."
    swiftc -swift-version 5 tools/make_icon.swift -o build/obj/make_icon
    build/obj/make_icon build/icon-1024.png

    ICONSET="build/AppIcon.iconset"
    mkdir -p "$ICONSET"
    make_size() {
        local pixels="$1" name="$2"
        sips -z "$pixels" "$pixels" build/icon-1024.png --out "$ICONSET/$name" >/dev/null
    }
    make_size 16   icon_16x16.png
    make_size 32   icon_16x16@2x.png
    make_size 32   icon_32x32.png
    make_size 64   icon_32x32@2x.png
    make_size 128  icon_128x128.png
    make_size 256  icon_128x128@2x.png
    make_size 256  icon_256x256.png
    make_size 512  icon_256x256@2x.png
    make_size 512  icon_512x512.png
    make_size 1024 icon_512x512@2x.png
    iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

build_arch() {
    local arch="$1"
    echo "Compiling $arch ..."
    swiftc \
        -O \
        -swift-version 5 \
        -target "${arch}-apple-macosx${MIN_MACOS}" \
        -sdk "$SDK" \
        -framework Cocoa \
        -framework AVFoundation \
        -framework Speech \
        -framework ApplicationServices \
        -framework ServiceManagement \
        -framework Carbon \
        -framework SwiftUI \
        Sources/*.swift \
        -o "build/obj/VoiceInput-${arch}"
}

build_arch arm64
build_arch x86_64

lipo -create \
    build/obj/VoiceInput-arm64 \
    build/obj/VoiceInput-x86_64 \
    -output "$BIN"

echo "Signing (ad-hoc) ..."
codesign --force --sign - --timestamp=none "$APP" >/dev/null

echo "Architectures: $(lipo -archs "$BIN")"
echo "Built: $(pwd)/$APP"
