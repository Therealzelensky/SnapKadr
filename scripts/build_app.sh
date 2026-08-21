#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

VARIANT="${SNAPKADR_VARIANT:-stable}"
SWIFT_PRODUCT="SnapKadr"

# Public EdDSA key for Sparkle (generated once; private key lives in CI secrets / keys/).
# Placeholder replaced by scripts/ensure_sparkle_keys.sh if missing.
SU_PUBLIC_ED_KEY="${SU_PUBLIC_ED_KEY:-}" # filled below from keys/ed25519.pub if present

if [[ -f "$ROOT/keys/ed25519.pub" ]]; then
  SU_PUBLIC_ED_KEY="$(tr -d '\n' < "$ROOT/keys/ed25519.pub")"
fi

# Monotonic build from env or timestamp
MARKETING_VERSION="${SNAPKADR_VERSION:-0.1.0}"
BUILD_NUMBER="${SNAPKADR_BUILD:-$(date +%Y%m%d%H%M)}"

if [[ "$VARIANT" == "beta" ]]; then
  APP_NAME="SnapKadrBeta"
  APP_BUNDLE_NAME="SnapKadrBeta"
  BUNDLE_ID="com.snapkadr.app.beta"
  DISPLAY_NAME="Snap.Kadr Beta"
  RELEASE_TAG="${SNAPKADR_TAG:-v${MARKETING_VERSION}-beta.dev}"
  BETA_PLIST_KEY=$'	<key>SnapKadrBetaBuild</key>\n	<true/>\n	<key>SnapKadrReleaseTag</key>\n	<string>'"${RELEASE_TAG}"$'</string>\n'
  FEED_URL="https://therealzelensky.github.io/SnapKadr/appcast-beta.xml"
else
  APP_NAME="SnapKadr"
  APP_BUNDLE_NAME="SnapKadr"
  BUNDLE_ID="com.snapkadr.app"
  DISPLAY_NAME="Snap.Kadr"
  BETA_PLIST_KEY=""
  FEED_URL="https://therealzelensky.github.io/SnapKadr/appcast.xml"
fi

APP_DIR="$ROOT/dist/${APP_BUNDLE_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
FRAMEWORKS_DIR="$CONTENTS/Frameworks"

echo "==> Building ${APP_BUNDLE_NAME} (${VARIANT}, release)..."
swift build -c release --product "$SWIFT_PRODUCT"

BIN="$(swift build -c release --show-bin-path)/${SWIFT_PRODUCT}"
if [[ ! -x "$BIN" ]]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi

echo "==> Assembling ${APP_BUNDLE_NAME}.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$BIN" "$MACOS_DIR/$APP_NAME"
# SPM links Sparkle via @rpath; point rpath at bundled Frameworks.
if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$MACOS_DIR/$APP_NAME"
fi

# Suite brand: menu bar template + Dock/Finder icon (beta gets AppIcon with β badge)
for f in MenuBarIcon.png "MenuBarIcon@2x.png"; do
  if [[ -f "$ROOT/Resources/$f" ]]; then
    cp "$ROOT/Resources/$f" "$RESOURCES_DIR/$f"
  fi
done
if [[ -d "$ROOT/Resources/Brand" ]]; then
  mkdir -p "$RESOURCES_DIR/Brand"
  cp -R "$ROOT/Resources/Brand/." "$RESOURCES_DIR/Brand/"
fi
if [[ "$VARIANT" == "beta" && -f "$ROOT/Resources/AppIcon-Beta.icns" ]]; then
  cp "$ROOT/Resources/AppIcon-Beta.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Bundle Sparkle.framework from SPM build
SPARKLE_FW="$(swift build -c release --show-bin-path)/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
  cp -R "$SPARKLE_FW" "$FRAMEWORKS_DIR/"
elif [[ -d "$ROOT/.build/artifacts" ]]; then
  FOUND="$(find "$ROOT/.build" -type d -name 'Sparkle.framework' | head -1 || true)"
  if [[ -n "$FOUND" ]]; then
    cp -R "$FOUND" "$FRAMEWORKS_DIR/"
  fi
fi

SU_KEY_XML=""
if [[ -n "$SU_PUBLIC_ED_KEY" ]]; then
  SU_KEY_XML=$'	<key>SUPublicEDKey</key>\n	<string>'"${SU_PUBLIC_ED_KEY}"$'</string>\n'
fi

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>ru</string>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${APP_BUNDLE_NAME}</string>
	<key>CFBundleDisplayName</key>
	<string>${DISPLAY_NAME}</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
${BETA_PLIST_KEY}	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${MARKETING_VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD_NUMBER}</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 Snap.Kadr. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSCameraUsageDescription</key>
	<string>Щёлк.Кадр использует камеру для наложения веб-камеры на запись экрана.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Щёлк.Кадр записывает микрофон вместе с экраном.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Щёлк.Кадр создаёт субтитры из записи голоса.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>Щёлк.Кадр создаёт заметку с текстом транскрипта в приложении Заметки.</string>
	<key>SUFeedURL</key>
	<string>${FEED_URL}</string>
	<key>SUEnableAutomaticChecks</key>
	<true/>
${SU_KEY_XML}	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Распознать текст</string>
			</dict>
			<key>NSMessage</key>
			<string>transcribeService</string>
			<key>NSPortName</key>
			<string>${APP_NAME}</string>
			<key>NSRequiredContext</key>
			<dict>
				<key>NSFileTypes</key>
				<array>
					<string>public.audio</string>
					<string>public.movie</string>
					<string>public.audiovisual-content</string>
				</array>
			</dict>
			<key>NSSendTypes</key>
			<array>
				<string>public.file-url</string>
				<string>NSFilenamesPboardType</string>
			</array>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.audio</string>
				<string>public.movie</string>
				<string>public.audiovisual-content</string>
			</array>
		</dict>
	</array>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeName</key>
			<string>Проект Кадра</string>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>LSHandlerRank</key>
			<string>Owner</string>
			<key>LSTypeIsPackage</key>
			<true/>
			<key>CFBundleTypeExtensions</key>
			<array>
				<string>kadr</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

SIGN_ID="${SNAPKADR_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' \
    | head -1)"
fi
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:.*\)".*/\1/p' \
    | head -1)"
fi
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID="-"
  echo "==> Codesign: ad-hoc"
else
  echo "==> Codesign: $SIGN_ID"
fi

# Sign Sparkle inside-out (no --deep), then the app with Hardened Runtime.
ENTITLEMENTS_FILE="$ROOT/SnapKadr.entitlements"
TIMESTAMP_FLAG=(--timestamp)
if [[ "$SIGN_ID" == "-" ]]; then
  TIMESTAMP_FLAG=(--timestamp=none)
fi
sign_one() {
  local target="$1"
  shift
  codesign --force --sign "$SIGN_ID" --options runtime "${TIMESTAMP_FLAG[@]}" "$@" "$target"
}

if [[ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]]; then
  SPARKLE="$FRAMEWORKS_DIR/Sparkle.framework"
  SPARKLE_B="$SPARKLE/Versions/B"
  echo "==> Codesign Sparkle nested binaries (Hardened Runtime)"
  # Inside-out per Sparkle docs: XPC → Autoupdate/Updater → framework (no --deep).
  # Downloader.xpc (≥2.6): preserve entitlements metadata.
  for xpc in "$SPARKLE_B"/XPCServices/*.xpc; do
    [[ -d "$xpc" ]] || continue
    if [[ "$(basename "$xpc")" == "Downloader.xpc" ]]; then
      sign_one "$xpc" --preserve-metadata=entitlements
    else
      sign_one "$xpc"
    fi
  done
  if [[ -d "$SPARKLE_B/Updater.app" ]]; then
    sign_one "$SPARKLE_B/Updater.app"
  fi
  if [[ -f "$SPARKLE_B/Autoupdate" ]]; then
    sign_one "$SPARKLE_B/Autoupdate"
  fi
  sign_one "$SPARKLE"
fi

if [[ -f "$ENTITLEMENTS_FILE" ]]; then
  echo "==> Entitlements: $ENTITLEMENTS_FILE (Hardened Runtime)"
  sign_one "$APP_DIR" --entitlements "$ENTITLEMENTS_FILE" --identifier "$BUNDLE_ID"
else
  echo "==> WARNING: SnapKadr.entitlements missing — Continuity/camera may be black"
  sign_one "$APP_DIR" --identifier "$BUNDLE_ID"
fi

# Optional notarize when Developer ID + credentials present
if [[ "${SNAPKADR_NOTARIZE:-0}" == "1" ]]; then
  echo "==> Notarizing..."
  NOTARY_ZIP="$(mktemp -t ${APP_BUNDLE_NAME}.XXXXXX.zip)"
  ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" \
    --apple-id "${APP_STORE_APPLE_ID:?}" \
    --team-id "${APP_STORE_TEAM_ID:?}" \
    --password "${APP_STORE_APP_SPECIFIC_PASSWORD:?}" \
    --wait
  rm -f "$NOTARY_ZIP"
  xcrun stapler staple "$APP_DIR"
fi

INSTALL_FLAG="${SNAPKADR_INSTALL:-0}"
if [[ "$INSTALL_FLAG" == "1" ]]; then
  ditto "$APP_DIR" "/Applications/${APP_BUNDLE_NAME}.app"
  sign_one "/Applications/${APP_BUNDLE_NAME}.app" --identifier "$BUNDLE_ID"
  echo "==> Done: /Applications/${APP_BUNDLE_NAME}.app"
else
  echo "==> Done: $APP_DIR"
  echo "    Run: killall ${APP_NAME} 2>/dev/null; open \"$APP_DIR\""
fi
