# Settings UX 改造方案

## 进度状态（2026-04-07）

- 状态：已按本方案完成第一阶段实现并通过本地构建与测试验证。
- 结果：Language + Engine 已合并为 `Mode` tab，WorkMode 成为设置页核心入口，语言与引擎配置在同一页按方案落地。
- 验证：`swift build`、`swift test` 均通过。

## Context

Polish mode 已实现（`96bd368`），但 WorkMode 在设置页面完全缺席——只能通过菜单栏切换，没有解释、没有配置入口。同时现有 6 个 tab 中，Language（实际显示为"翻译"）和 Engine 是割裂的，用户需要跨 tab 才能完成"Morpho 按热键后做什么"这个核心配置。

## 改造目标

将 Language + Engine 两个 tab **合并为 Mode tab**，让 WorkMode 成为设置页的核心入口，语言和引擎配置作为同一 tab 下的子卡片，语言卡片根据当前模式动态切换内容。

## Tab 结构：6 → 5

| Tab | 标签 | 图标 | 内容 |
|-----|------|------|------|
| general | General / 通用 | `slider.horizontal.3` | 不变 |
| hotkey | Hotkey / 快捷键 | `keyboard` | 不变 |
| **mode** | **Mode / 模式** | `arrow.triangle.swap` | **WorkMode 选择 + 语言配置 + 引擎配置** |
| history | History / 运行历史 | `clock.arrow.circlepath` | 不变 |
| about | About / 关于 | `info.circle` | 不变 |

## Mode Tab 详细设计

### Card 1: 工作模式
- **Segmented Picker**: Translate / Polish（`maxWidth: 300`）
- 下方根据当前 mode 显示说明文字：
  - Translate: "检测源语言，将选中文本翻译为目标语言"
  - Polish: "检测选中文本的语言，用同一语言对文本进行润色改写"

### Card 2: 语言设置（条件渲染）
- **Translate 模式**: 显示 source picker + target picker + auto-detect toggle + hint（复用现有 LanguageSettingsPane 内容）
- **Polish 模式**: 显示一行信息文字 "润色模式下自动检测语言并用同一语言改写，无需配置"

### Card 3: 引擎配置
- Provider picker + Model picker + API Key 输入（复用现有 EngineSettingsPane 内容）
- 两种模式共享，始终显示

## 实现步骤

### Step 1: 提取共享 `MenuPickerRow`
- 从 `GeneralSettingsPane.swift`、`LanguageSettingsPane.swift`、`EngineSettingsPane.swift` 三处重复的 `private struct MenuPickerRow` 提取为独立文件
- **新建** `Sources/MorphoApp/Views/Settings/MenuPickerRow.swift`（`internal` 可见性）
- 删除三个文件中的 `private` 副本

### Step 2: `MorphoAppModel` 添加 `updateWorkMode(_:)`
- 文件: `Sources/MorphoApp/MorphoAppModel.swift`
- 添加 `func updateWorkMode(_ mode: WorkMode)` — 直接赋值 + persistSettings
- 保留现有 `toggleWorkMode()` 给菜单栏使用

### Step 3: 更新 `SettingsTab` 枚举
- 文件: `Sources/MorphoApp/Views/Settings/SettingsTab.swift`
- 删除 `language` 和 `engine` case
- 新增 `mode` case（在 hotkey 之后、history 之前）
- titleKey → `"settings.tab.mode"`，iconName → `"arrow.triangle.swap"`

### Step 4: 新建 `ModeSettingsPane.swift`
- **新建** `Sources/MorphoApp/Views/Settings/Panes/ModeSettingsPane.swift`
- 包含 3 张 SettingsCard：工作模式 + 语言（条件渲染）+ 引擎
- API key 的 `@State apiKeyDraft` / `@FocusState` 逻辑从 EngineSettingsPane 迁移过来

### Step 5: 更新 `SettingsShellView` 路由
- 文件: `Sources/MorphoApp/Views/Settings/SettingsShellView.swift`
- 删除 `.language` 和 `.engine` case
- 新增 `.mode: ModeSettingsPane(model: model)`

### Step 6: 删除旧 pane 文件
- 删除 `LanguageSettingsPane.swift`
- 删除 `EngineSettingsPane.swift`

### Step 7: 本地化字符串
- 文件: `en.lproj/Localizable.strings` + `zh-Hans.lproj/Localizable.strings`
- 新增 keys:
  - `settings.tab.mode` = "Mode" / "模式"
  - `settings.mode.title` / `.description`
  - `settings.mode.translate.description` / `settings.mode.polish.description`
  - `settings.mode.language.title` / `.polish_info`
- 删除: `settings.tab.translation`、`settings.tab.engine`
- 保留 `settings.translation.*` 和 `settings.engine.*` keys（内容复用于新 pane）

### Step 8: 更新测试
- 搜索引用 `SettingsTab.language` / `SettingsTab.engine` 的测试，更新为 `.mode`

## 不变的部分

- Domain 层 (`AppSettings`, `WorkMode`, `HandleHotkeyTranslationUseCase`) — 零改动
- Infrastructure 层 (`UserDefaultsSettingsStore`) — 零改动
- 菜单栏 `MorphoMenuView` — 保留 mode toggle 按钮不变
- General / Hotkey / History / About tab — 不变

## 关键文件

| 文件 | 操作 |
|------|------|
| `Sources/MorphoApp/Views/Settings/MenuPickerRow.swift` | **新建** |
| `Sources/MorphoApp/Views/Settings/Panes/ModeSettingsPane.swift` | **新建** |
| `Sources/MorphoApp/Views/Settings/SettingsTab.swift` | 修改 |
| `Sources/MorphoApp/Views/Settings/SettingsShellView.swift` | 修改 |
| `Sources/MorphoApp/MorphoAppModel.swift` | 修改（添加方法） |
| `Sources/MorphoApp/Views/Settings/Panes/GeneralSettingsPane.swift` | 修改（删除重复 struct） |
| `Sources/MorphoApp/Views/Settings/Panes/LanguageSettingsPane.swift` | **删除** |
| `Sources/MorphoApp/Views/Settings/Panes/EngineSettingsPane.swift` | **删除** |
| `Resources/en.lproj/Localizable.strings` | 修改 |
| `Resources/zh-Hans.lproj/Localizable.strings` | 修改 |

## 验证

1. `swift build` 编译通过
2. `swift test` 全部测试通过
3. 手动验证：Settings 打开默认 General → 切到 Mode tab → segmented picker 切换 Translate/Polish → 语言卡片内容随之切换
4. 手动验证：Polish 模式下语言卡片只显示信息文字，无 picker
5. 手动验证：API key 输入、model 选择在 Mode tab 中正常工作
6. 菜单栏 mode toggle 与 Settings 中的 picker 状态同步
