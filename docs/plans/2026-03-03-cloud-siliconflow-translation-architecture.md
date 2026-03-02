# Cloud-Only Translation (SiliconFlow First) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 移除本地/System 翻译，改为纯云端翻译；首期接入硅基流动，并在架构上预留后续接入微软等多 Provider。

**Architecture:** Application 层只依赖 `TranslationEngine` 抽象。Infrastructure 使用 `CloudTranslationEngine` + `CloudTranslationProviderClient` 插件化模型，`AppSettings` 仅保存当前 Provider，API Key 走 Keychain。新增 Provider 时仅新增 client 与注册映射，不影响用例编排和 UI 主结构。

**Tech Stack:** Swift 6.2, Foundation(URLSession), Security(Keychain), SwiftUI, XCTest

---

## Design Analysis

### 方案 A（推荐）: 单一 Cloud Engine + Provider Client 插件化
- `CloudTranslationEngine` 读取 `settings.translationProvider`，分发到对应 Provider Client。
- Provider Client 负责协议细节（Endpoint、Headers、Body、错误映射）。
- Keychain 凭据存储通过 `CloudCredentialStore` 抽象解耦。

优点：
- 分层清晰：UseCase 不接触 HTTP/厂商协议。
- 扩展成本低：新增 Provider 不改核心链路。
- 测试边界清晰：UseCase、Engine、Provider 可独立测试。

### 方案 B: Engine 内硬编码硅基流动
优点：
- 开发快。

缺点：
- 后续接微软会产生二次重构。
- Provider 语义与配置无法沉淀。

### 决策
采用方案 A，符合项目“极简但可扩展”的原则。

## Provider Contract（首期 SiliconFlow）
- Endpoint: `POST https://api.siliconflow.cn/v1/chat/completions`
- Auth: `Authorization: Bearer <API_KEY>`
- 协议: OpenAI-Compatible Chat Completions
- 输入: system+user prompt（限定“只返回翻译结果，不要解释”）
- 输出: `choices[0].message.content`

参考：
- [SiliconFlow OpenAI Compatible 文档](https://docs.siliconflow.cn/cn/api-reference/chat-completions/chat-completions)
- [SiliconFlow Quick Start](https://docs.siliconflow.cn/cn/userguide/quickstart)

## Domain Changes
- `TranslationBackend` -> `TranslationProvider`（`siliconFlow`，预留新增枚举值）
- `AppSettings.translationBackend` -> `translationProvider`
- 新增凭据接口：
  - `CloudCredentialStore`（按 Provider 读写 API Key）

## Error Model Changes
- 移除 System 专属错误：
  - `translationSessionStartupTimeout`
  - `translationInProgress`
  - `systemTranslatorUnavailable`
- 新增云端通用错误：
  - `cloudCredentialMissing`
  - `cloudAuthenticationFailed`
  - `cloudRateLimited`
  - `cloudServiceUnavailable`

---

### Task 1: 设置模型与持久化迁移

**Files:**
- Modify: `Sources/MorphoKit/Domain/Models/TextContext.swift`
- Modify: `Sources/MorphoKit/Domain/Models/AppSettings.swift`
- Modify: `Sources/MorphoKit/Infrastructure/Settings/UserDefaultsSettingsStore.swift`
- Test: `Tests/MorphoKitTests/Infrastructure/Settings/UserDefaultsSettingsStoreTests.swift`

**Steps:**
1. 先写失败测试（旧 `translationBackend` 数据可迁移到 `translationProvider = siliconFlow`）。
2. 实现枚举与持久化字段迁移逻辑。
3. 运行 `swift test --filter UserDefaultsSettingsStoreTests`。

### Task 2: 凭据存储抽象 + Keychain 实现

**Files:**
- Modify: `Sources/MorphoKit/Domain/Protocols/TranslationContracts.swift`
- Create: `Sources/MorphoKit/Infrastructure/Security/KeychainCloudCredentialStore.swift`
- Create: `Tests/MorphoKitTests/Infrastructure/Security/KeychainCloudCredentialStoreTests.swift`

**Steps:**
1. 先写失败测试（save/load/delete API Key）。
2. 实现 `CloudCredentialStore` 与 Keychain 存储。
3. 运行 `swift test --filter KeychainCloudCredentialStoreTests`。

### Task 3: 云端 Provider 客户端与 SiliconFlow 实现

**Files:**
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/CloudTranslationProviderClient.swift`
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/SiliconFlowTranslationProviderClient.swift`
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/CloudHTTPClient.swift`
- Create: `Sources/MorphoKit/Infrastructure/Translation/Cloud/URLSessionCloudHTTPClient.swift`
- Test: `Tests/MorphoKitTests/Infrastructure/Translation/SiliconFlowTranslationProviderClientTests.swift`

**Steps:**
1. 先写失败测试（请求结构 + 响应解析 + 错误码映射）。
2. 实现 client，默认模型先用稳定可用常量，并可在代码中集中替换。
3. 运行 `swift test --filter SiliconFlowTranslationProviderClientTests`。

### Task 4: CloudTranslationEngine 接管主链路，移除本地翻译

**Files:**
- Create: `Sources/MorphoKit/Infrastructure/Translation/CloudTranslationEngine.swift`
- Modify: `Sources/MorphoKit/Infrastructure/Translation/DefaultTranslationEngineFactory.swift`
- Delete: `Sources/MorphoKit/Infrastructure/Translation/SystemTranslationEngine.swift`
- Delete: `Sources/MorphoKit/Infrastructure/Translation/TranslationTaskBridgeHost.swift`
- Delete: `Sources/MorphoKit/Infrastructure/Translation/TranslationErrorMapper.swift`
- Delete: `Sources/MorphoKit/Infrastructure/Translation/CloudTranslationEnginePlaceholder.swift`
- Test: `Tests/MorphoKitTests/Infrastructure/TranslationEngineFactoryTests.swift`
- Test: `Tests/MorphoKitTests/Infrastructure/Translation/CloudTranslationEngineTests.swift`

**Steps:**
1. 先写失败测试（缺少 API Key、调用 provider、错误透传）。
2. 实现 engine 与 factory。
3. 删除本地/System 链路。
4. 运行相关测试。

### Task 5: 用例与设置 UI 改造

**Files:**
- Modify: `Sources/MorphoKit/Application/HandleHotkeyTranslationUseCase.swift`
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`
- Modify: `Sources/MorphoApp/Views/SettingsView.swift`
- Test: `Tests/MorphoKitTests/Application/HandleHotkeyTranslationUseCaseTests.swift`

**Steps:**
1. 先写失败测试（UseCase 从 settings 取 provider 分发）。
2. 修改注入链路。
3. 设置页增加 API Key 输入、Provider 选择（当前仅硅基流动，但结构可扩）。
4. 运行相关测试。

### Task 6: 错误文案、文档与全量验证

**Files:**
- Modify: `Sources/MorphoKit/Domain/Errors/TranslationWorkflowError.swift`
- Modify: `Sources/MorphoKit/Application/TranslationErrorPresenter.swift`
- Modify: `Tests/MorphoKitTests/Application/TranslationErrorPresenterAdditionalTests.swift`
- Modify: `README.md`
- Modify: `docs/architecture/system-level-input-translation-mvp.md`

**Steps:**
1. 先写失败测试（新增云端错误文案）。
2. 实现错误映射与文案。
3. 文档更新为 SiliconFlow First + 多 Provider 预留。
4. 运行 `swift test` 全量验证。

---

## Verification Checklist
- `swift test` 全绿
- 设置页可保存 API Key（Keychain）
- 快捷键触发翻译端到端可用
- 缺失 Key、401、429、5xx 都有明确反馈

## Relevant Skills
- `@superpowers/brainstorming`
- `@superpowers/writing-plans`
- `@superpowers/test-driven-development`
- `@superpowers/verification-before-completion`
