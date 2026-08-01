# Каналы (6 SKU)

| Product | Release | Beta | Bundle ID release / beta |
|---|---|---|---|
| Щёлк | Snap.app | SnapBeta.app | `com.snap.app` / `com.snap.app.beta` |
| Кадр | Kadr.app | KadrBeta.app | `com.kadr.app` / `com.kadr.app.beta` |
| Щёлк.Кадр | SnapKadr.app | SnapKadrBeta.app | `com.snapkadr.app` / `com.snapkadr.app.beta` |

## Routing

- Only Snap → Snap Beta → Snap release
- Only Kadr → Kadr Beta → Kadr release
- Suite / shared → SnapKadr Beta → SnapKadr release

Suite beta is **autonomous** (SnapKit + KadrKit in-process). Standalone Snap/Kadr remain optional dogfood alongside suite.

Кадр Beta must never be renamed into suite beta.

See also: [unification spec](https://github.com/Therealzelensky/Zelensky) (monorepo docs) / local `Zelensky/docs/superpowers/specs/2026-07-31-snapkadr-unification-design.md`.

## Ship suite beta

From a feature branch (or `main`):

```bash
make ship-beta
# prompts: Merge '<branch>' → main? [y/N]
```

- Non-interactive merge: `SHIP_BETA_MERGE=1 make ship-beta`
- Override tag: `SHIP_BETA_TAG=v0.1.0-beta.99 make ship-beta`

Requires a clean tracked working tree, GitHub auth (`gh` / `GH_TOKEN` / git credentials), and a Sparkle private key (`keys/ed25519` or keychain account from `generate_keys`).

## Install + updates (suite beta)

- Landing download: **DMG** (`SnapKadrBeta.dmg`) — drag into Applications
- Sparkle feed (`appcast-beta.xml`): **ZIP** enclosure (`SnapKadrBeta.zip`) — in-place update, not Downloads
- Dogfood may use Apple Development signing on the developer Mac

### Public landing gate (not done yet)

Before claiming the landing works on arbitrary Macs:

1. **Developer ID Application** certificate in the keychain
2. Sign with Developer ID (not Apple Development)
3. `SNAPKADR_NOTARIZE=1` (or equivalent notarytool profile) + staple
4. Verify Gatekeeper: `spctl -a -vv dist/SnapKadrBeta.app` → accepted / notarized
