# Backlog

## Next

- 新增 Microsoft Provider（基于现有 Cloud provider 抽象）
- 为不同 Provider 增加模型/endpoint 配置能力
- Caret Loading Overlay 在 Web/Electron 中的降级方案（fallback 到鼠标位置）
- 扩展输入控件兼容性验收矩阵（Phase 1 之外应用）
  - 浏览器：Edge、Firefox
  - Electron/桌面：Discord、Notion Desktop、Obsidian
  - 原生：更多 AppKit / SwiftUI 文本控件组合

## Done

- **2026-03-28: Menu Bar 呼吸点指示器**
  - 重写 `MenuBarIconStateMachine`，用静态 `m.circle.fill` 图标 + 呼吸动画圆点替代 globe 循环动画
  - 呼吸周期 1.35s，scale 0.68-1.0，alpha 0.58-1.0
  - 延迟显示 200ms，最小显示 350ms，淡出 150ms
  - 支持 Reduce Motion 模式
  - 参考：`docs/architecture/2026-03-28-menu-bar-busy-indicator-design.md`

- **2026-03-28: 应用图标品牌化**
  - 添加 Gloock 字体变体图标（bricolage、crimsonpro、ibmplexserif、youngserif）
  - 更新 App 图标资产（16-512px 所有尺寸）
  - 修复打包脚本以正确生成 AppIcon.icns

- **2026-03-28: Electron/Chromium 兼容性修复**
  - 从 CGEvent.keyboardSetUnicodeString() 回退到剪贴板粘贴方案
  - 为 Electron 应用恢复文本替换功能
  - 文档记录：`docs/compatibility/app-compatibility-log.md`

- **2026-03-03: 云端调用重试与退避策略（429/5xx）**
  - 通过 `RetryingCloudHTTPClient` 装饰器在基础 HTTP 层实现
  - 指数退避（含 `maxDelay`）+ `Retry-After` 优先
- **2026-03-03: 自动检测下的双向语言对互译**
  - 在 `AppSettings` 增加可选语言对配置并持久化
  - UseCase 基于检测结果做 A<->B 方向路由
  - 设置交互优化为"源语言 + 目标语言 + 自动检测开关"
