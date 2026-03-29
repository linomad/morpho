# Caret Loading Overlay — Web/Electron Fallback 修复计划

**分支**: `fix/caret-loading-overlay-fallback`
**Worktree**: `.worktrees/caret-fallback`
**状态**: 待实施（计划中）

---

## 问题描述

### 现象

| 应用 | 原生 App | Chrome | 微信 | Electron App |
|------|---------|--------|------|--------------|
| Loading 显示 | ✅ | ❌ | ❌ | ❌ |

### 根因

`CaretLoadingOverlay.show()` 调用 `CaretRectLocator.queryCaretRect()` 获取光标位置。

在 Web/Electron 环境中：
1. `kAXSelectedTextRangeAttribute` 可获取（文本替换正常）
2. `kAXBoundsForRangeParameterizedAttribute` **可能返回异常值**
3. `validateAXRect()` 的尺寸校验（8-120px）会过滤掉无效 rect
4. 最终返回 `nil`，overlay **静默不显示**

---

## 技术分析

### CaretRectLocator 查询流程

```
queryCaretRect()
  ├─ queryViaStandardAX()        // 优先尝试
  │    └─ boundsForRange() → validateAXRect()
  │
  └─ queryViaTextMarker()        // 回退方案
       └─ boundsForTextMarkerRange() → validateAXRect()
```

### Web/Electron 的 AX 限制

| 控件类型 | AX 完善度 | bounds 准确性 |
|----------|-----------|---------------|
| 原生 macOS 控件 | ✅ 完善 | ✅ 准确 |
| Chrome textarea | ⚠️ 部分 | ⚠️ 可能异常 |
| Electron WebView | ❌ 有限 | ❌ 常失败 |
| 微信内嵌 WebView | ❌ 有限 | ❌ 常失败 |

---

## SwiftUI-Pro 代码审查发现

### 1. 静默失败问题（高优先级）

**当前问题**：当 `queryCaretRect()` 返回 `nil` 时，`show()` 方法直接返回，用户不知道发生了什么。

**影响**：
- 用户体验差：触发翻译后没有任何反馈
- 调试困难：无法确认是否调用了 overlay

**建议**：
- 添加 debug 日志输出
- 考虑在 fallback 模式下也显示 overlay（使用鼠标位置）

### 2. 线程安全问题（中等优先级）

**当前问题**：`@MainActor` 类中的 `nonisolated static` 方法访问 `NSEvent.mouseLocation`。

**分析**：
- `NSEvent.mouseLocation` 可以在任何线程调用
- 但在 `nonisolated` 方法中访问可能导致数据竞争
- 当前 `@MainActor` 隔离提供了保护，实际风险较低

**建议**：保持现状即可，这是合理的用法。

### 3. 缺少单元测试（高优先级）

**当前问题**：没有针对 fallback 逻辑的单元测试。

**建议**：添加以下测试：
- `mouseLocationAsRect()` 返回值的尺寸验证
- `show()` 在 fallback 模式下的行为测试

### 4. 代码可测试性（中等优先级）

**当前问题**：`show()` 方法直接调用 `CaretRectLocator.queryCaretRect()`，难以 mock。

**建议**：考虑引入协议抽象（可选，当前改动较小可暂不处理）。

---

## 修复方案

### 方案 A：Fallback 到鼠标位置 + Debug 日志（推荐）

#### 修改 1：添加 `mouseLocationAsRect()` 方法

```swift
// CaretLoadingOverlay.swift

private nonisolated static let mouseFallbackHeight: CGFloat = 14

private nonisolated static func mouseLocationAsRect() -> CGRect {
    let location = NSEvent.mouseLocation
    return CGRect(x: location.x, y: location.y, width: 0, height: mouseFallbackHeight)
}
```

#### 修改 2：修改 `show()` 方法

```swift
func show() {
    // 调试日志（生产环境关闭）
    #if DEBUG
    let startTime = CFAbsoluteTimeGetCurrent()
    defer {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print(String(format: "CaretLoadingOverlay.show() completed in %.2fms", elapsed))
    }
    #endif

    var caretRect = CaretRectLocator.queryCaretRect()

    // Fallback: 当光标检测失败时使用鼠标位置
    if caretRect == nil {
        #if DEBUG
        print("⚠️ CaretLoadingOverlay: queryCaretRect returned nil, using mouse location fallback")
        #endif
        caretRect = Self.mouseLocationAsRect()
    }

    guard let caretRect, let visibleFrame = Self.visibleFrame(for: caretRect) else {
        #if DEBUG
        print("⚠️ CaretLoadingOverlay: visibleFrame calculation failed")
        #endif
        return
    }

    let origin = Self.panelOrigin(
        for: caretRect,
        overlaySize: Self.overlaySize,
        withinVisibleFrame: visibleFrame
    )

    panel.setFrame(NSRect(origin: origin, size: Self.overlaySize), display: false)
    syncAppearance()
    startAnimating()
    panel.orderFrontRegardless()
}
```

**优点**：
- 实现简单，无破坏性变更
- 用户体验：Loading 出现在鼠标附近（通常接近光标）
- 向后兼容：原生 App 仍使用精确光标位置
- Debug 日志便于问题诊断

**缺点**：
- 精度略低（鼠标 vs 光标）
- Debug 日志在生产环境自动关闭

---

## 实施步骤

### Step 1: 添加 `mouseLocationAsRect()` 方法

**文件**: `Sources/MorphoApp/Support/CaretLoadingOverlay.swift`

在 `spinnerPath` 方法后添加：

```swift
private nonisolated static let mouseFallbackHeight: CGFloat = 14

private nonisolated static func mouseLocationAsRect() -> CGRect {
    let location = NSEvent.mouseLocation
    return CGRect(x: location.x, y: location.y, width: 0, height: mouseFallbackHeight)
}
```

### Step 2: 修改 `show()` 方法

修改 `show()` 方法，添加 fallback 逻辑和 debug 日志。

### Step 3: 添加单元测试

**文件**: `Tests/MorphoAppTests/Support/CaretOverlayGeometryTests.swift`

添加以下测试：

```swift
func testMouseLocationAsRectHasValidHeight() {
    let rect = CaretLoadingOverlay.mouseLocationAsRect()
    XCTAssertEqual(rect.height, 14)
}

func testMouseLocationAsRectHasZeroWidth() {
    let rect = CaretLoadingOverlay.mouseLocationAsRect()
    XCTAssertEqual(rect.width, 0)
}
```

### Step 4: 测试验证

| 应用 | 测试场景 | 预期结果 |
|------|----------|----------|
| 备忘录 | 原生输入框 | Loading 出现在光标旁 |
| Chrome | textarea 输入 | Loading 出现在鼠标位置 |
| 微信 | 搜索框输入 | Loading 出现在鼠标位置 |
| Electron App | 任意输入框 | Loading 出现在鼠标位置 |

### Step 5: 验证调试日志

在 Debug 配置下运行，触发翻译时观察控制台输出：
- `⚠️ CaretLoadingOverlay: queryCaretRect returned nil, using mouse location fallback`

---

## 相关文件

| 文件 | 操作 |
|------|------|
| `Sources/MorphoApp/Support/CaretLoadingOverlay.swift` | 修改 |
| `Tests/MorphoAppTests/Support/CaretOverlayGeometryTests.swift` | 添加测试 |
| `docs/progress/2026-03-05-caret-loading-overlay-status.md` | 更新状态 |
| `docs/compatibility/app-compatibility-log.md` | 更新兼容性记录 |

---

## 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|----------|
| 鼠标位置不准确 | 低 | 用户通常在光标附近操作 |
| 性能影响 | 无 | 鼠标位置获取是同步 API |
| 向后兼容 | 无 | 优先使用精确光标，fallback 保守 |
| Debug 日志性能 | 低 | 仅在 DEBUG 配置下编译 |

---

## 验收标准

- [ ] `show()` 方法在光标检测失败时使用鼠标位置
- [ ] Debug 构建显示日志，生产构建无日志
- [ ] 单元测试覆盖 fallback 逻辑
- [ ] Chrome/微信/Electron 中 loading 可见
