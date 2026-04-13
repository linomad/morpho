# ME 输入框兜底复制时序修复（2026-04-14）

## Summary

在 `ME.app`（Bundle ID: `com.jd.TimLine`）中，热键触发后会提示“当前输入控件不支持直接翻译”，但用户观察到剪贴板中实际出现了待翻译文本。  
本次修复确认这是 **兜底复制链路的时序误判**，并完成根因修复。

## Symptoms

- 主通道失败：`focusedInputUnavailable`
- 兜底通道失败：`fallback copy returned probe/empty content`
- 最终报错：`unsupportedInputControl`
- 但用户侧可观察到：稍后剪贴板里出现了真实文本

## Root Cause

`ControlledPasteTextGateway` 的旧逻辑在 `changeCount` 首次变化后立即判定复制结果。  
对于 `ME` 这类“先写 probe/空值，再延迟写入真实字符串”的应用，会产生假阴性：

1. 第一时间检测到剪贴板变化
2. 读到 `probe token` 或空值
3. 直接返回失败，不再继续轮询
4. 错过随后写入的真实文本

## Fix

提交：`df2b9ed` (`fix: stabilize fallback capture for delayed clipboard writes`)

- 将复制读取逻辑改为“在轮询窗口内持续读取，直到拿到非 probe 的有效文本或超时”
- 不再在首个 `changeCount` 变化时立即失败
- 默认复制轮询窗口从 `12 * 10ms` 提升到 `30 * 10ms`（120ms -> 300ms）
- 新增回归测试：模拟“先回写 probe，再延迟回写真实文本”的时序

## Verification

- `swift test --filter testCaptureKeepsPollingWhenCopyInitiallyEchoesProbeTokenThenProvidesText` 通过
- `swift test` 全量通过（`126 tests, 0 failures`）
- 手工回归：`ME` 输入框场景已恢复正常

## Impact

这不是单一 App 的定制补丁，而是对 fallback 复制握手策略的通用增强。  
对所有存在异步剪贴板写入时序的应用都能提升稳定性。

