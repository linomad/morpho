# System-Level Input Translation MVP

## Goal

在 macOS 上提供系统级输入翻译能力：用户在任意可编辑输入场景按全局快捷键后，可将当前输入内容翻译并写回。

## Product Scope (MVP)

- 菜单栏常驻应用，无主业务窗口
- 设置页：快捷键、源语言、目标语言、自动检测开关、云端 Provider、API Key
  - 快捷键使用单一录制框，聚焦后按组合键即时更新
  - API Key 输入后即时生效（无单独保存按钮）
  - 自动检测开启后：识别为源语言则翻译为目标语言；识别为目标语言则翻译为源语言
- 翻译行为：
  - 若存在选中文本，翻译并替换选中
  - 若无选中，翻译并替换全文
- 输入兼容策略：
  - 主通道：AX 直读直写
  - 兜底通道：受控复制/粘贴（仅针对已选中文本，不自动全选）
- 失败反馈：系统通知 + 菜单栏状态
- 兼容边界：优先支持标准 AX 可读写输入控件；AX 失败时支持“选中复制 + 粘贴写回”兜底

## Layered Architecture

- Domain
  - 核心模型：`TextContext`、`AppSettings`、`TranslationWorkflowError`
  - 协议：`TextContextProvider`、`TextReplacer`、`TranslationEngine`、`SettingsStore`
- Application
  - 用例：`HandleHotkeyTranslationUseCase`
  - 负责权限检查、文本决策、语言方向路由、翻译调用、结果写回、状态上报
- Infrastructure
  - 分层输入网关：`LayeredTextContextGateway`
  - AX 主通道：`AXTextContextGateway`
  - 受控粘贴兜底：`ControlledPasteTextGateway`
  - 基础注入：`KeyboardEventInjecting`、`PasteboardAccessing`
  - 全局热键：`GlobalHotkeyService`
  - 翻译引擎：`CloudTranslationEngine`
  - 语言检测：`NaturalLanguageSourceLanguageDetector`
  - Provider Client：`SiliconFlowTranslationProviderClient`
  - 云端重试：`RetryingCloudHTTPClient` + `CloudRetryPolicy`
  - 持久化：`UserDefaultsSettingsStore`（含 API Key）
  - 通知与状态：`UserNotificationStatusReporter`、`StatusCenter`
- Presentation
  - 菜单栏：`MorphoMenuView`
  - 设置页：`SettingsView`
  - 组合与依赖注入：`MorphoAppModel`

## Runtime Workflow

1. 全局快捷键触发
2. 校验辅助功能权限
3. 读取焦点输入上下文
4. 决定翻译文本（选中优先，否则全文）
5. 调用翻译引擎
6. 写回输入框
7. 发布状态（成功/失败）

## Technical Decisions

- 最低系统版本：macOS 15+
- 仅云端翻译，不再依赖本地/System 翻译
- 当前 Provider 为 SiliconFlow（OpenAI-Compatible）
- Provider 与 Credential 抽象独立，后续可扩展微软等接口
- 云端请求对 `429/5xx` 启用指数退避重试，并支持 `Retry-After`
- 不使用剪贴板回退或模拟输入，避免不可控副作用
- 仅在 AX 失败时启用受控粘贴兜底，且只处理“用户已选中”的文本
- 不做自动全选，避免篡改用户输入状态
- AX 解析支持向父节点回溯与多文本类型解码（String/AttributedString/URL）

## Known Limits

- 非标准输入控件（尤其自绘组件）可能不暴露可写 AX 属性
- 对“AX 不可读且无选中”的输入控件，提示“请先选中文本后重试”
- 安全输入框（密码类）不处理
- 需用户在设置页填写有效 API Key 才可触发翻译

## Compatibility Matrix (Phase 1)

目标应用：Safari、Chrome、Arc、VS Code、Slack。

每个应用至少覆盖以下三类场景：

1. 有选中翻译：按快捷键后完成翻译并替换选中内容。
2. 无选中行为：不给自动全选，明确提示“先选中文本后重试”。
3. 写回稳定性：翻译后能写回当前焦点输入位，且不污染剪贴板。
