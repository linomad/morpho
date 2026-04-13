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

#### 场景 1: 网页 textarea
| 项目 | 结果 |
|------|------|
| 触发选中 | ✅ |
| 翻译完成 | ✅ |
| 显示 Loading | - |
| 文本替换 | ✅ |

**备注**: AXEnhancedUserInterface 启用后走 AX 主路径或剪贴板粘贴兜底，工作正常（2026-03-28）

#### 场景 2: 地址栏（Omnibox）
| 项目 | 结果 |
|------|------|
| 触发选中 | - |
| 翻译完成 | ✅ |
| 显示 Loading | ❌ |
| 文本替换 | ❌ |

**可能原因**:
- Omnibox 使用自定义渲染引擎，⌘V 粘贴方案仍无法替换
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
| 文本替换 | ✅ |

**修复方案**: 已修复 — 兜底替换从 CGEvent.keyboardSetUnicodeString() 改回剪贴板粘贴（⌘V）+ TransientType 标记（2026-03-28）

---

### ME (JoyME)
- **Bundle ID**: `com.jd.TimLine`
- **App 类型**: Electron
- **测试日期**: 2026-04-14

#### 问题 1: 输入框触发后提示“当前输入控件不支持直接翻译”
| 项目 | 结果 |
|------|------|
| 触发选中 | ✅ |
| 翻译完成 | ✅（修复后） |
| 显示 Loading | - |
| 文本替换 | ✅（修复后） |
| 备注 | 修复前日志显示 `probe/empty`，但用户可见剪贴板稍后出现真实文本。 |

**可能原因**:
- 复制链路是异步分阶段写剪贴板：先变化为 probe/空，再延迟写入真实字符串
- 旧逻辑在首个 `changeCount` 变化后立即判失败，导致假阴性

**修复方案**: 已修复 — fallback copy 改为轮询窗口内持续读取有效文本，并将默认轮询窗口提升到 300ms（提交 `df2b9ed`，2026-04-14）

---

## 根因分析

### CGEvent.keyboardSetUnicodeString() 失效场景

| 场景 | 原因 | 解决方案 | 状态 |
|------|------|---------|------|
| Chrome 地址栏 | Omnibox 自定义渲染 | 需要特殊处理或降级 | 待修复 |
| ~~Electron 自绘组件~~ | ~~拦截底层键盘事件~~ | ~~降级到剪贴板方案~~ | ✅ 已修复 |
| ME 输入框（com.jd.TimLine） | 复制结果延迟写入，首个轮询读到 probe/空值 | 调整 fallback copy 判定为“窗口内持续轮询有效文本” | ✅ 已修复 |
| WebView 内嵌输入框 | DOM 层级拦截 | 需要 JS 注入或降级 | 待验证 |

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

| 优先级 | 问题 | 影响范围 | 状态 |
|--------|------|---------|------|
| ~~P0~~ | ~~Electron 文本替换失效~~ | ~~Electron 应用用户~~ | ✅ 已修复 (2026-03-28) |
| P1 | Chrome 地址栏失效 | Chrome 重度用户 | 待修复 |
| P2 | Caret Loading Overlay 在 Web/Electron 不显示 | Web/Electron 用户 | 待修复（fallback 到鼠标位置） |
| ~~P3~~ | ~~静默失败无反馈~~ | ~~调试困难~~ | ✅ 已修复 — 状态消息包含翻译结果 (2026-03-28) |

---

## 近期修复 (2026-03-28)

### Electron/Chromium 兼容性

**问题**：Electron 应用中翻译后文本无法正确替换。

**根因**：CGEvent.keyboardSetUnicodeString() 在 Electron 自绘组件中失效。

**解决方案**：回退到剪贴板粘贴方案（⌘V）+ TransientType 标记。

**涉及提交**：
- `4ccfd3a` — refactor: replace clipboard paste with CGEvent direct text injection
- `8c1af04` — fix: restore clipboard paste fallback for Electron/Chromium compatibility
- `c50c3e3` — refactor: rewrite MenuBarIconStateMachine with breathing dot phase
- `a1c6975` — feat: menu bar breathing dot indicator during translation
- `242a32f` — refactor: tune menu bar icon rendering and busy indicator behavior

**测试验证**：
| 应用 | 翻译触发 | 文本替换 | 状态 |
|------|---------|---------|------|
| Codex App | ✅ | ✅ | ✅ |
| Chrome textarea | ✅ | ✅ | ✅ |
| Chrome 地址栏 | ❌ | ❌ | 待处理 |
