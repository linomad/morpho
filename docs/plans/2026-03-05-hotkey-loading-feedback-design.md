# Hotkey Loading Feedback Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在全局快捷键触发翻译时，为用户提供稳定可见的“翻译进行中”反馈，并在完成后自动恢复。

**Architecture:** 不再尝试修改全局系统鼠标样式（该路径在当前 macOS 能力边界下不可靠），改为“应用内可控反馈”：菜单栏图标 running 态 + 非激活悬浮 Loading HUD。HUD 由应用内独立控制器管理，`MorphoAppModel` 仅发出开始/结束信号，保持分层清晰、可测试。

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, MenuBarExtra, XCTest

---

## 1. 背景与根因

### 1.1 已确认事实
- 快捷键事件能进入当前进程（有 debug 日志证据）。
- 调试分支可拦截翻译执行（说明链路可控）。
- 即便调用 `NSCursor.push/set`，在“前台应用不是 Morpho”时，用户仍看不到光标变化。

### 1.2 根因结论
- `NSCursor` 是应用级语义，不保证改变当前屏幕显示光标（尤其前台为其他应用时）。
- 可修改全局主题光标的历史 Carbon API 在现代 macOS 路径不可用（32-bit only），不能作为可维护方案。

### 1.3 设计决策
- 放弃“强改系统全局光标”的目标。
- 采用稳定替代：`菜单栏 running 图标 + 悬浮 Loading HUD`。

---

## 2. 目标体验（验收标准）

### 2.1 用户可见行为
- 通过快捷键触发翻译后，150ms 内出现 Loading HUD。
- HUD 默认显示在鼠标附近（偏移 12~16 px，避免遮挡点位）。
- 翻译完成（成功/失败）后，HUD 立即消失。
- 并发触发只显示一个 HUD（引用计数或 in-flight guard）。

### 2.2 异常场景
- 无法显示 HUD 时，不阻断翻译流程，仅记录状态日志。
- 任务取消/失败也必须保证 HUD 收敛（不残留）。

---

## 3. 分层设计

### 3.1 新增抽象
- `TranslationActivityIndicating`（应用层协议）
  - `func begin()`
  - `func end()`
- `HUDWindowControlling`（基础设施协议）
  - `func show(at screenPoint: NSPoint)`
  - `func hide()`

### 3.2 组件职责
- `MorphoAppModel`
  - 只在翻译生命周期调用 `begin/end`。
  - 不直接操作 AppKit 视图对象。
- `TranslationActivityIndicatorController`
  - 处理幂等、并发保护、开始/结束配对。
- `FloatingLoadingHUDController`（AppKit 实现）
  - 管理 `NSPanel` 生命周期、位置计算、显示隐藏。

### 3.3 依赖方向
- `MorphoAppModel -> TranslationActivityIndicating`
- `TranslationActivityIndicatorController -> HUDWindowControlling`
- 不反向依赖 `MorphoAppModel`，避免耦合 UI 与业务。

---

## 4. 详细实施任务（TDD）

### Task 1: 活动指示控制器（纯逻辑）

**Files:**
- Create: `Sources/MorphoApp/Support/TranslationActivityIndicatorController.swift`
- Create: `Tests/MorphoAppTests/Support/TranslationActivityIndicatorControllerTests.swift`
- Modify: `Package.swift`（如需恢复 `MorphoAppTests` 目标）

**Step 1: 写失败测试**
- `begin()` 只首次触发 `show`
- `end()` 在配对后触发 `hide`
- 未 `begin` 直接 `end` 不触发 `hide`

**Step 2: 跑测试确认失败**
- Run: `swift test --filter TranslationActivityIndicatorControllerTests`

**Step 3: 最小实现转绿**
- `isActive` 或计数 guard。

**Step 4: 再跑测试**
- Run: `swift test --filter TranslationActivityIndicatorControllerTests`

---

### Task 2: AppKit 悬浮 HUD 基础设施

**Files:**
- Create: `Sources/MorphoApp/Support/FloatingLoadingHUDController.swift`
- Create: `Sources/MorphoApp/Views/LoadingHUDView.swift`
- Create: `Tests/MorphoAppTests/Support/HUDPositioningTests.swift`

**Step 1: 写失败测试（定位算法）**
- 输入鼠标点 + 屏幕边界，输出 HUD frame 在可视区域内。

**Step 2: 跑测试确认失败**
- Run: `swift test --filter HUDPositioningTests`

**Step 3: 实现最小 HUD**
- 非激活 `NSPanel`（`nonactivatingPanel` + `level = .statusBar`）
- `ignoresMouseEvents = true`
- 内容用 SwiftUI `ProgressView` + 简短文案（如“Translating…”）

**Step 4: 复跑测试**
- Run: `swift test --filter HUDPositioningTests`

---

### Task 3: 接入翻译生命周期

**Files:**
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`

**Step 1: 写集成级单测（可选，建议）**
- 验证 `triggerTranslation()` 开始调用 `begin()`，结束调用 `end()`。

**Step 2: 实现注入与调用**
- 构造函数初始化 `TranslationActivityIndicatorController`。
- 在翻译开始/结束生命周期配对调用。

**Step 3: 运行全量测试**
- Run: `swift test`

---

### Task 4: 手工验收与回归

**手工验收脚本：**
1. `swift run MorphoApp`
2. 聚焦任意可编辑文本应用（TextEdit / 输入框）
3. 按快捷键触发翻译
4. 观察 HUD 出现与消失（成功/失败场景都验证）
5. 连续快速触发，确认没有多个 HUD 叠加与残留

**回归关注点：**
- 快捷键注册/禁用不受影响
- 历史记录与状态提示不回归
- 菜单“立即翻译”行为一致

---

## 5. 非目标（明确不做）

- 不再实现“修改全局系统鼠标为 busy”方案。
- 不引入常驻复杂窗口管理器或多实例 HUD。
- 不改动翻译引擎与文本替换流程。

---

## 6. 风险与缓解

- 风险：部分全屏/多显示器场景 HUD 位置异常。
  - 缓解：先把“位置计算”提纯为可测试函数，覆盖边界。
- 风险：异常路径导致 HUD 不收敛。
  - 缓解：统一在完成回调与 `defer` 里执行 `end()`。

---

## 7. 交付定义（DoD）

- 单元测试通过：`swift test`
- 手工验收通过：快捷键触发时用户可稳定看到 loading 反馈
- 代码分层满足：Model 不直接持有具体 HUD 视图/窗口实现
- 文档与行为一致，无调试分支残留
