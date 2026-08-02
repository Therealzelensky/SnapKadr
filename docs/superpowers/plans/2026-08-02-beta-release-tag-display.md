# Plan: beta release tag in Version prefs

> Spec: `docs/superpowers/specs/2026-08-02-beta-release-tag-display-design.md`

## Task 1: Plist + ship env

**Files:** `scripts/build_app.sh`, `scripts/ship_beta.sh`

- In `ship_beta.sh` after `TAG=` is known: `export SNAPKADR_TAG="$TAG"`.
- In `build_app.sh` for beta: `RELEASE_TAG="${SNAPKADR_TAG:-v${MARKETING_VERSION}-beta.dev}"`, write:
  ```xml
  <key>SnapKadrReleaseTag</key>
  <string>${RELEASE_TAG}</string>
  ```
- Stable: omit key (or empty).

## Task 2: Branding + Version UI

**Files:** `AppBranding.swift`, `PrefsVersionView.swift`

- Add `releaseLabel`: if `SnapKadrReleaseTag` non-empty use it; else `shortVersion`.
- Prefs primary text: `releaseLabel` (no “Версия ” prefix when tag already has `v…`); English same.
- Keep click → `build`.

## Task 3: Verify

- `make app-beta` → `defaults read … SnapKadrReleaseTag` shows `v0.1.0-beta.dev` (or ship tag).
- Open prefs Version: primary line is tag; click shows build.
