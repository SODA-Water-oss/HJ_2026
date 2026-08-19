#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! security find-identity -v -p codesigning | grep -q "Apple Development"; then
  echo "错误：未找到 Apple Development 签名证书。" >&2
  echo "请先在 Xcode → Settings → Accounts 登录开发者账号并下载证书。" >&2
  exit 1
fi

ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/Build/Development/花计2046.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/Build/Development}"

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_FUNCTIONS_URL="${SUPABASE_FUNCTIONS_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

BUILD_SETTINGS=(
  CODE_SIGN_STYLE=Automatic
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-55MKGSFZJ9}"
)
if [ -n "$SUPABASE_URL" ]; then BUILD_SETTINGS+=(SUPABASE_URL="$SUPABASE_URL"); fi
if [ -n "$SUPABASE_FUNCTIONS_URL" ]; then BUILD_SETTINGS+=(SUPABASE_FUNCTIONS_URL="$SUPABASE_FUNCTIONS_URL"); fi
if [ -n "$SUPABASE_ANON_KEY" ]; then BUILD_SETTINGS+=(SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"); fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild archive \
  -project 花计2046.xcodeproj \
  -scheme 花计2046 \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  "${BUILD_SETTINGS[@]}"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist scripts/ExportOptions/Development.plist \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

echo ""
echo "Development IPA 已生成：$EXPORT_PATH/花计2046.ipa"
echo "该 IPA 使用 365 天 Development Profile，可安装到已注册设备，无需每 7 天重装。"
