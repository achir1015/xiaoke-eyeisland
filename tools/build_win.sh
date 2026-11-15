#!/usr/bin/env bash
# 匯出 Windows 版＋Inno 安裝程式＋免安裝 zip，輸出到 ../build/release
# 用法：bash tools/build_win.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
GODOT="/e/從零建置 Godot 賽車遊戲/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
ISCC="$LOCALAPPDATA/Programs/Inno Setup 6/ISCC.exe"
VERSION="$(grep -E '^config/version=' project.godot | cut -d'"' -f2)"
REL="$ROOT/build/release"
mkdir -p "$REL" "$ROOT/build/windows"
echo "== v$VERSION"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows" "$ROOT/build/windows/XiaokeEyeIsland.exe" 2>&1 | grep -E "ERROR" || true
(cd platform/windows && "$ISCC" //Q //DAppVersion="$VERSION" installer.iss)
rm -f "$REL/XiaokeEyeIsland-Windows-portable.zip"
(cd "$ROOT/build/windows" && powershell -NoProfile -Command "Compress-Archive -Path XiaokeEyeIsland.exe -DestinationPath '$(cygpath -w "$REL")\XiaokeEyeIsland-Windows-portable.zip'")
ls -la "$REL"
