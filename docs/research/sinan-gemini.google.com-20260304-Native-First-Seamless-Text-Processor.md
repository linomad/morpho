# Sinan Export

- Source: gemini.google.com
- URL: https://gemini.google.com/u/2/app/2033d6106dd0ffae?pageId=none
- Exported At: 2026-03-04 17:04:23
- Selected Count: 1

## ```我的要求是 不用考虑 老的 Electron 版本 不用考虑密码输入 这种场景 将 主流 APP 的支持当做最高优先...

> ```我的要求是 不用考虑 老的 Electron 版本 不用考虑密码输入 这种场景 将 主流 APP 的支持当做最高优先级 对剪贴板的污染是「尽量无」也就是 能有更好的方案时最好用别的，它只当做最兜底的场景。 ``` 请基于这个，再更新下 方案

明确了你的核心诉求：**“主流 APP 优先、现代环境、极力避免剪贴板”**。这就要求我们把 macOS 的系统级 API 压榨到极致。

在现代 macOS 环境下（抛开老旧应用和密码框），要实现\*\*无痕（Zero-Clipboard）\*\*的文本读取与替换，我们不能仅仅停留在基础的 `Accessibility API`，而是要深入到 WebKit 和 Chromium 底层暴露的扩展无障碍接口，以及针对特定环境的自动化脚本。

基于你的严格要求，为你重新梳理这套\*\*“渐进式降级 (Progressive Fallback)”\*\*的技术方案架构。

### 终极架构设计：三层防御体系

要做到尽量不污染剪贴板并支持主流 App，你的程序需要按照以下优先级依次尝试执行：

#### 🚀 第一层：原生与私有 Accessibility API (最高优先级，零剪贴板污染)

这是实现无痕替换的核心。但主流 App (如 Chrome, Safari, VS Code, Notion 等现代 Electron/Web 核心应用) 对基础 `AXUIElement` 的支持往往不够，你需要引入更深层的 API。

1.  **基础 `AXUIElement` (针对纯原生 App)**

    -   **获取：** 通过 `kAXFocusedUIElementAttribute` 获取焦点元素。尝试读取 `kAXSelectedTextAttribute`。如果为空，读取 `kAXValueAttribute`。

    -   **替换：** 使用 `AXUIElementSetAttributeValue` 直接将翻译后的文本写回。

    -   **适用：** 备忘录、Pages、Xcode、系统设置等纯原生 Cocoa 应用。

2.  **进阶 `AXTextMarker` (针对 Chromium / WebKit 系主流 App)**

    -   **原理：** 对于 Chrome、Safari 以及现代 Electron 应用，它们内部的文本渲染非常复杂，往往不会直接返回 `kAXSelectedTextAttribute`。此时必须使用苹果未公开（但业界广泛使用，如 Grammarly 桌面版都在用）的 `AXTextMarker` 和 `AXTextMarkerRange` 机制。

    -   **操作：** \* 查询元素的 `kAXSelectedTextMarkerRangeAttribute`。

        -   通过 `kAXStringForTextMarkerRangeParameterizedAttribute` 获取选中文本。

        -   如果没有选中，可以查询 `kAXStartTextMarkerAttribute` 和 `kAXEndTextMarkerAttribute` 来构建一个包含全部文本的 Range，再获取完整内容。

        -   **替换：** 在 WebKit/Chromium 中，直接用 AX API 写回文本极其困难且极易失败。通常只能读取，**替换时可能仍需降级**，或者使用系统的原生文本替换快捷键（如果该应用实现了相关 NSTextView 接口）。

    -   **注意：** 这是一个 C 语言级别的 CoreFoundation 接口，如果是上架 Mac App Store 会有审核风险，但对于独立分发的效率工具，这是标配。

#### 🌐 第二层：AppleScript / JXA 注入 (针对主流浏览器)

如果你发现用户当前活跃的 App 是主流浏览器（Chrome, Safari, Edge, Arc 等），并且第一层的 AX API 获取或替换失败了，直接走系统底层的 AppleScript 桥接，操作页面的 DOM。

-   **原理：** 通过 `NSAppleScript` 或 `OSAScript` 向目标浏览器发送指令，执行 JavaScript。

-   **获取与替换：**

    JavaScript

    ```
    // 伪代码逻辑注入
    var activeElement = document.activeElement;
    if (activeElement.value !== undefined) {
        // 处理 Input 或 Textarea
        var selectedText = activeElement.value.substring(activeElement.selectionStart, activeElement.selectionEnd);
        // 如果没选中，获取全部
        // ...执行替换...
    } else if (activeElement.isContentEditable) {
        // 处理富文本编辑器 (如飞书文档、Notion 网页版)
        var selection = window.getSelection();
        // ...执行获取与替换...
    }
    ```

-   **优点：** 完美绕过剪贴板，直接在 DOM 层级完成“读取 替换”，对前端开发者来说逻辑非常清晰。

-   **缺点：** 仅限浏览器和部分支持 AppleScript 字典的 App。

#### 🛡️ 第三层：极致优化的剪贴板流 (绝对兜底)

当且仅当上述方案全部抛出异常（例如遇到了不支持 AppleScript 且完全自绘 UI 的奇葩跨平台应用），才启动剪贴板方案。为了满足你“尽量不污染”的要求，我们需要做**剪贴板状态保护**。

-   **执行流程：**

    1.  **挂起监控：** 暂停你自己 App 内可能存在的剪贴板监听器。

    2.  **快照备份：** 读取当前 `NSPasteboard` 中的所有类型数据（不仅是 String，可能还有图片、RTF 富文本等，必须完整备份）。

    3.  **清空与触发：** 清空剪贴板 发送 `Cmd+C` 轮询检测剪贴板变更（超时 150ms 认为无选中）。

    4.  **全选触发：** 如果无选中 发送 `Cmd+A` 发送 `Cmd+C`。

    5.  **写入与替换：** 获取文本进行翻译 将翻译结果写入剪贴板 发送 `Cmd+V`。

    6.  **微秒级恢复：** 等待 `Cmd+V` 的系统事件消耗完毕后（通常延时 50-100ms），立即将第 2 步的**快照数据还原**回剪贴板。

-   **效果：** 用户在感知上，文本被瞬间替换了。如果他们按下 `Cmd+V`，粘贴出来的依然是他们之前复制的图片或文字，感觉不到剪贴板被借用过。

* * *

### 方案总结与优先级排序

| 执行顺位 | 技术路线 | 适用主流场景 | 剪贴板污染度 | 获取能力 | 替换能力 |
| --- | --- | --- | --- | --- | --- |
| **1** | **AXUIElement** | 原生 App (Xcode, 备忘录, Pages) | 零 | 完美 | 完美 |
| **2** | **AXTextMarker** | 现代 Electron (VS Code, Slack), WebKit | 零 | 极佳 | 较弱 (多需降级) |
| **3** | **AppleScript / JXA** | 主流浏览器 (Chrome, Safari, Edge) | 零 | 极佳 | 极佳 |
| **4** | **受保护的剪贴板流** | 未知/自绘 UI 的应用作为兜底 | 极低 (瞬间恢复) | 完美 (需模拟按键) | 完美 (需模拟按键) |

这种架构下，绝大部分现代主流应用（前端和原生）都在前三层被消化了，只有极少数场景会触发行云流水般快速恢复的第四层。

在这个流程中，**第二层的 Web/浏览器 DOM 注入（AppleScript/JXA）** 或 **第一层中未公开的 AXTextMarker 探秘** 都是相对容易踩坑的深水区。你需要我为你展开讲讲这其中哪一部分的具体实现思路？