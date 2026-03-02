# Morpho MVP Progress (2026-03-02)

## Summary

已完成从 0 到 1 的可运行 MVP：项目初始化、分层实现、核心流程打通、测试覆盖、文档沉淀。

## Milestones

- A. 项目骨架与设置模型: 完成
- B. 全局快捷键与权限引导: 完成
- C. AX 文本读取/写回: 完成
- D. 系统翻译引擎接入: 完成
- E. 失败反馈与状态展示: 完成

## Completed Work

- 新建 SwiftPM 工程并拆分 `MorphoKit` + `MorphoApp`
- 实现菜单栏应用、设置页、状态展示
- 实现用例编排：`HandleHotkeyTranslationUseCase`
- 实现 AX 网关：
  - 焦点元素读取
  - 选中/全文替换
  - 父链回溯寻找可写文本元素
  - 文本类型解码（String/AttributedString/URL）
- 实现系统翻译：
  - macOS 26+: `TranslationSession(installedSource:target:)`
  - macOS 15-25: `translationTask` 桥接主流程
- 实现引擎工厂与 Cloud 占位
- 实现设置持久化（UserDefaults）
- 实现通知与菜单栏状态同步

## Verification Evidence

- `swift test`
  - 14 tests
  - 0 failures
- 运行验证
  - 应用可启动
  - 全局快捷键可注册
  - 失败路径可反馈状态

## Issues Encountered and Fixes

- 进程退出被误判为崩溃：
  - 结论：部分场景为会话回收，不是新增 crash
- 旧版本 `UserNotifications` 相关崩溃：
  - 通过无 bundle 场景下禁用通知调用规避启动异常
- 浏览器地址栏误报“没有找到可编辑输入框”：
  - 根因：只检查焦点元素且只接收 String
  - 修复：父链回溯 + 多类型文本解码 + 可写属性校验

## Backlog

见 `docs/todo.md`
