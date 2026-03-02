# Morpho

系统级输入翻译 macOS 工具（MVP）。

## 当前能力

- 菜单栏常驻 + 设置页
- 全局快捷键触发翻译
- Accessibility 读取并写回当前聚焦输入框
- 规则：有选中翻译选中，否则翻译全文
- 系统翻译引擎（`Translation.framework`）
- Cloud 引擎接口已预留（占位，未接入）
- 失败状态会写入菜单栏状态并触发系统通知

## 运行

```bash
swift test
swift run MorphoApp
```

首次使用需在系统设置中授予辅助功能权限（Accessibility）。

## 架构

- `Sources/MorphoKit/Domain`: 领域模型与协议
- `Sources/MorphoKit/Application`: 用例编排
- `Sources/MorphoKit/Infrastructure`: AX、翻译、热键、通知、持久化
- `Sources/MorphoApp`: 菜单栏与设置页
