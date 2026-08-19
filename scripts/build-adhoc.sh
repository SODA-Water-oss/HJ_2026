#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

load_release_env() {
  if [ -z "${SUPABASE_URL:-}" ] && [ -f "$ROOT/Configs/Local.xcconfig" ]; then
    eval "$(grep -E '^(SUPABASE_URL|SUPABASE_FUNCTIONS_URL|SUPABASE_ANON_KEY)' "$ROOT/Configs/Local.xcconfig" | sed 's/[[:space:]]*=[[:space:]]*/="/' | sed 's/$/"/')"
  fi
}
load_release_env

if ! security find-identity -v -p codesigning | grep -q "Distribution"; then
  echo "错误：未找到有效的 Distribution 签名证书。" >&2
  echo "请先在 Xcode → Settings → Accounts 登录开发者账号并下载证书。" >&2
  echo "当前本机签名身份：" >&2
  security find-identity -v -p codesigning >&2 || true
  exit 1
fi

SUPABASE_URL="${SUPABASE_URL:?请设置 SUPABASE_URL}"
SUPABASE_FUNCTIONS_URL="${SUPABASE_FUNCTIONS_URL:?请设置 SUPABASE_FUNCTIONS_URL}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:?请设置 SUPABASE_ANON_KEY}"

ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/Build/AdHoc/花计2046.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/Build/AdHoc}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild archive \
  -project 花计2046.xcodeproj \
  -scheme 花计2046 \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-55MKGSFZJ9}" \
  SUPABASE_URL="$SUPABASE_URL" \
  SUPABASE_FUNCTIONS_URL="$SUPABASE_FUNCTIONS_URL" \
  SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist scripts/ExportOptions/AdHoc.plist \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

echo ""
echo "Ad Hoc IPA 已生成：$EXPORT_PATH/花计2046.ipa"
echo "可用 Apple Configurator 或设备管理安装到已注册的测试设备。"
