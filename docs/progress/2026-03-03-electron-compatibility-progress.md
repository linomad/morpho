# Morpho Electron 输入兼容改造进度（2026-03-03 ~ 2026-03-04）

## Summary

本次改造目标是解决 Electron 场景下“没有找到可编辑的输入框”与“误读剪贴板旧值”问题，并保证核心能力：

- 有选中时翻译并替换选中内容
- 无选中时翻译并替换全文

最终方案保持分层架构不变，不修改 `UseCase` 与领域协议，仅增强 `Infrastructure/Accessibility`：

- `AX First` 作为主路径（零剪贴板污染优先）
- `AX` 失败时尝试一次 `AXManualAccessibility` 激活并重试
- 仍失败时走 `ControlledPaste`，并使用 deterministic copy handshake 避免陈旧剪贴板误判

## Implementation Scheme

### 1) 输入通道策略

- 主通道保持 `AXTextContextGateway`（AX 直读直写）
- 兜底通道保持 `ControlledPasteTextGateway`（受控复制/粘贴）
- 分层路由保持 `LayeredTextContextGateway`，主通道失败时进入兜底通道

### 2) Electron 兼容能力增强

- 新增 `KeyboardShortcut.selectAll`（`⌘A`），支持全文捕获与全文替换
- 兜底捕获改为双阶段：
  - 先 `⌘C` 尝试读取选中
  - 若无有效选中，再 `⌘A -> ⌘C` 读取全文
- 兜底替换改为模式化：
  - `selection`：直接 `⌘V`
  - `entireField`：`⌘A -> settle -> ⌘V`
- `focusedAppBundleId` 增加 fallback：AX 失败时回退 `frontmostApplication`

### 3) AX 写回稳定性增强

- `AXTextContextGateway.replace` 在焦点链不一致时，不直接失败
- 增加一次“基于当前焦点重新解析文本元素并重试写回”的路径

### 4) 剪贴板陈旧值误判修复（Codex 场景）

- 移除“与触发前剪贴板文本相等”的启发式判定
- 引入 deterministic copy handshake：
  - 每次复制前写入 probe token（`morpho-probe-UUID`）
  - 记录 baseline `changeCount`
  - 触发复制后轮询等待 `changeCount` 增加
  - 若复制结果为空或等于 probe token，判定为复制失败
- 通过该机制避免把旧剪贴板值误当作输入文本

### 5) 时序稳定性补强

- 新增 `selectAllSettleInterval`（默认 30ms）：`⌘A` 后等待选区稳定
- 新增 `pasteCommitInterval`（默认 40ms）：`⌘V` 后等待粘贴提交，再恢复剪贴板
- 新增可注入 `sleep` 闭包，便于单元测试验证时序路径

## Progress

### Completed

- [x] 新增 `KeyboardShortcut.selectAll`
- [x] 实现双阶段捕获与全文替换路径（`⌘A/⌘C/⌘V`）
- [x] `focusedAppBundleId` 增加 frontmost fallback
- [x] AX 写回增加焦点变化重解析重试
- [x] AX 读取路径增加 `AXManualAccessibility` 激活后重试
- [x] 兜底复制改为 deterministic probe handshake
- [x] 兜底替换增加 `selectAll/paste` 时序等待
- [x] 新增 Electron 回退行为测试（含 `focusedInputUnavailable` 回退）
- [x] 新增剪贴板陈旧值误判回归测试（probe 驱动）
- [x] 新增时序等待回归测试（`selectAllSettleInterval` / `pasteCommitInterval`）
- [x] 更新架构文档，保证文档与实现一致

### Verification

- `swift test --filter ControlledPasteTextGatewayTests`：通过
- `swift test`：通过（55 tests, 0 failures）

### Pending

- [ ] 手工验收 Electron 客户端（至少两款：Discord / Notion Desktop / Obsidian）
- [ ] 手工验收 Codex app 输入框端到端行为：
  - 输入 `i'm good` 时不应再误用剪贴板旧值
  - 无选中时应翻译全文并替换

## Optimization: Direct Text Injection via CGEvent

**Date:** 2026-03-28

### Problem

The clipboard-based paste fallback (`⌘V`) was unstable in some applications:
- Some apps don't respond to simulated keyboard shortcuts
- The 40ms `pasteCommitInterval` was insufficient for slower apps
- Restoring clipboard in `asyncAfter(deadline: .now() + 0.3)` could race with the paste operation

### Solution

Replace clipboard-based paste with direct CGEvent text injection:

```swift
// Before: Clipboard-based paste
pasteboard.writeString(translatedText)
try keyboard.trigger(.paste)
wait(pasteCommitInterval)

// After: Direct text injection
try keyboard.insertText(translatedText)
```

### Implementation

1. **New Protocol Method**: Added `insertText(_ text: String) throws` to `KeyboardEventInjecting`
2. **CGEvent Implementation**: Uses `CGEvent.keyboardSetUnicodeString()` to inject text directly
3. **Removed**: `pasteCommitInterval` parameter (no longer needed)
4. **Removed**: Clipboard snapshot/restore logic (no longer touches clipboard)

### Benefits

- **Zero clipboard pollution** — Never touches the user's clipboard
- **More compatible** — Works in apps that don't respond to `⌘V`
- **Faster** — No clipboard operations or artificial delays
- **Simpler** — Less code, fewer timing parameters

### Changed Files

- `Sources/MorphoKit/Infrastructure/Accessibility/KeyboardEventInjecting.swift`
- `Sources/MorphoKit/Infrastructure/Accessibility/ControlledPasteTextGateway.swift`
- `Tests/MorphoKitTests/Infrastructure/Accessibility/ControlledPasteTextGatewayTests.swift`

### Status

- [x] Implementation complete
- [x] Unit tests updated
- [ ] Manual testing in problematic apps needed

## Known Issues

详见 [app-compatibility-log.md](../compatibility/app-compatibility-log.md)

### 问题摘要 (2026-03-28)

| App | 问题 | 原因 |
|-----|------|------|
| Codex (Electron) | 文本替换失效 | CGEvent 被 Electron 层拦截 |
| Chrome 地址栏 | 文本替换失效 | Omnibox 不响应 CGEvent |

### Next Steps

- [ ] 实现 CGEvent 失效时的剪贴板降级方案
- [ ] 增强 `insertText()` 错误检测机制
- [ ] 继续测试更多 App 并更新兼容性文档

## Changed Files

- `Sources/MorphoKit/Infrastructure/Accessibility/KeyboardEventInjecting.swift`
- `Sources/MorphoKit/Infrastructure/Accessibility/ControlledPasteTextGateway.swift`
- `Sources/MorphoKit/Infrastructure/Accessibility/AXTextContextGateway.swift`
- `Tests/MorphoKitTests/Infrastructure/Accessibility/ControlledPasteTextGatewayTests.swift`
- `Tests/MorphoKitTests/Infrastructure/Accessibility/LayeredTextContextGatewayTests.swift`
- `docs/architecture/system-level-input-translation-mvp.md`

## Notes

- 当前工作区还有未跟踪目录 `.claude/`，本次改造未修改该目录内容。
