# Settings V2 Plan and Delivery (Plan + Completion)

## Goal
在不破坏现有分层（Domain / Application / Infrastructure / Presentation）的前提下，将 Morpho 设置页从单页 Form 重构为 Voxt 风格的“侧栏导航 + 内容卡片”，并分阶段落地设置模型扩展、运行历史、开机启动等能力。

## Locked Decisions
1. 第一阶段优先框架迁移，不一次性堆叠全部能力。
2. 语言页包含界面语言与翻译语言配置。
3. 翻译引擎页包含 Provider + API Key + Model。
4. 模型第一版为固定下拉（当前单模型预设）。
5. 历史记录最终记录成功翻译项（时间/输入/输出/语言方向）。
6. 开机启动最终接入系统能力，不做绕过方案。
7. 视觉最终跟随系统明暗模式。

## Phase Plan

### Phase A: 设置页骨架重构 + 能力迁移
- 建立 `SettingsShell + Sidebar + Card + Panes` 组件体系。
- 将快捷键、语言、引擎、关于等能力从旧 `Form` 迁移到独立 pane。
- 调整设置窗口尺寸到 `760 x 560`，形成桌面端设置中心结构。

### Phase B: 配置模型与持久化一致性
- 扩展 `AppSettings`：
  - `launchAtLoginPreferred`
  - `interfaceLanguageCode`
  - `translationModelID`
- 打通 `AppSettings -> UserDefaultsSettingsStore -> MorphoAppModel -> View` 单向链路。
- 确保旧配置缺失字段时回落默认值，保障兼容迁移。

### Phase C: 体验收口与真实能力
- 新增运行历史领域与存储：`RunHistoryEntry` + `RunHistoryStore` + `FileRunHistoryStore`。
- 在 `HandleHotkeyTranslationUseCase` 成功路径写入历史。
- 历史页支持列表展示、分页加载、清空。
- 开机启动接入 `SMAppService`，失败回滚并提供错误提示。
- 翻译模型选择透传到 cloud 调用链路（非 UI 假开关）。

## Completion Status

### Phase A (Completed)
- [x] 新增设置导航和统一卡片体系。
- [x] 设置页拆分为 6 个 pane：General / Hotkey / Language / Engine / History / About。
- [x] 设置窗口尺寸调整为 `760 x 560`。

主要文件：
- `Sources/MorphoApp/Views/Settings/SettingsShellView.swift`
- `Sources/MorphoApp/Views/Settings/SettingsSidebarView.swift`
- `Sources/MorphoApp/Views/Settings/SettingsCard.swift`
- `Sources/MorphoApp/Views/Settings/Panes/*.swift`
- `Sources/MorphoApp/Views/SettingsView.swift`
- `Sources/MorphoApp/MorphoApp.swift`

### Phase B (Completed)
- [x] 扩展 `AppSettings` 新字段及默认值。
- [x] 扩展 `UserDefaultsSettingsStore` 新字段持久化与迁移回退。
- [x] 扩展 `MorphoAppModel` 更新接口：
  - `updateLaunchAtLoginPreferred(_:)`
  - `updateInterfaceLanguageCode(_:)`
  - `updateTranslationModelID(_:)`
- [x] 增加界面语言/模型选项支持文件。

主要文件：
- `Sources/MorphoKit/Domain/Models/AppSettings.swift`
- `Sources/MorphoKit/Infrastructure/Settings/UserDefaultsSettingsStore.swift`
- `Sources/MorphoApp/MorphoAppModel.swift`
- `Sources/MorphoApp/Support/InterfaceLanguageOptions.swift`
- `Sources/MorphoApp/Support/TranslationModelOptions.swift`

### Phase C (Completed)
- [x] 新增运行历史模型与协议。
- [x] 新增文件存储实现（默认上限 500 条）。
- [x] 在翻译成功路径写入历史。
- [x] 历史页已展示真实历史（时间、输入、输出、方向）并支持清空。
- [x] 开机启动接入 `SMAppService`（错误回滚+提示）。
- [x] 模型 ID 已透传到 cloud 调用链路。

主要文件：
- `Sources/MorphoKit/Domain/Models/RunHistoryEntry.swift`
- `Sources/MorphoKit/Domain/Protocols/RunHistoryStore.swift`
- `Sources/MorphoKit/Infrastructure/Settings/FileRunHistoryStore.swift`
- `Sources/MorphoKit/Application/HandleHotkeyTranslationUseCase.swift`
- `Sources/MorphoKit/Domain/Protocols/TranslationContracts.swift`
- `Sources/MorphoKit/Infrastructure/Translation/CloudTranslationEngine.swift`
- `Sources/MorphoKit/Infrastructure/Translation/Cloud/CloudTranslationProviderClient.swift`
- `Sources/MorphoKit/Infrastructure/Translation/Cloud/SiliconFlowTranslationProviderClient.swift`
- `Sources/MorphoApp/Support/LaunchAtLoginController.swift`
- `Sources/MorphoApp/Views/Settings/Panes/HistorySettingsPane.swift`

## Tests and Verification
已完成测试补充并通过全量测试：
- `Tests/MorphoKitTests/Infrastructure/Settings/UserDefaultsSettingsStoreTests.swift`
  - 新字段保存/加载/缺省回退
- `Tests/MorphoKitTests/Infrastructure/Settings/FileRunHistoryStoreTests.swift`
  - 历史追加、裁剪、清空
- `Tests/MorphoKitTests/Application/HandleHotkeyTranslationUseCaseTests.swift`
  - 翻译成功写历史
- `Tests/MorphoKitTests/Infrastructure/Translation/CloudTranslationEngineTests.swift`
  - 模型透传
- `Tests/MorphoKitTests/Infrastructure/Translation/SiliconFlowTranslationProviderClientTests.swift`
  - 请求 body 使用指定模型

验证命令：
```bash
swift test
```

验证结果：
- 65 tests executed
- 0 failures

## Notes
- 本次提交仅包含 Settings V2 相关改动与沉淀文档。
- 工作区中与本任务无关的未跟踪文件（如 `.claude/`、`docs/sinan-*`）不纳入提交。
