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

---

## Регламент: улучшения беты → публикация обновления (suite)

Цель: после правок на бете выкатить обновление так, чтобы лендинг качал **DMG**, а уже установленные беты получили **in-place Sparkle** (zip), без файлов в «Загрузки».

### Жёсткие правила

1. **Сначала бета.** Фичи/фиксы suite — в ветке → dogfood на `SnapKadrBeta` → только потом `make ship-beta`. Не пушить «сразу в стабильный» канал (`appcast.xml` / `SnapKadr.app`), пока бета не ОК.
2. **Одна команда ship.** Публикация беты = `make ship-beta` из репо SnapKadr. Не руками править appcast/CTA «на глаз» и не заливать только zip в Release.
3. **Два артефакта.** Релиз всегда содержит:
   - `SnapKadrBeta.dmg` — CTA лендинга (первая установка)
   - `SnapKadrBeta.zip` — enclosure в `appcast-beta.xml` (обновление)
4. **Чистое дерево.** Перед ship — без грязных *tracked* файлов (untracked можно). Иначе скрипт падает.
5. **Проверка сборкой.** Маркетинг `0.1.0` может не меняться — смотри `CFBundleVersion` / `sparkle:version` (timestamp build). После update в `/Applications/SnapKadrBeta.app` build должен совпасть с appcast.

### Поток (каждый цикл улучшений)

```
ветка с фиксом/фичей
  → merge в main (через ship prompt или заранее)
  → make ship-beta          # build, dmg+zip, GitHub Release, appcast, CTA, push
  → Pages обновится (1–2 мин)
  → ручной прогон:
       • новый юзер: лендос → DMG → Программы
       • уже стоит бета: Версия → «Проверить обновления…»
  → OK пользователя
  → (позже) стабильный релиз — отдельный шаг, не этот регламент
```

### Команды

Из корня репо SnapKadr:

```bash
# На feature-ветке — ship сам спросит merge → main:
make ship-beta

# Уже на main, без вопросов:
make ship-beta

# Без TTY / CI-подобно:
SHIP_BETA_MERGE=1 make ship-beta

# Явный тег (редко нужно):
SHIP_BETA_TAG=v0.1.0-beta.99 make ship-beta
```

Нужно: GitHub auth (`gh` / `GH_TOKEN` / git credentials), Sparkle private key (keychain account `snapkadr` или `keys/ed25519`).

### Что делает `ship-beta` (не дублировать руками)

1. При необходимости merge текущей ветки → `main`
2. Следующий тег `v0.1.0-beta.N`
3. `make app-beta` + подпись
4. Zip + EdDSA `sign_update` + DMG (`scripts/make_dmg.sh`)
5. GitHub prerelease: upload **zip и dmg**
6. `docs/index.html` CTA → `.dmg`
7. `docs/appcast-beta.xml` enclosure → `.zip` + signature + length + **новый** `sparkle:version`
8. `docs/check-landings.sh`
9. Commit `docs: ship <tag>`, push `main` (+ tag)

Если `git push` тега ругается «already exists», а assets/docs уже на `main` — проверить, что Release содержит оба файла и appcast на Pages свежий; тег чинить отдельно, не пересобирать «вслепую».

### Чеклист после ship (минимум)

- [ ] https://therealzelensky.github.io/SnapKadr/ — кнопка качает **`.dmg`**, не `.zip`
- [ ] https://therealzelensky.github.io/SnapKadr/appcast-beta.xml — enclosure **`.zip`**, `sparkle:version` = только что собранный build
- [ ] Уже установленная бета: обновление на месте, в «Загрузки» нового архива нет
- [ ] `defaults read /Applications/SnapKadrBeta.app/Contents/Info CFBundleVersion` == версия из appcast

### Dogfood без Щёлка/Кадра

Для чистого теста suite: `killall Snap SnapApp Kadr KadrBeta SnapKadr SnapKadrBeta` (стабильные `.app` в Программах можно не удалять). Suite автономен — companion не обязателен.

### Стабильный релиз (пока не этот цикл)

Когда бета стабильно ОК и есть явное «в релиз»:

- Отдельный ship stable (`appcast.xml`, `SnapKadr.dmg` / zip, bundle `com.snapkadr.app`)
- **Не** мержить бета-лендинг в стабильный «заодно»
- Публичный «любой Mac» — только после Developer ID + notarize (см. ниже)

Пока стабильного ship-команды нет — не импровизировать копированием beta-артефактов в release channel.

---

## Ship suite beta (кратко)

```bash
make ship-beta
```

См. полный регламент выше.

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
