# Auto Bidirectional Language Pair (zh <-> en)

## 背景

用户希望在“源语言自动检测”开启时，支持配置一组语言对，并根据识别结果自动决定翻译方向：
- 识别为中文 -> 翻译为英文
- 识别为英文 -> 翻译为中文

## 设计决策（已执行）

1. 语言方向路由放在 Application 层（`HandleHotkeyTranslationUseCase`）
- 推荐原因：避免把业务策略耦合进 Provider 协议层，保持分层清晰。
- 结果：UseCase 在调用引擎前先计算 `(effectiveSource, effectiveTarget)`。

2. 语言检测能力通过协议注入
- 新增协议：`SourceLanguageDetecting`
- 默认实现：`NaturalLanguageSourceLanguageDetector`（基于 `NaturalLanguage`）
- 推荐原因：可测试、可替换，不把平台 API 直接写死在用例里。

3. 配置模型使用“可选语言对”
- 在 `AppSettings` 新增 `autoSwitchLanguagePair: AutoSwitchLanguagePair?`
- 仅当 `sourceLanguage == .auto` 且该字段不为空时，启用双向互译路由。

4. UI 交互
- 自动检测开启时，新增“自动检测后在语言对内互译”开关。
- 开启后展示“语言 A / 语言 B”两个选择器。
- 规则：识别为 A -> 翻译到 B；识别为 B -> 翻译到 A。

## 路由规则

在翻译请求发起前执行：
1. 如果不是自动检测模式：沿用现有 `source + target`。
2. 如果是自动检测但未开启语言对：沿用现有 `target`。
3. 如果开启语言对：
   - 识别命中第一语言：`source = first`, `target = second`
   - 识别命中第二语言：`source = second`, `target = first`
   - 未命中语言对：回退到原有 `source/target` 配置

## 验证

- 新增用例测试：`HandleHotkeyTranslationUseCaseTests`
  - 自动识别中文时目标切换为英文
  - 自动识别英文时目标切换为中文
- 新增持久化测试：`UserDefaultsSettingsStoreTests`
  - 语言对配置保存与恢复
- 全量回归：`swift test` 通过
