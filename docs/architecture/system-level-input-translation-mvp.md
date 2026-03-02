# System-Level Input Translation MVP

## Goal

在 macOS 上提供系统级输入翻译能力：用户在任意可编辑输入场景按全局快捷键后，可将当前输入内容翻译并写回。

## Product Scope (MVP)

- 菜单栏常驻应用，无主业务窗口
- 设置页：快捷键、源语言（支持自动检测）、目标语言、翻译后端（System/Cloud）
- 翻译行为：
  - 若存在选中文本，翻译并替换选中
  - 若无选中，翻译并替换全文
- 失败反馈：系统通知 + 菜单栏状态
- 兼容边界：仅支持标准 AX 可读写输入控件

## Layered Architecture

- Domain
  - 核心模型：`TextContext`、`AppSettings`、`TranslationWorkflowError`
  - 协议：`TextContextProvider`、`TextReplacer`、`TranslationEngine`、`SettingsStore`
- Application
  - 用例：`HandleHotkeyTranslationUseCase`
  - 负责权限检查、文本决策、翻译调用、结果写回、状态上报
- Infrastructure
  - AX 网关：`AXTextContextGateway`
  - 全局热键：`GlobalHotkeyService`
  - 翻译引擎：`SystemTranslationEngine` + `CloudTranslationEnginePlaceholder`
  - 持久化：`UserDefaultsSettingsStore`
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
- System 翻译优先，Cloud 为占位扩展
- 不使用剪贴板回退或模拟输入，避免不可控副作用
- AX 解析支持向父节点回溯与多文本类型解码（String/AttributedString/URL）

## Known Limits

- 非标准输入控件（尤其自绘组件）可能不暴露可写 AX 属性
- 安全输入框（密码类）不处理
- Cloud 后端尚未接入真实 API
