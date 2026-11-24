# Редизайн SnapKadr под Apple Liquid Glass & HIG: План реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Полный визуальный редизайн SnapKadr (Щёлк + Кадр) в современном стиле Apple Liquid Glass & HIG: глубокие материалы размытия, парящие капсулы, световые контуры, сдержанные монохромные SF Symbols и пружинные микроанимации.

**Architecture:** Обновление дизайн-системы `SuiteTheme` (материалы, градиентные контуры 1px, непрерывные скругления, Apple spring physics), перевод `NSPanel` главного меню в статус-баре на `NSVisualEffectView`, редизайн плиток и заголовков в `SuiteControlPanelView`, редизайн тулбара и плавающей панели опций инструментов скриншотов в `EditorWindowController` и `ToolOptionsPanel`, а также утончение окна настроек и HUD записи.

**Tech Stack:** macOS 14+, Swift 5.9, SwiftUI, AppKit (`NSVisualEffectView`, `NSPanel`, `NSImage.SymbolConfiguration`), Sparkle, Make (`make app-beta` / `make run-beta`).

## Global Constraints

- **Ветка разработки:** `feat/liquid-glass-redesign` в `SnapKadr/SnapKadr`.
- **Правило бета-версий:** Разработка и проверка только на бете (`dist/SnapKadrBeta.app`, bundle id `com.snapkadr.app.beta`).
- **Сборка и прогон:** `make app-beta` и `make run-beta`.
- **Сообщения коммитов:** строго на русском языке, формат `тип: краткое описание` (например `feat:`, `fix:`, `refactor:`).
- **Без атрибуции ИИ:** никаких упоминаний Cursor, AI, Co-authored-by или трейлеров агентов.
- **Иконки:** исключительно сдержанные монохромные SF Symbols (иерархический рендеринг), цвет только для функциональных состояний (красная точка записи, палитра аннотаций).

---

### Task 1: Архитектура дизайн-токенов Liquid Glass (`SuiteTheme.swift`)

**Files:**
- Modify: `SnapKadr/Sources/SnapKadr/SuiteTheme.swift`
- Test: сборка `make app-beta`

**Interfaces:**
- Consumes: SwiftUI `Color`, `Animation`, AppKit `NSColor`, `NSVisualEffectView`.
- Produces: `SuiteTheme.glassBackground`, `SuiteTheme.glassBorder`, `SuiteTheme.radiusPill`, `SuiteTheme.radiusContinuous(18)`, `SuiteTheme.springApple`, `SuiteTheme.pressScale`.

- [ ] **Step 1: Обновить токены SuiteTheme для стиля Liquid Glass**

Заменить глухие цвета и базовые анимации на:
```swift
enum SuiteTheme {
    // Liquid Glass Materials and Surfaces
    static let glassSurface = Color.white.opacity(0.06)
    static let glassSurfaceHover = Color.white.opacity(0.12)
    static let glassSurfaceActive = Color.white.opacity(0.18)
    
    // Specular border highlights (light reflection on top edge)
    static let borderSpecular = LinearGradient(
        colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let borderSubtle = Color.white.opacity(0.08)
    static let borderDivider = Color.white.opacity(0.12)
    
    // Functional colors (monochrome restrained)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.70)
    static let textTertiary = Color.white.opacity(0.40)
    static let record = Color(hex: 0xEF4444) // Only functional colored dot
    
    // Radii
    static let radiusPill: CGFloat = 999
    static let radiusPanel: CGFloat = 18
    static let radiusCard: CGFloat = 14
    static let radiusControl: CGFloat = 10
    
    // Spacing
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 12
    static let spaceL: CGFloat = 16
    static let spaceXL: CGFloat = 24
    
    // Apple Spring Animations
    static let springApple = Animation.spring(response: 0.30, dampingFraction: 0.82)
    static let springBouncy = Animation.spring(response: 0.28, dampingFraction: 0.75)
    static let pressDuration: Double = 0.10
}
```

- [ ] **Step 2: Проверить сборку проекта**

Run: `cd SnapKadr && swift build`
Expected: PASS

- [ ] **Step 3: Зафиксировать изменения в git**

```bash
git add Sources/SnapKadr/SuiteTheme.swift
git commit -m "refactor: токены и материалы liquid glass в SuiteTheme"
```

---

### Task 2: Меню в строке состояния (Status Bar Popover) на NSVisualEffectView (`SuiteStatusController.swift`)

**Files:**
- Modify: `SnapKadr/Sources/SnapKadr/SuiteStatusController.swift`
- Test: `make app-beta`

**Interfaces:**
- Consumes: `NSPanel`, `NSVisualEffectView`, `SuiteTheme`.
- Produces: полупрозрачная плавающая панель статуса с нативным размытием `vibrancy`.

- [ ] **Step 1: Заменить непрозрачный фон панели на NSVisualEffectView**

В `SuiteStatusController.swift` (метод `ensurePanel()`):
Заменить `chrome.layer?.backgroundColor` на подложку `NSVisualEffectView`:
```swift
let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: 420))
effect.material = .hudWindow
effect.blendingMode = .behindWindow
effect.state = .active
effect.wantsLayer = true
effect.layer?.cornerRadius = SuiteTheme.radiusPanel
effect.layer?.cornerCurve = .continuous
effect.layer?.masksToBounds = true
```

- [ ] **Step 2: Проверить компиляцию**

Run: `cd SnapKadr && swift build`
Expected: PASS

- [ ] **Step 3: Зафиксировать в git**

```bash
git add Sources/SnapKadr/SuiteStatusController.swift
git commit -m "feat: полупрозрачная подложка NSVisualEffectView в меню строки состояния"
```

---

### Task 3: Редизайн интерфейса всплывающей панели (`SuiteControlPanelView.swift`)

**Files:**
- Modify: `SnapKadr/Sources/SnapKadr/SuiteControlPanelView.swift`
- Test: `make app-beta`

**Interfaces:**
- Consumes: `SuiteTheme`, SF Symbols 6, `StenoSessionController`.
- Produces: обновленный экран `SuiteControlPanelView` с монохромными иконками и карточками.

- [ ] **Step 1: Обновить заголовок и бейдж BETA**

Заменить цветную иконку на монохромный `camera.aperture`, добавить нейтральный стеклянный бейдж `BETA` со скруглением капсулы.

- [ ] **Step 2: Перевести плитки действий на сдержанные монохромные SF Symbols**

- Снимок экрана: `crop` (Область), `macwindow` (Окно), `display` (Экран) с монохромным белым тинтом и высветлением при наведении.
- Запись экрана: `record.circle` (Запись), `rectangle.split.2x1` (Раскладка), `folder` (Проекты).
- Карточка стенографии / активного звонка: компактный виджет с белым пульсирующим индикатором активности и минималистичной кнопкой.

- [ ] **Step 3: Проверить сборку бета-приложения**

Run: `cd SnapKadr && make app-beta`
Expected: Сборка `dist/SnapKadrBeta.app` успешна.

- [ ] **Step 4: Зафиксировать в git**

```bash
git add Sources/SnapKadr/SuiteControlPanelView.swift
git commit -m "feat: сдержанный стиль Liquid Glass и монохромные иконки в меню бара"
```

---

### Task 4: Парящая капсула инструментов и панель опций редактора скриншотов (`EditorWindowController.swift` & `ToolOptionsPanel.swift`)

**Files:**
- Modify: `Snap/Snap/.worktrees/suite-embed/Snap/UI/EditorWindowController.swift`
- Modify: `Snap/Snap/.worktrees/suite-embed/Snap/UI/ToolOptionsPanel.swift`
- Test: `make app-beta`

**Interfaces:**
- Consumes: `NSVisualEffectView`, `EditorTool`, `ToolOptionsPanel`.
- Produces: парящий закругленный тулбар аннотаций со сдержанными монохромными иконками и полупрозрачная панель опций.

- [ ] **Step 1: Обновить OptionsHostView в ToolOptionsPanel.swift**

Заменить глухой серый фон на `NSVisualEffectView` со скруглением `999` (капсула) и 1px верхним световым бликом `NSColor.white.withAlphaComponent(0.18)`.

- [ ] **Step 2: Обновить стили иконок и кнопок в EditorWindowController.swift**

В `EditorToolbarHost` и `EditorIconButton`:
- Добавить непрерывное скругление кнопок.
- Использовать монохромный иерархический рендеринг символов.
- Плавный отклик при нажатии.

- [ ] **Step 3: Проверить сборку через suite-embed**

Run: `cd SnapKadr && make app-beta`
Expected: Сборка успешна, обновленные файлы Snap подхватываются в `SnapKit`.

- [ ] **Step 4: Зафиксировать изменения в git**

```bash
cd Snap/Snap/.worktrees/suite-embed
git add Snap/UI/EditorWindowController.swift Snap/UI/ToolOptionsPanel.swift
git commit -m "feat: парящая капсула и стеклянный стиль редактора скриншотов"
```

---

### Task 5: Окно настроек (`PreferencesWindowController.swift` & `PrefsShellView.swift`) и HUD записи (`RecordingHUDView.swift`)

**Files:**
- Modify: `SnapKadr/Sources/SnapKadr/PreferencesWindowController.swift`
- Modify: `SnapKadr/Sources/SnapKadr/PrefsShellView.swift`
- Modify: `Kadr/Kadr/.worktrees/multi-source-layout/Kadr/UI/Views/RecordingHUDView.swift`
- Test: `make app-beta`

**Interfaces:**
- Consumes: `SuiteTheme`, `KadrKit`.
- Produces: современное стеклянное окно настроек с монохромными табами и парящий HUD записи.

- [ ] **Step 1: Обновить PrefsShellView со стеклянными карточками**

Оформить секции настроек в закругленные матовые карточки со световым верхним контуром и монохромными системными символами.

- [ ] **Step 2: Обновить RecordingHUDView**

Парящая капсула таймера с моноширинными цифрами и красной точкой записи.

- [ ] **Step 3: Проверить сборку и запуск бета-версии**

Run: `cd SnapKadr && make run-beta`
Expected: `SnapKadrBeta.app` запускается в строке состояния, меню открывается со стеклянным размытием и монохромными иконками.

- [ ] **Step 4: Зафиксировать изменения в git**

```bash
cd SnapKadr
git add Sources/SnapKadr/PreferencesWindowController.swift Sources/SnapKadr/PrefsShellView.swift
git commit -m "feat: стеклянный стиль окна настроек и HUD записи"
```

---

### Task 6: Финальная сквозная верификация бета-версии

**Files:**
- Test: вся цепочка приложения `SnapKadrBeta`

- [ ] **Step 1: Сборка чистого бета-билда**

Run: `cd SnapKadr && make clean && make app-beta`
Expected: Успешная сборка `dist/SnapKadrBeta.app`.

- [ ] **Step 2: Запуск и проверка ключевых сценариев**

Run: `cd SnapKadr && make run-beta`
Проверить:
1. Клик по иконке в строке состояния: поповер открывается с эффектом Liquid Glass, иконки монохромные, клики по плиткам работают.
2. Снимок области: открывается капсула редактора аннотаций со сдержанными иконками инструментов и панелью опций.
3. Окно настроек: плавные переходы, аккуратные карточки.

- [ ] **Step 3: Финальный коммит и отчет**

```bash
cd SnapKadr
git commit --allow-empty -m "chore: готовность бета-билда с новым дизайном Liquid Glass"
```
