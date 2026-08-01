#!/usr/bin/env bash
# Acceptance tests for SnapKadr unification (spec §9 + build smoke).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); echo "PASS  $*"; }
ko() { FAIL=$((FAIL+1)); echo "FAIL  $*"; }

need_app() {
  local path="$1" id="$2" label="$3"
  if [[ ! -d "$path" ]]; then
    ko "$label missing at $path"
    return
  fi
  local got
  got="$(defaults read "${path}/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
  if [[ "$got" == "$id" ]]; then
    ok "$label bundle id = $id"
  else
    ko "$label bundle id want=$id got=$got"
  fi
}

echo "==> SnapKadr acceptance"

need_app "$ROOT/dist/SnapKadr.app" "com.snapkadr.app" "SnapKadr"
need_app "$ROOT/dist/SnapKadrBeta.app" "com.snapkadr.app.beta" "SnapKadrBeta"

# Companion apps (optional paths — check common locations)
SNAP_ROOT="${SNAP_ROOT:-/Users/admin/Projects/Zelensky/Snap}"
KADR_ROOT="${KADR_ROOT:-/Users/admin/Projects/Zelensky/Kadr/.worktrees/multi-source-layout}"
need_app "$SNAP_ROOT/dist/Snap.app" "com.snap.app" "Snap"
need_app "$SNAP_ROOT/dist/SnapBeta.app" "com.snap.app.beta" "SnapBeta"
need_app "$KADR_ROOT/dist/Kadr.app" "com.kadr.app" "Kadr"
need_app "$KADR_ROOT/dist/KadrBeta.app" "com.kadr.app.beta" "KadrBeta"

# Suite beta Sparkle keys in Info.plist
FEED="$(defaults read "$ROOT/dist/SnapKadrBeta.app/Contents/Info" SUFeedURL 2>/dev/null || true)"
if [[ "$FEED" == *"appcast-beta.xml"* ]]; then
  ok "SnapKadrBeta SUFeedURL=$FEED"
else
  ko "SnapKadrBeta SUFeedURL unexpected: $FEED"
fi

PUB="$(defaults read "$ROOT/dist/SnapKadrBeta.app/Contents/Info" SUPublicEDKey 2>/dev/null || true)"
if [[ -n "$PUB" ]]; then
  ok "SnapKadrBeta SUPublicEDKey present"
else
  ko "SnapKadrBeta SUPublicEDKey missing"
fi

if [[ -d "$ROOT/dist/SnapKadrBeta.app/Contents/Frameworks/Sparkle.framework" ]]; then
  ok "Sparkle.framework bundled"
else
  ko "Sparkle.framework missing"
fi

# Companion Sparkle feeds
SNAP_FEED="$(defaults read "$SNAP_ROOT/dist/SnapBeta.app/Contents/Info" SUFeedURL 2>/dev/null || true)"
if [[ "$SNAP_FEED" == *"appcast-snap-beta.xml"* ]]; then
  ok "SnapBeta SUFeedURL=$SNAP_FEED"
else
  ko "SnapBeta SUFeedURL unexpected: $SNAP_FEED"
fi
KADR_FEED="$(defaults read "$KADR_ROOT/dist/KadrBeta.app/Contents/Info" SUFeedURL 2>/dev/null || true)"
if [[ "$KADR_FEED" == *"appcast-kadr-beta.xml"* ]]; then
  ok "KadrBeta SUFeedURL=$KADR_FEED"
else
  ko "KadrBeta SUFeedURL unexpected: $KADR_FEED"
fi
if [[ -d "$SNAP_ROOT/dist/SnapBeta.app/Contents/Frameworks/Sparkle.framework" ]]; then
  ok "SnapBeta Sparkle.framework bundled"
else
  ko "SnapBeta Sparkle.framework missing"
fi
if [[ -d "$KADR_ROOT/dist/KadrBeta.app/Contents/Frameworks/Sparkle.framework" ]]; then
  ok "KadrBeta Sparkle.framework bundled"
else
  ko "KadrBeta Sparkle.framework missing"
fi

# Pages + appcast HTTP
for url in \
  "https://therealzelensky.github.io/SnapKadr/" \
  "https://therealzelensky.github.io/SnapKadr/appcast-beta.xml" \
  "https://therealzelensky.github.io/SnapKadr/appcast-snap-beta.xml" \
  "https://therealzelensky.github.io/SnapKadr/appcast-kadr-beta.xml" \
  "https://github.com/Therealzelensky/app-feedback" \
  "https://github.com/Therealzelensky/SnapKadr/releases/tag/v0.1.0-beta.3" \
  "https://github.com/Therealzelensky/SnapKadr/releases/tag/snap-v1.0.0-beta.1" \
  "https://github.com/Therealzelensky/SnapKadr/releases/tag/kadr-v0.1.0-beta.1"
do
  code="$(curl -sS -o /dev/null -w '%{http_code}' -L "$url" || echo 000)"
  if [[ "$code" == "200" ]]; then
    ok "HTTP 200 $url"
  else
    ko "HTTP $code $url"
  fi
done

# Feedback template
code="$(curl -sS -o /dev/null -w '%{http_code}' -L \
  'https://github.com/Therealzelensky/app-feedback/issues/new?template=beta_feedback.yml' || echo 000)"
# GitHub may 302/200 for issues/new when logged out → accept 200/302
if [[ "$code" == "200" || "$code" == "302" ]]; then
  ok "feedback template reachable ($code)"
else
  ko "feedback template HTTP $code"
fi

# Source presence
for f in \
  Sources/SnapKadr/PrefsShellView.swift \
  Sources/SnapKadr/PrefsTypes.swift \
  Sources/SnapKadr/PrefsGeneralView.swift \
  Sources/SnapKadr/PrefsVersionView.swift \
  Sources/SnapKadr/PrefsKadrView.swift \
  Sources/SnapKadr/PrefsHotkeysView.swift \
  Sources/SnapKadr/SuiteStatusController.swift \
  Sources/SnapKadr/UpdateService.swift \
  Sources/SnapKadr/FeedbackService.swift \
  docs/index.html \
  docs/appcast-beta.xml \
  docs/appcast-snap-beta.xml \
  docs/appcast-kadr-beta.xml \
  Resources/MenuBarIcon.png \
  Resources/AppIcon.icns \
  Resources/Brand/NeonIris.png \
  scripts/render_suite_brand.swift
do
  if [[ -f "$ROOT/$f" ]]; then
    ok "source $f"
  else
    ko "missing $f"
  fi
done

# Prefs tabs mentioned in source
if grep -q 'case general, kadr, snap, hotkeys, notifications, version' "$ROOT/Sources/SnapKadr/PrefsTypes.swift"; then
  ok "prefs tabs enum present"
else
  ko "prefs tabs enum missing"
fi

SNAP_SRC="${SNAP_SRC:-/Users/admin/Projects/Zelensky/Snap/.worktrees/prefs-polish}"
if [[ ! -d "$SNAP_SRC" ]]; then
  SNAP_SRC="/Users/admin/Projects/Zelensky/Snap"
fi

if grep -q 'PrefsNotificationsView' "$ROOT/Sources/SnapKadr/PrefsShellView.swift" \
  && grep -q 'NotchHUDKit' "$ROOT/Package.swift"; then
  ok "Notifications tab + NotchHUDKit wired"
else
  ko "Notifications tab / NotchHUDKit missing"
fi

if grep -q 'SuiteKadrHotkey' "$ROOT/Sources/SnapKadr/PrefsHotkeysView.swift" \
  && grep -q 'reloadKadrHotkeys' "$ROOT/Sources/SnapKadr/SuiteHotkeyMonitor.swift"; then
  ok "Kadr hotkeys UI + monitor wired"
else
  ko "Kadr hotkeys missing"
fi

if grep -q 'WindowBGTile' "$SNAP_SRC/Snap/UI/SnapPrefsContent.swift" \
  && grep -q 'backdropImagePath' "$SNAP_SRC/Snap/UI/SnapPrefsContent.swift"; then
  ok "SnapPrefs window tiles + backdrop path state"
else
  ko "SnapPrefs window tiles / backdrop state missing"
fi

if grep -q 'Therealzelensky' "$ROOT/Sources/SnapKadr/PrefsVersionView.swift" \
  && grep -q 'developerGitHubURL' "$ROOT/Sources/SnapKadr/AppBranding.swift"; then
  ok "Version tab developer card"
else
  ko "Version developer card missing"
fi

if grep -q 'Проверить обновления' "$ROOT/Sources/SnapKadr/PrefsVersionView.swift"; then
  ok "Check for Updates UI in Версия"
else
  ko "Check for Updates UI missing"
fi

# Prefs shell (sidebar, no segmented, no Save)
if grep -q 'PrefsShellView' "$ROOT/Sources/SnapKadr/PreferencesWindowController.swift" \
  && ! grep -rq 'pickerStyle(.segmented)' "$ROOT/Sources/SnapKadr" --include='*.swift'; then
  ok "prefs sidebar shell (no segmented)"
else
  ko "prefs shell missing / segmented still present"
fi

if ! grep -rqE 'Button\(L10n\.tr\("Сохранить"' "$ROOT/Sources/SnapKadr" --include='*.swift'; then
  ok "no Save button in suite prefs"
else
  ko "Save button still present"
fi

if grep -q 'SnapPrefsContent' "$ROOT/Sources/SnapKadr/PrefsShellView.swift" \
  && grep -q 'SuiteHotkeyMonitor' "$ROOT/Sources/SnapKadr/AppDelegate.swift"; then
  ok "Snap prefs + hotkey monitor wired"
else
  ko "Snap prefs / hotkeys not wired"
fi

if grep -q 'SuiteKadrSettings' "$ROOT/Sources/SnapKadr/PrefsKadrView.swift"; then
  ok "Kadr prefs bound to SuiteKadrSettings"
else
  ko "Kadr prefs missing"
fi

# Single status item (not dual)
if grep -q 'SuiteStatusController' "$ROOT/Sources/SnapKadr/AppDelegate.swift" \
  && ! grep -q 'DualStatusController' "$ROOT/Sources/SnapKadr/AppDelegate.swift"; then
  ok "single SuiteStatusController wired"
else
  ko "SuiteStatusController not wired / dual still present"
fi
if grep -q 'menuBarIcon' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift"; then
  ok "SuiteStatusController uses Kadr menuBarIcon"
else
  ko "menuBarIcon missing on suite status"
fi
if grep -q 'SuiteControlPanelView' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && grep -q 'togglePanel' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift"; then
  ok "LMB opens Kadr-style suite panel"
else
  ko "suite panel not wired on LMB"
fi
if grep -q 'KadrEngine.shared.openCaptureBar' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && grep -q 'rightMouseUp' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift"; then
  ok "RMB/⌥ opens in-process capture bar"
else
  ko "RMB capture shortcut missing"
fi

# E1: Snap in-process (no snap:// companion)
if grep -q 'SnapEngine.shared.captureArea' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && grep -q 'SnapEngine.shared.captureFull' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && grep -q 'SnapEngine.shared.captureActiveWindow' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && ! grep -qE 'openSnap\(' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift"; then
  ok "Snap panel actions use SnapEngine (no openSnap)"
else
  ko "Snap still companion / SnapEngine not wired"
fi
if grep -q 'SnapEngine.shared.prepare' "$ROOT/Sources/SnapKadr/AppDelegate.swift"; then
  ok "SnapEngine.prepare on suite launch"
else
  ko "SnapEngine.prepare missing on launch"
fi

# E2: Kadr in-process (no kadr:// companion)
if grep -q 'KadrEngine.shared' "$ROOT/Sources/SnapKadr/SuiteStatusController.swift" \
  && grep -q 'import KadrKit' "$ROOT/Sources/SnapKadr/AppDelegate.swift" \
  && grep -q 'KadrKit' "$ROOT/Package.swift" \
  && [[ ! -f "$ROOT/Sources/SnapKadr/CompanionLaunch.swift" ]] \
  && ! grep -rqE 'CompanionLaunch|openKadr\(|kadr://|kadr-beta://' "$ROOT/Sources/SnapKadr" --include='*.swift'; then
  ok "KadrKit in-process (no Kadr companion URL)"
else
  ko "Kadr companion still present / KadrKit not wired"
fi
if grep -q 'KadrEngine.shared.prepare' "$ROOT/Sources/SnapKadr/AppDelegate.swift"; then
  ok "KadrEngine.prepare on suite launch"
else
  ko "KadrEngine.prepare missing on launch"
fi

# rpath for Sparkle
if otool -l "$ROOT/dist/SnapKadrBeta.app/Contents/MacOS/SnapKadrBeta" 2>/dev/null | grep -q '@executable_path/../Frameworks'; then
  ok "SnapKadrBeta has Frameworks rpath"
else
  ko "SnapKadrBeta missing Frameworks rpath"
fi

if [[ -f "$ROOT/dist/SnapKadrBeta.app/Contents/Resources/MenuBarIcon.png" ]]; then
  ok "MenuBarIcon bundled in SnapKadrBeta"
else
  ko "MenuBarIcon not in SnapKadrBeta Resources"
fi

if [[ -f "$ROOT/dist/SnapKadrBeta.app/Contents/Resources/AppIcon.icns" ]]; then
  ok "AppIcon.icns bundled in SnapKadrBeta"
else
  ko "AppIcon.icns not in SnapKadrBeta Resources"
fi

icon_file="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$ROOT/dist/SnapKadrBeta.app/Contents/Info.plist" 2>/dev/null || true)"
if [[ "$icon_file" == "AppIcon" ]]; then
  ok "CFBundleIconFile=AppIcon"
else
  ko "CFBundleIconFile missing or wrong ($icon_file)"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
