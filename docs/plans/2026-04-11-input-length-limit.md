# Input Text Length Limit v2（架构优先 + 全链路本地化）

## 目标
在触发翻译/润色时引入输入长度限制；当输入超限时不执行翻译，并且：
- 状态提示走完整本地化链路（不是 MorphoKit 内硬编码中文）
- 历史记录保留语义（明确是「被策略阻断」而非成功记录）
- 保持分层清晰：MorphoKit 只产出语义，不做 UI 文案本地化

## 非目标
- 本版本不开放设置页配置阈值（先固定阈值）
- 不引入多条复杂策略引擎（仅输入长度一条规则）

---

## 现状问题（必须先修正）

1. `TranslationErrorPresenter` 在 MorphoKit 中硬编码中文，不是可本地化链路。  
2. `HandleHotkeyTranslationUseCase` 成功状态文案也硬编码中文。  
3. `MorphoAppModel` 通过“字符串前缀”判断是否翻译完成，属于脆弱逻辑。  
4. `RunHistoryEntry` 仅表达“成功翻译记录”，无法语义化表达“被策略阻断”。  

---

## 核心设计决策

### 1) 输入限制放在 UseCase，但由独立策略对象表达
在 `HandleHotkeyTranslationUseCase.execute()` 中，拿到 `payload` 后立即校验；  
校验规则由独立值对象 `InputTextLengthPolicy` 承担，避免魔法值散落。

```swift
public struct InputTextLengthPolicy: Sendable {
    public let maxCharacters: Int

    public init(maxCharacters: Int = 5_000) {
        self.maxCharacters = max(1, maxCharacters)
    }

    public func validate(_ text: String) -> InputLengthValidationResult {
        let count = text.count
        return count <= maxCharacters
            ? .withinLimit
            : .tooLong(actual: count, limit: maxCharacters)
    }
}
```

### 2) 本地化链路改为「语义键 + 参数」，文案解析下沉到 App 层
MorphoKit 只发布可本地化描述符，不直接输出最终人类语言文案。

```swift
public enum StatusCode: String, Sendable {
    case ready
    case translationCompleted
    case polishCompleted
    case workflowBlocked
    case workflowFailed
    case hotkeyInitFailed
    case hotkeyRegisterFailed
    case launchAtLoginUnsupportedSystem
}

public struct StatusEntry: Equatable, Sendable {
    public let code: StatusCode
    public let messageKey: String
    public let messageArguments: [String]
    public let severity: StatusSeverity
    public let createdAt: Date
}
```

App 层新增 `StatusMessageLocalizer`（基于 `AppLocalization`）进行最终文案解析。  
`MorphoMenuView` 与通知模块都消费解析后的文本。

### 3) 历史记录显式建模结果类型，不再用占位符字段
避免 `"- -> -"`、`outputText` 塞错误原因这种语义污染。

```swift
public enum RunHistoryResult: String, Codable, Sendable {
    case success
    case blocked
}

public enum RunHistoryBlockReason: String, Codable, Sendable {
    case inputTextTooLong
}
```

`RunHistoryEntry` 新增：
- `result: RunHistoryResult`（默认 `.success`，保证历史数据兼容）
- `blockReason: RunHistoryBlockReason?`
- `inputPreview: String`（仅用于展示，防止异常大文本进入历史文件）

---

## 领域模型变更

### TranslationWorkflowError
新增带上下文的错误，避免信息丢失：

```swift
case inputTextTooLong(actualCount: Int, maxCount: Int)
```

### TranslationError 描述符（替代硬编码 Presenter）
将 `TranslationErrorPresenter` 从“返回中文文案”改为“返回 messageKey + 参数”。

```swift
struct TranslationErrorDescriptor: Sendable {
    let key: String
    let args: [String]
}
```

---

## 执行流程（UseCase）

1. 捕获上下文并得到 `payload`。  
2. 用 `InputTextLengthPolicy` 校验 `payload.text`。  
3. 若超限：
   - 追加 `RunHistoryResult.blocked` 记录，`blockReason = .inputTextTooLong`
   - 发布 `StatusEntry(code: .workflowBlocked, messageKey: "error.input_text_too_long", messageArguments: [...])`
   - 返回 `.failure(.inputTextTooLong(...))`
4. 未超限则按现有流程翻译、写回、记录 success 历史。  
5. 成功状态改为 `status.translation_complete_with_preview` / `status.polish_complete_with_preview`，不再拼接硬编码中文。

---

## UI/展示层调整

### MorphoAppModel
- 自动重置状态从“字符串前缀判断”改为 `StatusCode` 判断：
  - `.translationCompleted` / `.polishCompleted` 才触发延时 reset

### MorphoMenuView
- 展示本地化后的 status 文案，不再依赖 `isTranslationCompleteStatus(message:)` 文本匹配逻辑

### HistorySettingsPane
- success：保持输入/输出展示
- blocked：展示输入 + 本地化阻断原因（`settings.history.reason.input_text_too_long`）
- 语言方向仅 success 展示，blocked 展示结果标签（例如 `Blocked`/`已阻断`）

---

## 本地化键（全链路）

### 新增/迁移原则
- MorphoKit 不再内嵌中文文案
- 将现有错误文案全量迁移为 `Localizable.strings` 键
- 本次新增输入超限相关键，且补齐完成状态带预览键

### 关键新增键（zh-Hans）

```text
error.input_text_too_long = "输入文本过长（%@/%@），不支持翻译";
status.translation_complete_with_preview = "翻译完成：%@";
status.polish_complete_with_preview = "润色完成：%@";
settings.history.result.blocked = "已阻断";
settings.history.reason.label = "原因";
settings.history.reason.input_text_too_long = "输入超出长度上限";
```

### 关键新增键（en）

```text
error.input_text_too_long = "Input text is too long (%@/%@).";
status.translation_complete_with_preview = "Translation complete: %@";
status.polish_complete_with_preview = "Polish complete: %@";
settings.history.result.blocked = "Blocked";
settings.history.reason.label = "Reason";
settings.history.reason.input_text_too_long = "Input exceeds length limit";
```

> 注：现有错误键（accessibility/noText/cloud* 等）也应一并入表，完成硬编码迁移。

---

## 兼容性与迁移

1. `RunHistoryEntry` 解码使用 `decodeIfPresent` + 默认值，兼容旧 JSON。  
2. 旧历史记录无 `result/blockReason/inputPreview` 时按 success 解释。  
3. 状态模型变更后，同步更新测试桩（`StatusSinkSpy`、断言字段）。  

---

## 变更文件清单（计划）

### MorphoKit
- `Sources/MorphoKit/Application/HandleHotkeyTranslationUseCase.swift`
- `Sources/MorphoKit/Domain/Errors/TranslationWorkflowError.swift`
- `Sources/MorphoKit/Domain/Models/StatusEntry.swift`
- `Sources/MorphoKit/Domain/Models/RunHistoryEntry.swift`
- `Sources/MorphoKit/Application/TranslationErrorPresenter.swift`（重构为 descriptor mapper）
- `Tests/MorphoKitTests/Application/HandleHotkeyTranslationUseCaseTests.swift`
- `Tests/MorphoKitTests/Application/TranslationErrorPresenterAdditionalTests.swift`
- `Tests/MorphoKitTests/Infrastructure/TranslationErrorPresenterTests.swift`

### MorphoApp
- `Sources/MorphoApp/MorphoAppModel.swift`
- `Sources/MorphoApp/Views/MorphoMenuView.swift`
- `Sources/MorphoApp/Views/Settings/Panes/HistorySettingsPane.swift`
- `Sources/MorphoApp/Support/StatusMessageLocalizer.swift`（新增）
- `Sources/MorphoApp/Resources/zh-Hans.lproj/Localizable.strings`
- `Sources/MorphoApp/Resources/en.lproj/Localizable.strings`

---

## 测试计划（必须覆盖）

1. `count == 5000`：成功进入翻译流程。  
2. `count == 5001`：返回 `inputTextTooLong`，不调用 engine、不调用 replacer。  
3. 超限场景发布 `StatusCode.workflowBlocked` 且 `severity == .warning`。  
4. 超限场景追加 blocked 历史，`blockReason == .inputTextTooLong`。  
5. success 场景仍为 success 历史且语言方向字段正确。  
6. `RunHistoryEntry` 新旧 JSON 兼容解码测试。  
7. 菜单栏状态重置逻辑从 message 文本匹配切到 `StatusCode` 后行为不回归。  
8. 中英文下错误/完成/历史原因文案正确渲染。  

---

## 实施步骤

1. 重构 `StatusEntry` 为 `StatusCode + messageKey + args` 结构。  
2. 重构 `TranslationErrorPresenter` 为 key/args 描述符映射。  
3. 实现 `InputTextLengthPolicy` 并接入 UseCase。  
4. 扩展 `TranslationWorkflowError` 与超限失败路径。  
5. 扩展 `RunHistoryEntry` 语义字段并实现 blocked 记录。  
6. App 层新增 `StatusMessageLocalizer`，接管状态文本展示。  
7. 更新 `MorphoAppModel` / `MorphoMenuView` / `HistorySettingsPane`。  
8. 增补 `Localizable.strings`（含现有错误文案迁移）。  
9. 补齐并通过全部测试。  

---

## 结果判定标准（Done Definition）

- MorphoKit 不再输出硬编码中文错误/完成文案。  
- 输入超限时翻译不会发起，状态与历史都可本地化、可追踪。  
- 历史语义明确区分 success 与 blocked。  
- 菜单栏状态逻辑不依赖字符串前缀。  
- 兼容旧历史数据并通过测试。  
