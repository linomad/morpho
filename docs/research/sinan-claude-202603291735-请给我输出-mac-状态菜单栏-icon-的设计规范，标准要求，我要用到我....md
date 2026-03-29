# Sinan Export

- Source: claude.ai
- URL: https://claude.ai/chat/b4fed9eb-c7ab-4a02-8f9c-83cf72bb7818
- Exported At: 2026-03-29 17:35:25
- Selected Count: 1

## 请给我输出 mac 状态菜单栏 icon 的设计规范，标准要求，我要用到我的 mac app 开发中，

> 请给我输出 mac 状态菜单栏 icon 的设计规范，标准要求，我要用到我的 mac app 开发中，

以下是 macOS 状态栏菜单图标的完整设计规范，结合 Apple HIG 及实际开发经验整理：

* * *

## 一、尺寸规范

菜单栏的高度随 macOS 版本演进：从最初的 19pt，到 Yosemite 的 22pt，再到 Big Sur 起固定为 **24pt**。尺寸单位是 point（pt），1pt = 1 非 Retina 像素 = 2 Retina 像素。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

尽管菜单栏高度因设备不同有变化（如带刘海的 MacBook Pro 为 37pt），但 **menu bar extra 的可用工作区固定为 22pt**，图标不能超过这个高度。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

| 参数 | 推荐值 |
| --- | --- |
| 图标设计尺寸 | **16×16pt**（圆形图标感知重量与系统图标一致） |
| 最大高度 | **22pt** |
| 导出 @1x（非 Retina） | 16×16px |
| 导出 @2x（Retina） | 32×32px |

> ⚠️ 特殊情况：14/16 寸 MacBook Pro 因刘海导致菜单栏高度可能是 27pt、29pt、34pt、37pt 或 43pt，但图标工作区仍不变。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

* * *

## 二、图标类型：Template Image（强烈推荐）

菜单栏图标可以是**全彩**或**单色 Template Image**。Template Image 是一种特殊图像——macOS 会忽略其颜色信息，只使用 Alpha 通道。**推荐使用 Template Image**，因为它能自动适配浅色/深色模式，无需提供两套资源。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

**实现方式（Swift）：**

swift

```swift
if let image = NSImage(named: "MenuBarIcon") {
    image.isTemplate = true
    statusItem.button?.image = image
}
```

* * *

## 三、颜色与透明度

由于 Template Image 会忽略颜色，设计稿中的图形应用**纯色填充**创作。如需表达状态或层次，可使用**不同透明度**——Apple 官方使用 **35% 不透明度**来表示禁用/非激活元素，这种做法常见于 Wi-Fi 信号强度、音量等图标中。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

| 透明度 | 用途 |
| --- | --- |
| 100% | 主图形（激活状态） |
| 35% | 禁用/次要元素（Apple 惯例） |
| 中间值 | 多级状态（如信号格） |

* * *

## 四、文件格式

支持的资源格式：

-   **单个 SVG**
-   **单个 PDF**
-   **PNG 对（1× 和 2×）** 分别对应非 Retina 和 Retina
-   **代码绘制**（适合动态内容，如显示当前日期的日历图标） [Bjango](https://bjango.com/articles/designingmenubarextras/)

推荐工作流：设计用 SVG，Xcode Asset Catalog 中以 PDF 或 SVG 导入，勾选 **Preserve Vector Data**，设置 Scales 为 **Single Scale**。

* * *

## 五、Padding 与对齐

通常**不需要内边距**，除非是为了辅助垂直居中。 [Bjango](https://bjango.com/articles/designingmenubarextras/)macOS 会自动将图标垂直居中于菜单栏。

设计时建议：

-   以 16×16pt 画布设计图形本体
-   导出时画布保持 16×16pt（不额外加 padding 画布）
-   视觉重量参考 SF Symbols 的同尺寸图标

* * *

## 六、适配无障碍「降低透明度」模式

系统辅助功能中的「降低透明度」选项会将菜单栏变为深灰或浅灰色背景，而非跟随壁纸的半透明效果。这是部分用户的真实使用场景，设计时值得关注。 [Bjango](https://bjango.com/articles/designingmenubarextras/)

Template Image 在此模式下会自动适配，无需额外处理。

* * *

## 七、开发侧关键 API

swift

```swift
// 创建固定宽度（方形）的状态栏图标
let statusItem = NSStatusBar.system.statusItem(
    withLength: NSStatusItem.squareLength
)

// 设置 Template Image
let button = statusItem.button
let image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: nil)
image?.isTemplate = true
button?.image = image
```

* * *

## 八、设计检查清单

-   [ ]  图标主体不超过 **16×16pt**，整体不超过 **22pt 高**
-   [ ]  使用 Template Image（`.isTemplate = true`）
-   [ ]  图形为**纯色 + Alpha** 构成，不依赖颜色传达信息
-   [ ]  禁用状态使用 **35% 透明度**
-   [ ]  导出 **@1x + @2x PNG** 或单张 **SVG/PDF**
-   [ ]  在浅色/深色模式下均测试显示效果
-   [ ]  开启「降低透明度」后验证可读性