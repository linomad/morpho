# Hotkey Recorder + Cloud Retry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重构设置页快捷键交互为“聚焦后按键即设置”，移除 API Key 保存按钮并改为即时生效，同时落地云端调用重试与退避策略（429/5xx）提升翻译稳定性。

**Architecture:** UI 层只负责事件采集与展示；快捷键语义保持在 `HotkeyShortcut` 领域模型中。云端重试通过 `CloudHTTPClient` 装饰器实现，不侵入 UseCase 与 Provider 协议层。这样既保持分层清晰，也保证后续新增 Provider 时自动复用重试能力。

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation, XCTest

---

## 设计与决策记录

### 决策 1：快捷键设置交互
- 方案 A（采用）：使用单一“快捷键录制框”，聚焦后监听 `keyDown`，实时写入 `HotkeyShortcut`。
- 方案 B：保留按键下拉 + 修饰键开关。
- 不选 B 的原因：操作路径长，不符合桌面端快捷键设置习惯。

### 决策 2：API Key 持久化时机
- 方案 A（采用）：输入变化即持久化（本地应用设置即时生效）。
- 方案 B：保留显式保存按钮。
- 不选 B 的原因：增加不必要状态与流程，易产生“已输入未生效”的认知偏差。

### 决策 3：云端重试放置层级
- 方案 A（采用）：新增 `RetryingCloudHTTPClient` 装饰基础 HTTP 客户端。
- 方案 B：将重试逻辑写在 `SiliconFlowTranslationProviderClient`。
- 方案 C：将重试逻辑写在 `CloudTranslationEngine`。
- 不选 B/C 的原因：B 会导致 Provider 间逻辑重复；C 会混入协议细节（HTTP 状态码），破坏层次边界。

### 决策 4：退避策略
- 采用指数退避：`baseDelay * 2^(attempt-1)`，支持 `maxDelay` 上限。
- 对 429/503 优先解析 `Retry-After` 头（秒），可用时覆盖指数延迟。
- 默认最大尝试次数：3（含首发请求）。

## 任务拆解（TDD）

### Task 1: 云端重试策略（复杂功能）

**Files:**
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/CloudRetryPolicy.swift`
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/RetryingCloudHTTPClient.swift`
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`
- Test: `Tests/MorphoKitTests/Infrastructure/Translation/RetryingCloudHTTPClientTests.swift`

**Step 1: 写失败测试**
- 429/5xx 时重试并最终成功。
- 达到最大次数后停止重试。
- 有 `Retry-After` 时使用服务端延迟。

**Step 2: 运行测试确认失败**
Run: `swift test --filter RetryingCloudHTTPClientTests`
Expected: FAIL（类型/实现不存在）

**Step 3: 最小实现**
- 实现 retry policy 与 decorator。
- 在 `MorphoAppModel` 注入 `RetryingCloudHTTPClient`。

**Step 4: 运行测试确认通过**
Run: `swift test --filter RetryingCloudHTTPClientTests`
Expected: PASS

### Task 2: 快捷键录制框交互重构

**Files:**
- Create: `Sources/MorphoApp/Support/HotkeyRecorderShortcutBuilder.swift`
- Create: `Sources/MorphoApp/Views/HotkeyRecorderField.swift`
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`
- Modify: `Sources/MorphoApp/Views/SettingsView.swift`
- Modify: `Sources/MorphoApp/Views/MorphoMenuView.swift`
- Modify: `Sources/MorphoApp/Support/HotkeyKeyOptions.swift`

**Step 1: 写失败测试（纯逻辑）**
- 修饰键与按键标签格式化符合预期。
- 非法按键（纯修饰键）不生成快捷键。

**Step 2: 运行测试确认失败**
Run: `swift test --filter HotkeyShortcutDisplayTests`
Expected: FAIL

**Step 3: 最小实现**
- `SettingsView` 去除四个 Toggle + 按键 Picker。
- 改为录制框，聚焦后捕获组合键并立即 `model.updateHotkeyShortcut(...)`。
- 菜单栏快捷键文案复用统一格式化逻辑。

**Step 4: 运行相关测试**
Run: `swift test --filter Hotkey`
Expected: PASS

### Task 3: API Key 即时生效

**Files:**
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`
- Modify: `Sources/MorphoApp/Views/SettingsView.swift`

**Step 1: 写失败测试（若涉及可测逻辑则覆盖）**
- 文本变化应即时落盘，关闭窗口不依赖额外保存动作。

**Step 2: 最小实现**
- 移除“保存 API Key”按钮。
- `TextField` 变更时同步模型并持久化。

**Step 3: 运行全量测试**
Run: `swift test`
Expected: PASS

### Task 4: 文档同步

**Files:**
- Modify: `docs/architecture/system-level-input-translation-mvp.md`
- Modify: `docs/todo.md`

**Step 1:** 在架构文档记录重试装饰器与配置。

**Step 2:** 在 backlog 中标注“429/5xx 重试与退避策略”已完成，并补充下一个建议优先事项。

## 验证清单
- 设置页快捷键为单框录制交互。
- API Key 无保存按钮，输入后即时生效。
- 429/5xx 重试生效且可测试验证。
- `swift test` 全绿。
