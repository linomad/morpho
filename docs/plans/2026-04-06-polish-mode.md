# 润色/纠错模式 (Polish Mode)

## Context

Morpho 当前只支持「翻译」一种操作模式。对语言学习者来说，一个高频场景是：用目标语言写出带语法错误/错别字的句子，希望 AI 帮忙润色为地道、正确的表达。这个功能与翻译共享整条管线（热键 → 捕获文本 → LLM → 原地替换），唯一的差异在于 prompt 和语言路由逻辑。

用户选择的交互方式：**菜单栏模式切换** — 同一热键，根据当前模式执行翻译或润色。

## 实现方案

### Step 1: Domain — 新增 `WorkMode` 枚举 + 更新模型

**新建** `Sources/MorphoKit/Domain/Models/WorkMode.swift`:
```swift
public enum WorkMode: String, CaseIterable, Codable, Equatable, Sendable {
    case translate
    case polish
}
```

**修改** `AppSettings.swift`:
- 添加 `public var workMode: WorkMode` 属性
- `init` 和 `defaultValue` 中默认 `.translate`

**修改** `RunHistoryEntry.swift`:
- 添加 `public let workMode: WorkMode`（init 默认 `.translate`）
- 自定义 `Decodable` 使旧数据缺失该字段时回退为 `.translate`

### Step 2: Protocol — `TranslationEngine` 增加 `workMode` 参数

**修改** `TranslationContracts.swift`:
```swift
public protocol TranslationEngine {
    func translate(
        _ text: String, source: LanguageSource, target: Locale.Language,
        apiKey: String?, modelID: String?, workMode: WorkMode
    ) async throws -> String
}

// 向后兼容：不传 workMode 默认 .translate
extension TranslationEngine {
    public func translate(
        _ text: String, source: LanguageSource, target: Locale.Language,
        apiKey: String?, modelID: String?
    ) async throws -> String {
        try await translate(text, source: source, target: target,
                           apiKey: apiKey, modelID: modelID, workMode: .translate)
    }
}
```

同样更新 `CloudTranslationProviderClient` 协议，增加 `workMode` 参数。

### Step 3: Infrastructure — 引擎实现 + 持久化

**修改** `CloudTranslationEngine.swift`:
- 实现 6 参数 `translate` 方法
- Polish 模式时**跳过**同语言短路逻辑（line 24-27），因为润色就是同语言操作
- 将 `workMode` 透传给 `client`

**修改** `SiliconFlowTranslationProviderClient.swift`:
- `translate` 方法接收 `workMode`
- 当 `workMode == .polish` 时：
  - System prompt: `"You are a text proofreading engine. Return only the corrected text without explanations."`
  - User prompt: `buildPolishPrompt(text:source:)` — 指示修正语法、纠正错别字、保持原语言
- 当 `workMode == .translate` 时：现有行为不变

**修改** `UserDefaultsSettingsStore.swift`:
- `PersistedSettings` 增加 `workMode: String?` 字段
- `load()` 中缺失时默认 `"translate"`

### Step 4: Application — UseCase 分支逻辑

**修改** `HandleHotkeyTranslationUseCase.swift`:
- `execute()` 中读取 `settings.workMode`
- **Translate 模式**：现有逻辑不变
- **Polish 模式**：
  - 使用 `sourceLanguageDetector` 检测文本语言
  - 将检测到的语言作为 source 和 target（润色不换语言）
  - 调用 `engine.translate(..., workMode: .polish)`
- 状态消息根据模式区分：「翻译完成」vs「润色完成」
- `appendRunHistory` 传入 `workMode`

### Step 5: Presentation — 菜单栏模式切换 + 本地化

**修改** `MorphoAppModel.swift`:
- 添加 `var workMode: WorkMode { settings.workMode }`
- 添加 `func toggleWorkMode()` — 切换 translate/polish 并持久化

**修改** `MorphoMenuView.swift`:
- 在 hotkey summary 下方显示当前模式指示
- Action 按钮文案随模式变化：「翻译」/「润色」
- 添加模式切换按钮（或 Picker）

**修改** Localizable strings (en + zh-Hans):
- `menu.mode.translate` / `menu.mode.polish`
- `menu.action.polish_now`
- `status.polish_complete`

**修改** `MorphoMenuView.truncatedStatusMessage`:
- 增加对润色完成消息的处理

### Step 6: Tests

- **UseCase tests**: 添加 polish 模式下的 execute 测试
- **SiliconFlow tests**: 验证 polish 模式发送正确的 prompt
- **CloudTranslationEngine tests**: 验证 polish 模式不触发同语言短路
- **Settings 持久化 tests**: workMode 读写 round-trip + 旧数据兼容
- 更新所有受影响的 test stubs

## 关键文件

| 文件 | 变更 |
|------|------|
| `Sources/MorphoKit/Domain/Models/WorkMode.swift` | **新建** |
| `Sources/MorphoKit/Domain/Models/AppSettings.swift` | 添加 workMode |
| `Sources/MorphoKit/Domain/Models/RunHistoryEntry.swift` | 添加 workMode |
| `Sources/MorphoKit/Domain/Protocols/TranslationContracts.swift` | 协议扩展 |
| `Sources/MorphoKit/Infrastructure/Translation/CloudTranslationEngine.swift` | 跳过同语言短路 |
| `Sources/MorphoKit/Infrastructure/Translation/Cloud/SiliconFlowTranslationProviderClient.swift` | Polish prompt |
| `Sources/MorphoKit/Infrastructure/Translation/Cloud/CloudTranslationProviderClient.swift` | 协议更新 |
| `Sources/MorphoKit/Infrastructure/Settings/UserDefaultsSettingsStore.swift` | 持久化 workMode |
| `Sources/MorphoKit/Application/HandleHotkeyTranslationUseCase.swift` | 模式分支 |
| `Sources/MorphoApp/MorphoAppModel.swift` | 切换方法 |
| `Sources/MorphoApp/Views/MorphoMenuView.swift` | UI 模式切换 |

## 验证方式

1. `swift build` 编译通过
2. `swift test` 全部 98+ 测试通过（含新增测试）
3. 手动验证：菜单栏切换到润色模式 → 输入有语法错误的英文 → 热键触发 → 文本被原地替换为正确表达
4. 手动验证：切回翻译模式 → 行为与之前一致
5. 检查 Run History 记录了正确的 workMode
