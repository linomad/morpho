# Sinan Export

- Source: claude.ai
- URL: https://claude.ai/chat/1c01e238-b533-467a-b73c-dd088403134e
- Exported At: 2026-03-04 15:42:31
- Selected Count: 1

## 我再补充下我的诉求，可以将我的诉求备注在你的输出最开始的部分， 我的要求是 1. 不用考虑 老的 Electron 版本...

> 我再补充下我的诉求，可以将我的诉求备注在你的输出最开始的部分， 我的要求是 1. 不用考虑 老的 Electron 版本 2. 不用考虑密码输入 这种场景 3. 将 主流 APP 的支持当做最高优先级 4. 对剪贴板的污染是「尽量无」也就是 能有更好的方案时最好用别的，它只当做最兜底的场景。 ， 请你再更新下 三个方案

## 我的诉求备注

```
1. 不用考虑老的 Electron 版本
2. 不用考虑密码输入场景
3. 主流 App 支持为最高优先级
4. 剪贴板污染「尽量无」，仅作最兜底场景
```

* * *

## 主流 App 覆盖分析（决策基础）

在以上前提下，先明确「主流 App」的 AX 支持现状：

| App | AX 读取 | AX 写回 | 备注 |
| --- | --- | --- | --- |
| Chrome / Safari / Edge | ✅ | ✅ | 表单、地址栏全支持 |
| VSCode | ✅ | ✅ | Electron 新版完整支持 |
| 微信 / 钉钉 / 飞书 | ✅ | ✅ | 均可 |
| Xcode | ✅ | ✅ |  |
| Terminal / iTerm2 | ✅ | ✅ |  |
| Notion / Obsidian | ✅ | ✅ | Electron 新版 |
| Word / Pages | ✅ | ⚠️ 写回不稳定 | 降级剪贴板 |
| WPS | ✅ | ⚠️ | 降级剪贴板 |

> **结论：AXUIElement 可覆盖 ~95% 主流场景，剪贴板仅兜底 Word/WPS 等少数 Office 类 App。**

* * *

## 🥇 方案一：AXUIElement 直读直写

**推荐指数：★★★★★ 日常主力**

**定位：** 覆盖 95% 主流 App，零剪贴板污染

swift

```swift
import Cocoa

class AXTextReplacer {

    // MARK: - 权限
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - 快照（快捷键触发瞬间同步调用）
    func captureContext() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp) == .success else { return nil }

        var focusedEl: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedEl) == .success else { return nil }

        return focusedEl as! AXUIElement
    }

    // MARK: - 读（优先选中，无选中读全部）
    func readText(from el: AXUIElement) -> (text: String, hasSelection: Bool)? {
        var ref: CFTypeRef?

        // 优先读选中
        if AXUIElementCopyAttributeValue(el,
            kAXSelectedTextAttribute as CFString, &ref) == .success,
           let str = ref as? String, !str.isEmpty {
            return (str, true)
        }

        // 无选中，读整个输入框内容
        if AXUIElementCopyAttributeValue(el,
            kAXValueAttribute as CFString, &ref) == .success,
           let str = ref as? String, !str.isEmpty {
            return (str, false)
        }

        return nil
    }

    // MARK: - 写回
    @discardableResult
    func writeBack(to el: AXUIElement,
                   newText: String,
                   hasSelection: Bool) -> Bool {
        // 有选中 → 只替换选中部分；无选中 → 替换整个输入框
        let attr = hasSelection
            ? kAXSelectedTextAttribute
            : kAXValueAttribute

        return AXUIElementSetAttributeValue(
            el, attr as CFString, newText as CFTypeRef
        ) == .success
    }
}
```

### 配合异步翻译的正确姿势

swift

```swift
class TranslationCoordinator {
    let ax = AXTextReplacer()
    var savedElement: AXUIElement?
    var savedHasSelection = false

    func onHotkey() {
        // ⚠️ 必须在快捷键触发瞬间同步保存 element
        // 翻译是异步的，等结果回来时焦点可能已丢失
        guard let el = ax.captureContext(),
              let (text, hasSel) = ax.readText(from: el) else { return }

        savedElement    = el
        savedHasSelection = hasSel

        Task {
            let result = await MyTranslateAPI.translate(text)
            await MainActor.run {
                guard let el = self.savedElement else { return }
                self.ax.writeBack(to: el,
                                  newText: result,
                                  hasSelection: self.savedHasSelection)
            }
        }
    }
}
```

**不适用场景：** Word / WPS / Pages 等 Office 类 App 写回不稳定 → 交由方案三降级处理

* * *

## 🥈 方案二：AXSelectedTextRange 精准范围替换

**推荐指数：★★★★☆ AX 增强版**

**定位：** 方案一的增强，针对「无选中时只替换光标所在段落」而非整个输入框，体验更精准

> 适合输入框内容很长时（如 VSCode 编辑大文件），不希望替换全部内容

swift

```swift
import Cocoa

class AXRangeReplacer {

    // MARK: - 读取选中范围
    func getSelectedRange(from el: AXUIElement) -> CFRange? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el,
            kAXSelectedTextRangeAttribute as CFString,
            &ref) == .success else { return nil }

        var range = CFRange()
        guard AXValueGetValue(ref as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    // MARK: - 读取光标所在行/段落（无选中时的替代策略）
    func getParagraphAtCursor(from el: AXUIElement) -> (text: String, range: CFRange)? {
        var ref: CFTypeRef?

        // 获取光标位置
        guard AXUIElementCopyAttributeValue(el,
            kAXSelectedTextRangeAttribute as CFString,
            &ref) == .success else { return nil }

        var cursorRange = CFRange()
        AXValueGetValue(ref as! AXValue, .cfRange, &cursorRange)
        let cursor = cursorRange.location

        // 获取全文
        var valRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el,
            kAXValueAttribute as CFString,
            &valRef) == .success,
              let fullText = valRef as? String else { return nil }

        let nsText = fullText as NSString

        // 获取光标所在段落范围
        let paraRange = nsText.paragraphRange(
            for: NSRange(location: min(cursor, nsText.length), length: 0)
        )

        let paraText = nsText.substring(with: paraRange)
        let cfRange  = CFRange(location: paraRange.location,
                                length: paraRange.length)

        return (paraText, cfRange)
    }

    // MARK: - 按范围精准替换
    @discardableResult
    func replaceRange(in el: AXUIElement,
                      range: CFRange,
                      with newText: String) -> Bool {
        // 1. 先将选区设置到目标范围
        var mutableRange = range
        guard let axRange = AXValueCreate(.cfRange, &mutableRange) else { return false }

        guard AXUIElementSetAttributeValue(el,
            kAXSelectedTextRangeAttribute as CFString,
            axRange) == .success else { return false }

        // 2. 替换选中区域
        return AXUIElementSetAttributeValue(
            el,
            kAXSelectedTextAttribute as CFString,
            newText as CFTypeRef
        ) == .success
    }
}
```

### 典型调用逻辑

swift

```swift
func onHotkey() {
    guard let el = axReplacer.captureContext() else { return }

    let targetText: String
    let targetRange: CFRange?

    let selectedRange = rangeReplacer.getSelectedRange(from: el)

    if let r = selectedRange, r.length > 0 {
        // 有选中：读选中文本
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &ref)
        targetText  = ref as? String ?? ""
        targetRange = r
    } else {
        // 无选中：取光标所在段落
        guard let para = rangeReplacer.getParagraphAtCursor(from: el) else { return }
        targetText  = para.text
        targetRange = para.range
    }

    // 保存快照
    let savedEl    = el
    let savedRange = targetRange

    Task {
        let result = await MyTranslateAPI.translate(targetText)
        await MainActor.run {
            if let range = savedRange {
                rangeReplacer.replaceRange(in: savedEl, range: range, with: result)
            }
        }
    }
}
```

**优势：** 输入框内容再长，也只替换用户真正关心的段落，不误伤其他内容

* * *

## 🥉 方案三：AX 优先 + 剪贴板兜底组合

**推荐指数：★★★★★ 生产必选**

**定位：** 前两方案的统一封装，自动降级，剪贴板仅在 AX 彻底失败时启用

swift

```swift
import Cocoa

// MARK: - 上下文快照（触发时保存）
struct TextContext {
    let text: String
    let hasSelection: Bool
    let source: Source
    let axElement: AXUIElement?
    let axRange: CFRange?
    let targetApp: NSRunningApplication?

    enum Source { case ax, clipboard }
}

// MARK: - 剪贴板替换（仅兜底）
private class ClipboardFallback {
    private let pb = NSPasteboard.general

    private func save() -> [(NSPasteboard.PasteboardType, Data)] {
        pb.pasteboardItems?.flatMap { item in
            item.types.compactMap { t in item.data(forType: t).map { (t, $0) } }
        } ?? []
    }

    private func restore(_ saved: [(NSPasteboard.PasteboardType, Data)]) {
        pb.clearContents()
        let item = NSPasteboardItem()
        saved.forEach { item.setData($0.1, forType: $0.0) }
        pb.writeObjects([item])
    }

    private func key(_ code: CGKeyCode, flags: CGEventFlags = .maskCommand) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: 0.01)
    }

    func capture() -> String? {
        let saved = save()
        pb.clearContents()
        key(0x08)                                    // Cmd+C
        Thread.sleep(forTimeInterval: 0.08)
        let result = pb.string(forType: .string)
        restore(saved)                               // 立即还原，不污染
        return result?.isEmpty == false ? result : nil
    }

    func paste(_ text: String, selectAll: Bool) {
        let saved = save()
        if selectAll { key(0x00) ; Thread.sleep(forTimeInterval: 0.03) } // Cmd+A
        pb.clearContents()
        pb.setString(text, forType: .string)
        key(0x09)                                    // Cmd+V
        // 粘贴完成后还原剪贴板
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.restore(saved)
        }
    }
}

// MARK: - 统一引擎
class TextReplacementEngine {
    private let ax  = AXTextReplacer()
    private let cb  = ClipboardFallback()

    // Step 1 - 快捷键触发瞬间同步调用
    func capture() -> TextContext? {
        let app = NSWorkspace.shared.frontmostApplication

        // ── 优先 AX ──────────────────────────────────
        if let el = ax.captureContext(),
           let (text, hasSel) = ax.readText(from: el) {
            return TextContext(text: text, hasSelection: hasSel,
                               source: .ax, axElement: el,
                               axRange: nil, targetApp: app)
        }

        // ── 兜底：剪贴板（仅 AX 完全失败时）─────────
        if let text = cb.capture() {
            return TextContext(text: text, hasSelection: true,
                               source: .clipboard, axElement: nil,
                               axRange: nil, targetApp: app)
        }

        return nil
    }

    // Step 2 - 翻译完成后调用
    func replace(context: TextContext, with newText: String) {
        DispatchQueue.main.async {
            switch context.source {

            case .ax:
                guard let el = context.axElement else { return }
                let ok = self.ax.writeBack(to: el,
                                           newText: newText,
                                           hasSelection: context.hasSelection)
                // AX 写回失败（如 Word/WPS）→ 再降级剪贴板
                if !ok { self.fallbackPaste(context: context, newText: newText) }

            case .clipboard:
                self.fallbackPaste(context: context, newText: newText)
            }
        }
    }

    private func fallbackPaste(context: TextContext, newText: String) {
        context.targetApp?.activate(options: .activateIgnoringOtherApps)
        Thread.sleep(forTimeInterval: 0.05)
        cb.paste(newText, selectAll: !context.hasSelection)
    }
}
```

### 最终调用（3 行）

swift

```swift
let engine = TextReplacementEngine()

func onHotkey() {
    guard let ctx = engine.capture() else { return }     // 1. 同步快照

    Task {
        let result = await MyAPI.translate(ctx.text)     // 2. 异步翻译
        engine.replace(context: ctx, with: result)       // 3. 写回
    }
}
```

* * *

## 三方案横向对比

|  | 方案一 AX直读写 | 方案二 AX范围替换 | 方案三 AX+剪贴板兜底 |
| --- | --- | --- | --- |
| **推荐指数** | ★★★★★ | ★★★★☆ | ★★★★★ |
| **主流 App 覆盖** | ~95% | ~95% | ~99% |
| **剪贴板污染** | 无 | 无 | 仅兜底时短暂 |
| **无选中时替换粒度** | 整个输入框 | 光标所在段落 ✨ | 继承前两者 |
| **实现复杂度** | 低 | 中 | 中 |
| **适合 App Store** | ✅ | ✅ | ✅ |

**建议：** 直接采用**方案三**作为整体架构，内部的「无选中替换粒度」按需选择方案一或方案二的逻辑。