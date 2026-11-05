#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

./build.sh

DEST="/Applications/VoiceInput.app"
rm -rf "$DEST"
ditto "build/VoiceInput.app" "$DEST"

echo "Installed: $DEST"

# 结束旧实例，避免出现两个菜单栏图标。
pkill -x VoiceInput 2>/dev/null || true
sleep 0.3

open "$DEST"
echo "已启动。首次使用请按菜单栏提示授予：麦克风、语音识别、辅助功能。"
