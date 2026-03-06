# Morpho

macOS 系统级输入翻译工具（MVP）。

English: [README.md](README.md)

## Slogan

**Native-First, Seamless Input Translation**

## 初衷

Morpho 的出发点很具体：在聊天、写文章以及其他高频输入场景中，用户需要把“正在输入的内容”及时、迅速地翻译成目标语言，而且不应中断当前输入流程。

翻译应当发生在输入现场，而不是把人从当前应用和思路里拉走。

## 设计理念

- 深挖一个核心问题：帮助用户在输入过程中即时完成翻译，不打断写作与表达节奏。
- 保持产品小而专注：Morpho 不追求大而全，所有功能都应服务这一核心输入翻译场景，避免功能膨胀。
- 极度重视交互体验：每一次操作都应快速、可预期、低负担，并提供清晰反馈。

## 核心功能定义（MVP）

- 菜单栏常驻应用，提供独立设置页。
- 全局快捷键触发翻译。
- 翻译规则：有选中翻译选中；无选中翻译全文。
- 自动检测双向路由：识别为源语言时翻译为目标语言；识别为目标语言时翻译为源语言。
- 云端翻译（SiliconFlow），API Key 本地持久化并即时生效。
- 失败反馈统一进入菜单栏状态与系统通知。
- 输入通道分层：AX 主通道，受控粘贴作为最终兜底。

## 范围与边界

- 优先覆盖主流 App 输入场景。
- 不处理密码/安全输入框。
- 非标准自绘控件可能无法直接读写。
- 剪贴板路径仅在 AX 路径失败时使用。

## 架构分层

- `Sources/MorphoKit/Domain`: 领域模型与协议
- `Sources/MorphoKit/Application`: 用例编排与路由策略
- `Sources/MorphoKit/Infrastructure`: AX、受控粘贴、云端翻译、热键、通知、持久化
- `Sources/MorphoApp`: 菜单栏 UI 与设置页

## 参与开发

```bash
swift test
swift run MorphoApp
```
