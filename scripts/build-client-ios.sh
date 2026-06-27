#!/usr/bin/env bash
# 在 Mac 上编译 iOS IPA（仅需 ios/ 目录即可）
# 用法:
#   cd ~/Downloads/ios
#   export IOS_DEVELOPMENT_TEAM=你的TeamID   # 可选：Xcode 已配好签名时可省略，脚本会自动读取
#   export IOS_CONTROL_MODE=wda
#   ./scripts/build-client-ios.sh wss://域名/ws/client 用户名 client-token [wda_url]
#
# 环境变量:
#   IOS_DEVELOPMENT_TEAM  — Team ID（未设置时从 Xcode 工程读取）
#   IOS_BUILD_CONFIG      — Debug 或 Release（默认 Debug，与 Xcode ⌘R 一致）
#   IOS_EXPORT_METHOD     — development / ad-hoc（默认 development）

set -euo pipefail

IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$IOS_DIR/AegisControlClient.xcodeproj"
SCHEME="AegisControlClient"
BUILD_ROOT="$IOS_DIR/build"
ARCHIVE_PATH="$BUILD_ROOT/AegisControlClient.xcarchive"
EXPORT_DIR="$BUILD_ROOT/export"
EXPORT_OPTS="$IOS_DIR/ExportOptions.plist"
OUT_DIR="$IOS_DIR/dist"

copy_ipa() {
  local src="$1"
  local out_name="$2"
  mkdir -p "$OUT_DIR"
  cp -f "$src" "$OUT_DIR/$out_name"
  echo "==> 已输出: $OUT_DIR/$out_name"
}

detect_team_from_xcode() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -configuration "${IOS_BUILD_CONFIG:-Debug}" \
    -destination "generic/platform=iOS" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^[[:space:]]*DEVELOPMENT_TEAM/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }'
}

detect_bundle_id_from_xcode() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -configuration "${IOS_BUILD_CONFIG:-Debug}" \
    -destination "generic/platform=iOS" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }'
}

if [[ "${1:-}" == "--copy" ]]; then
  SRC="${2:-}"
  USERNAME="${3:-}"
  OUT_NAME="aegis-ios.ipa"
  if [[ -n "$USERNAME" ]]; then
    safe=$(echo "$USERNAME" | tr -cd 'a-zA-Z0-9_-')
    OUT_NAME="aegis-ios-${safe}.ipa"
  fi
  [[ -f "$SRC" ]] || { echo "错误: 找不到 $SRC"; exit 1; }
  copy_ipa "$SRC" "$OUT_NAME"
  exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "错误: iOS IPA 只能在 macOS 上编译"
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "错误: 未找到 xcodebuild，请安装 Xcode"
  exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
  echo "错误: 找不到 $PROJECT"
  exit 1
fi

WS_URL="${1:-wss://127.0.0.1:9000/ws/client}"
USERNAME="${2:-user}"
CLIENT_TOKEN="${3:-}"
WDA_URL="${4:-}"
IPA_NAME="${5:-}"
CONTROL_MODE="${IOS_CONTROL_MODE:-vnc}"
VNC_HOST="${IOS_VNC_HOST:-}"
BUILD_CONFIG="${IOS_BUILD_CONFIG:-Debug}"
EXPORT_METHOD="${IOS_EXPORT_METHOD:-development}"

if [[ "$CONTROL_MODE" == "vnc" ]]; then
  WDA_URL=""
fi

OUT_NAME="aegis-ios.ipa"
if [[ -n "$IPA_NAME" ]]; then
  OUT_NAME="$IPA_NAME"
elif [[ -n "$USERNAME" && "$USERNAME" != "user" ]]; then
  safe=$(echo "$USERNAME" | tr -cd 'a-zA-Z0-9_-')
  OUT_NAME="aegis-ios-${safe}.ipa"
fi

TEAM="${IOS_DEVELOPMENT_TEAM:-}"
if [[ -z "$TEAM" ]]; then
  TEAM="$(detect_team_from_xcode || true)"
fi

BUNDLE_ID="$(detect_bundle_id_from_xcode || true)"

if [[ -z "$TEAM" ]]; then
  echo "错误: 未找到 DEVELOPMENT_TEAM"
  echo "  1) 在 Xcode 打开工程 → Signing & Capabilities → 选好 Team 并勾选 Automatically manage signing"
  echo "  2) 或执行: export IOS_DEVELOPMENT_TEAM=你的TeamID"
  exit 1
fi

echo "==> Team: $TEAM  Config: $BUILD_CONFIG  Bundle: ${BUNDLE_ID:-（自动）}"

mkdir -p "$BUILD_ROOT" "$OUT_DIR"

BUILD_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$BUILD_CONFIG"
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  DEVELOPMENT_TEAM="$TEAM"
  CODE_SIGN_STYLE=Automatic
  -allowProvisioningUpdates
  "AEGIS_EMBED_SERVER_URL=$WS_URL"
  "AEGIS_EMBED_USERNAME=$USERNAME"
  "AEGIS_EMBED_CLIENT_TOKEN=$CLIENT_TOKEN"
  "AEGIS_EMBED_WDA_URL=$WDA_URL"
  "AEGIS_EMBED_CONTROL_MODE=$CONTROL_MODE"
  "AEGIS_EMBED_VNC_HOST=$VNC_HOST"
)

echo "==> Archive (server=$WS_URL user=$USERNAME mode=$CONTROL_MODE)"
xcodebuild "${BUILD_ARGS[@]}" archive

if [[ -f "$EXPORT_OPTS" ]]; then
  rm -rf "$EXPORT_DIR"
  mkdir -p "$EXPORT_DIR"
  EXPORT_PLIST="$EXPORT_DIR/exportOptions.plist"
  cp "$EXPORT_OPTS" "$EXPORT_PLIST"
  /usr/libexec/PlistBuddy -c "Set :method $EXPORT_METHOD" "$EXPORT_PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :teamID string $TEAM" "$EXPORT_PLIST" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :teamID $TEAM" "$EXPORT_PLIST" 2>/dev/null || true
  if [[ -n "$BUNDLE_ID" ]]; then
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$BUNDLE_ID string" "$EXPORT_PLIST" 2>/dev/null || true
  fi

  echo "==> Export IPA ($EXPORT_METHOD)"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates

  IPA_SRC=$(find "$EXPORT_DIR" -name "*.ipa" | head -n1)
else
  IPA_SRC=""
fi

if [[ -z "$IPA_SRC" || ! -f "$IPA_SRC" ]]; then
  echo ""
  echo "错误: 导出 IPA 失败"
  echo ""
  echo "Xcode 能 ⌘R 运行，但终端 Archive 失败时，常见原因："
  echo "  • 未 export IOS_DEVELOPMENT_TEAM（现已自动从 Xcode 读取）"
  echo "  • Release 签名与 Debug 不同 → 已默认改用 Debug 配置"
  echo ""
  echo "也可在 Xcode 手动导出："
  echo "  Product → Archive → Distribute App → Development → 导出 IPA"
  echo "  然后: ./scripts/build-client-ios.sh --copy /path/to/exported.ipa $USERNAME"
  exit 1
fi

copy_ipa "$IPA_SRC" "$OUT_NAME"
echo "    安装后已预填用户 $USERNAME，打开 App 会自动连接"
