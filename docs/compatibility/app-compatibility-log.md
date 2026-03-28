# App 兼容性测试记录

本文档记录 Morpho 在各 App 中的兼容性测试结果，便于追踪问题和迭代优化。

## 记录格式

```markdown
### App 名称
- **Bundle ID**: xxx
- **App 类型**: 原生 / Electron / WebView / 其他
- **测试日期**: YYYY-MM-DD

#### 问题 1: 场景描述
| 项目 | 结果 |
|------|------|
| 触发选中 | ✅ / ❌ / - |
| 翻译完成 | ✅ / ❌ |
| 显示 Loading | ✅ / ❌ / - |
| 文本替换 | ✅ / ❌ |
| 备注 | 现象描述 |

**可能原因**: xxx
**修复方案**: xxx（待实现 / 已实现）
```

---

## 测试记录

### Chrome
- **Bundle ID**: `com.google.Chrome`
- **App 类型**: 原生 (Chromium)
- **测试日期**: 2026-03-28

#### 问题 1: 地址栏（Omnibox）
| 项目 | 结果 |
|------|------|
| 触发选中 | - |
| 翻译完成 | ✅ |
| 显示 Loading | ❌ |
| 文本替换 | ❌ |

**可能原因**: 
- Omnibox 使用自定义渲染引擎，不响应 CGEvent 键盘事件
- 地址栏不是标准文本输入控件

**修复方案**: 待分析（可能需要特殊处理或提示用户）

---

### Codex App
- **Bundle ID**: 待补充
- **App 类型**: Electron
- **测试日期**: 2026-03-28

#### 问题 1: 输入框文本替换
| 项目 | 结果 |
|------|------|
| 触发选中 | ✅ |
| 翻译完成 | ✅ |
| 显示 Loading | ❌ |
| 文本替换 | ❌ |

**可能原因**: 
- Electron 自绘组件不响应 CGEvent.keyboardSetUnicodeString()
- CGEvent 发送的键盘事件被 Electron 层拦截

**修复方案**: 
1. 降级回剪贴板粘贴方案（需修复时序问题）
2. 或尝试 AXTextMarker API

---

## 根因分析

### CGEvent.keyboardSetUnicodeString() 失效场景

| 场景 | 原因 | 解决方案 |
|------|------|---------|
| Chrome 地址栏 | Omnibox 自定义渲染 | 需要特殊处理或降级 |
| Electron 自绘组件 | 拦截底层键盘事件 | 降级到剪贴板方案 |
| WebView 内嵌输入框 | DOM 层级拦截 | 需要 JS 注入或降级 |

### 静默失败问题

当前 `insertText()` 方法在 CGEvent 发送后不返回任何状态，导致：
- 文本注入失败时无反馈
- 也没有抛出异常
- UseCase 层误认为替换成功

**建议**: 增强错误检测机制

---

## 待测试 App 列表

- [ ] Safari
- [ ] VS Code
- [ ] Slack
- [ ] Discord
- [ ] Notion Desktop
- [ ] Obsidian
- [ ] 飞书
- [ ] 钉钉
- [ ] 微信
- [ ] Xcode
- [ ] Terminal
- [ ] iTerm2
- [ ] Pages
- [ ] Word
- [ ] WPS

---

## 修复优先级

| 优先级 | 问题 | 影响范围 |
|--------|------|---------|
| P0 | Electron 文本替换失效 | Electron 应用用户 |
| P1 | Chrome 地址栏失效 | Chrome 重度用户 |
| P2 | 静默失败无反馈 | 调试困难 |
