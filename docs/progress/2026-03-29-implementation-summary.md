# 2026-03-28 实现进度总结

**日期范围**: 2026-03-26 ~ 2026-03-29
**记录时间**: 2026-03-29

---

## 概览

本次迭代主要完成了以下三个功能：

1. **Menu Bar 呼吸点指示器** — 优化翻译状态反馈
2. **应用图标品牌化** — 视觉形象升级
3. **Electron/Chromium 兼容性修复** — 恢复文本替换功能

---

## 1. Menu Bar 呼吸点指示器

### 问题背景

原实现使用 globe 图标循环切换来表示翻译进行中，动画生硬且占用较多视觉注意力。

### 解决方案

改用静态 `m.circle.fill` 图标 + 呼吸动画圆点 overlay：

| 参数 | 值 | 说明 |
|------|-----|------|
| 基础图标 | `m.circle.fill` | 品牌化 M 字母 |
| 呼吸周期 | 1.35s | 平静、不打扰 |
| Scale 范围 | 0.68 ~ 1.0 | 呼吸缩放效果 |
| Alpha 范围 | 0.58 ~ 1.0 | 呼吸透明度 |
| 延迟显示 | 200ms | 跳过快速翻译 |
| 最小显示 | 350ms | 防止闪烁 |
| 淡出时间 | 150ms | 平滑消失 |
| Reduce Motion | 静态圆点 | 无障碍支持 |

### 架构改动

```
MenuBarIconStateMachine
  ├─ idle → loading → fadingOut → idle
  └─ 发布 MenuBarIconRenderState
      ├─ baseSymbol: String
      ├─ dotScale: CGFloat?
      └─ dotAlpha: CGFloat
```

### 涉及提交

| 提交 | 描述 |
|------|------|
| `c50c3e3` | refactor: rewrite MenuBarIconStateMachine with breathing dot phase |
| `a1c6975` | feat: menu bar breathing dot indicator during translation |
| `242a32f` | refactor: tune menu bar icon rendering and busy indicator behavior |

### 相关文档

- `docs/architecture/2026-03-28-menu-bar-busy-indicator-design.md` — 设计规范
- `docs/plans/2026-03-28-menu-bar-busy-indicator.md` — 实施计划

---

## 2. 应用图标品牌化

### 改动内容

1. 添加 Gloock 字体变体图标（bricolage、crimsonpro、ibmplexserif、youngserif）
2. 更新所有 macOS App 图标尺寸（16-512px @1x/2x）
3. 修复打包脚本正确生成 AppIcon.icns

### 涉及提交

| 提交 | 描述 |
|------|------|
| `7d6a065` | design: replace geometric M with Gloock typographic brand icon |
| `5d434c9` | feat: add app icon from morpho-app-icon.png, all macOS sizes |
| `6f65a45` | fix: generate AppIcon.icns and set CFBundleIconFile |

---

## 3. Electron/Chromium 兼容性修复

### 问题背景

Electron 应用（如 Codex App）中使用 CGEvent.keyboardSetUnicodeString() 直接注入文本失败，翻译无法正确替换。

### 根因分析

- CGEvent 在 Electron 自绘组件中被拦截
- 需要底层键盘事件支持

### 解决方案

回退到剪贴板粘贴方案：
1. 写入剪贴板
2. 模拟 ⌘V 粘贴
3. 使用 `NSPasteboard.PasteboardType.transient` 标记确保不污染剪贴板历史

### 涉及提交

| 提交 | 描述 |
|------|------|
| `4ccfd3a` | refactor: replace clipboard paste with CGEvent direct text injection |
| `8c1af04` | fix: restore clipboard paste fallback for Electron/Chromium compatibility |

### 兼容性测试结果

| 应用 | 翻译触发 | 文本替换 | 状态 |
|------|---------|---------|------|
| 原生 macOS App | ✅ | ✅ | ✅ |
| Chrome textarea | ✅ | ✅ | ✅ |
| Codex App (Electron) | ✅ | ✅ | ✅ |
| Chrome 地址栏 | ❌ | ❌ | 待处理 |

---

## 测试状态

所有测试通过：**98 tests, 0 failures** ✅

---

## 待处理项

1. **Caret Loading Overlay Web/Electron 降级**
   - 状态：计划中
   - 方案：光标检测失败时 fallback 到鼠标位置

2. **Chrome 地址栏兼容性**
   - 状态：待分析
   - 问题：Omnibox 自定义渲染，无法替换文本

3. **扩展兼容性测试**
   - 待测：Safari、VS Code、Slack、Discord、Notion Desktop、Obsidian、飞书、钉钉、微信
