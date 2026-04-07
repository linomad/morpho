# Settings UX 改造方案（第二阶段）

## 进度状态（2026-04-07）

- 第一阶段（已完成，`31679ef`）：Language + Engine 合并为 `Mode`，引入 WorkMode 设置入口。
- 第二阶段（本次优化，已实现）：将原 `Mode` 拆分为 `Workflow + Engine` 两个页签，降低单页信息密度并提升可发现性。

## 背景与问题

第一阶段虽然让 WorkMode 进入设置页，但 `Mode` 页签承担了「工作模式 + 语言 + 引擎」三块内容，信息密度过高，认知负担偏重。

## 第二阶段目标

1. 将 Translation Engine 独立成单独页签。
2. 将 `Mode` 重命名为更语义化的 `Workflow`（中文“流程”）。
3. 保持 WorkMode 与语言配置联动不变。
4. 不改动 Domain / Infrastructure 逻辑，保证架构分层稳定。

## 最新 Tab 结构（6 个）

| Tab | 标签 | 图标 | 内容 |
|-----|------|------|------|
| general | General / 通用 | `slider.horizontal.3` | 不变 |
| hotkey | Hotkey / 快捷键 | `keyboard` | 不变 |
| workflow | Workflow / 流程 | `arrow.triangle.swap` | WorkMode + 语言配置 |
| engine | Engine / 引擎 | `waveform` | Provider + Model + API Key |
| history | History / 运行历史 | `clock.arrow.circlepath` | 不变 |
| about | About / 关于 | `info.circle` | 不变 |

## 详细设计

### Workflow 页签

- Card 1: 工作模式
  - Segmented Picker: Translate / Polish（`maxWidth: 300`）
  - 模式说明文案随选择切换
- Card 2: 语言设置（条件渲染）
  - Translate: Source + Target + Auto Detect
  - Polish: 仅说明文字（无需语言配置）

### Engine 页签

- Card 1: 引擎配置
  - Provider Picker
  - Model Picker
  - API Key 输入（保留实时保存逻辑）

## 实施结果

1. 新增 `WorkflowSettingsPane.swift`，承载 WorkMode 与语言配置。
2. 新增（恢复）`EngineSettingsPane.swift`，承载引擎配置。
3. 删除 `ModeSettingsPane.swift`。
4. `SettingsTab` 改为 `.workflow` + `.engine`。
5. `SettingsShellView` 路由切换到 `WorkflowSettingsPane` 与 `EngineSettingsPane`。
6. 本地化 key 改为 `settings.workflow.*` 与 `settings.tab.workflow`，并恢复 `settings.tab.engine`。
7. 共享 `MenuPickerRow` 与 `MorphoAppModel.updateWorkMode(_:)` 保持不变（沿用第一阶段产物）。

## 验证

1. `swift test --filter SettingsTabTests` 通过
2. `swift test` 全量通过（110 tests, 0 failures）

## 不变部分

- Domain 层：`AppSettings`、`WorkMode`、`HandleHotkeyTranslationUseCase`
- Infrastructure 层：`UserDefaultsSettingsStore`
- 菜单栏 `MorphoMenuView` 的 mode toggle 行为
