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
