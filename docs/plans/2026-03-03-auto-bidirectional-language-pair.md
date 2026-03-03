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

4. UI 交互（优化后）
- 设置页固定展示“源语言 + 目标语言”两个配置项。
- 仅保留一个“开启自动检测”开关，不再引入额外的语言对开关。
- 规则：识别为源语言 -> 翻译到目标语言；识别为目标语言 -> 翻译到源语言。

## 路由规则

在翻译请求发起前执行：
1. 如果不是自动检测模式：沿用现有 `source + target`。
2. 如果是自动检测且存在语言对：
   - 识别命中第一语言：`source = first`, `target = second`
   - 识别命中第二语言：`source = second`, `target = first`
3. 未命中语言对：回退到原有 `source/target` 配置

## 验证

- 新增用例测试：`HandleHotkeyTranslationUseCaseTests`
  - 自动识别中文时目标切换为英文
  - 自动识别英文时目标切换为中文
- 新增持久化测试：`UserDefaultsSettingsStoreTests`
  - 语言对配置保存与恢复
- 全量回归：`swift test` 通过
