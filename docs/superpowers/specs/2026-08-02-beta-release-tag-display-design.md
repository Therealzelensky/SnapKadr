# Design: beta release tag in Version prefs

**Date:** 2026-08-02  
**Status:** approved  
**Product:** SnapKadr Beta (`com.snapkadr.app.beta`)

## Goal

On the Version prefs tab, the primary line shows the ship tag (e.g. `v0.1.0-beta.8`) instead of only `Версия 0.1.0`. Click still toggles to the numeric `CFBundleVersion` build.

## Non-goals

- Changing Sparkle comparison (still `sparkle:version` = `CFBundleVersion`)
- Renaming `CFBundleShortVersionString` away from marketing `0.1.0`
- Stable channel UI (keeps short version string)

## Approach

Bake `SnapKadrReleaseTag` into Info.plist at assemble time.

| Env / key | Beta ship | Local `make app-beta` | Stable |
|---|---|---|---|
| `SNAPKADR_TAG` | `v0.1.0-beta.N` from `ship_beta.sh` | `v${VERSION}-beta.dev` if unset | omitted / empty |
| `CFBundleShortVersionString` | `0.1.0` | `0.1.0` | marketing |
| `CFBundleVersion` | timestamp build | timestamp build | build |

## UI

- Default label: `AppBranding.releaseLabel` → tag when present, else `shortVersion`
- Toggle (existing): show `build`
- Accessibility: mention both tag and build

## Files

- `scripts/build_app.sh` — write plist key
- `scripts/ship_beta.sh` — `export SNAPKADR_TAG="$TAG"`
- `Sources/SnapKadr/AppBranding.swift` — `releaseLabel`
- `Sources/SnapKadr/PrefsVersionView.swift` — use `releaseLabel`
