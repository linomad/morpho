# SwiftUI Pro Review (2026-03-29)

## Scope
- Reviewed `Sources/MorphoApp/**/*.swift` with `swiftui-pro` rules (`api/views/data/navigation/design/accessibility/performance/swift/hygiene`).
- Baseline verification: `swift test` passed (`98` tests, `0` failures).

## Findings

### Sources/MorphoApp/Views/Settings/Panes/HistorySettingsPane.swift

**Line 19-23: Destructive action lacks `confirmationDialog()` (rule: Navigation and presentation).**

```swift
// Before
Button(localized("settings.history.clear.button"), role: .destructive) {
    model.clearRunHistory()
    visibleLimit = 20
}
```

```swift
// After
@State private var showClearHistoryConfirm = false

Button(localized("settings.history.clear.button"), role: .destructive) {
    showClearHistoryConfirm = true
}
.confirmationDialog(
    localized("settings.history.clear.confirm.title"),
    isPresented: $showClearHistoryConfirm
) {
    Button(localized("settings.history.clear.confirm.action"), role: .destructive) {
        model.clearRunHistory()
        visibleLimit = 20
    }
}
```

**Line 70, 92: `.caption2` is too small for readability (rule: Design/Accessibility).**

```swift
// Before
Text("\(entry.sourceLanguageIdentifier) -> \(entry.targetLanguageIdentifier)")
    .font(.caption2)

Text(label)
    .font(.caption2)
```

```swift
// After
Text("\(entry.sourceLanguageIdentifier) -> \(entry.targetLanguageIdentifier)")
    .font(.caption)

Text(label)
    .font(.caption)
```

### Sources/MorphoApp/MorphoAppModel.swift

**Line 525-540: `NotificationCenter` observer token is discarded (rule: Hygiene/Performance).**

```swift
// Before
NotificationCenter.default.addObserver(
    forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    // ...
}
```

```swift
// After
private var reduceMotionObserver: NSObjectProtocol?

deinit {
    if let reduceMotionObserver {
        NotificationCenter.default.removeObserver(reduceMotionObserver)
    }
}

private func observeReduceMotionChanges() {
    reduceMotionObserver = NotificationCenter.default.addObserver(
        forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        Task { @MainActor in
            self?.syncReduceMotionState()
        }
    }
}
```

**Line 314: `DispatchQueue.main` in Combine chain under `@MainActor` model (rule: Swift Concurrency).**

```swift
// Before
statusCenter.$lastEntry
    .compactMap { $0 }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] entry in
        self?.lastStatus = entry
    }
```

```swift
// After
statusCenter.$lastEntry
    .compactMap { $0 }
    .sink { [weak self] entry in
        Task { @MainActor in
            self?.lastStatus = entry
        }
    }
```

**Line 7, 14-19 (and related view files): legacy `ObservableObject` stack (rule: Data flow).**

```swift
// Before
final class MorphoAppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
}

@StateObject private var model = MorphoAppModel()
@ObservedObject var model: MorphoAppModel
```

```swift
// After
@Observable @MainActor
final class MorphoAppModel {
    private(set) var settings: AppSettings
}

@State private var model = MorphoAppModel()
@Bindable var model: MorphoAppModel
```

### Sources/MorphoApp/Views/MorphoMenuView.swift

**Line 70, 85: `DispatchQueue.main.async` used for UI sequencing (rule: Swift Concurrency).**

```swift
// Before
DispatchQueue.main.async {
    // ...
    DispatchQueue.main.async {
        settingsWindow.level = .normal
    }
}
```

```swift
// After
Task { @MainActor in
    // ...
    await Task.yield()
    settingsWindow.level = .normal
}
```

### Sources/MorphoApp/Views/Settings/Panes/AboutSettingsPane.swift

**Line 39: force unwrap URL in UI path (rule: Swift safety, avoid force unwrap).**

```swift
// Before
Link(localized("settings.about.project_link"), destination: URL(string: "https://github.com/linomad/morpho")!)
```

```swift
// After
if let projectURL = URL(string: "https://github.com/linomad/morpho") {
    Link(localized("settings.about.project_link"), destination: projectURL)
}
```

### Sources/MorphoApp/Views/Settings/Panes/GeneralSettingsPane.swift
### Sources/MorphoApp/Views/Settings/Panes/LanguageSettingsPane.swift
### Sources/MorphoApp/Views/Settings/Panes/EngineSettingsPane.swift
### Sources/MorphoApp/Views/Settings/Panes/HotkeySettingsPane.swift

**Inline `Binding(get:set:)` appears repeatedly in `body` (rule: Data flow/Bindings).**

```swift
// Before
Toggle(localized("settings.hotkey.enable.toggle"), isOn: Binding(
    get: { model.hotkeyEnabled },
    set: { model.setHotkeyEnabled($0) }
))
```

```swift
// After (post-@Observable migration)
@Bindable var model: MorphoAppModel

Toggle(localized("settings.hotkey.enable.toggle"), isOn: $model.settings.isHotkeyEnabled)
    .onChange(of: model.settings.isHotkeyEnabled) { _, enabled in
        model.setHotkeyEnabled(enabled)
    }
```

## Prioritized Summary
1. **High:** add confirmation for history clear action to prevent accidental irreversible data loss.
2. **High:** migrate observation/data flow to modern `@Observable` + `@Bindable` to simplify state ownership and reduce view-layer binding boilerplate.
3. **Medium:** remove `DispatchQueue.main.async` usage in view/model paths and adopt structured concurrency for predictable UI sequencing.
4. **Medium:** retain/remove NotificationCenter observer token to avoid observer lifecycle leaks.
5. **Medium:** remove force unwrap in About pane link construction.
6. **Low:** replace `.caption2` usage in history rows with more readable typography.
