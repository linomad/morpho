# Backlog

## Next

- 新增 Microsoft Provider（基于现有 Cloud provider 抽象）
- 为不同 Provider 增加模型/endpoint 配置能力
- 扩展输入控件兼容性验收矩阵（Phase 1 之外应用）
  - 浏览器：Edge、Firefox
  - Electron/桌面：Discord、Notion Desktop、Obsidian
  - 原生：更多 AppKit / SwiftUI 文本控件组合

## Done

- 2026-03-03: 云端调用重试与退避策略（429/5xx）
  - 通过 `RetryingCloudHTTPClient` 装饰器在基础 HTTP 层实现
  - 指数退避（含 `maxDelay`）+ `Retry-After` 优先
- 2026-03-03: 自动检测下的双向语言对互译
  - 在 `AppSettings` 增加可选语言对配置并持久化
  - UseCase 基于检测结果做 A<->B 方向路由
  - 设置交互优化为“源语言 + 目标语言 + 自动检测开关”
