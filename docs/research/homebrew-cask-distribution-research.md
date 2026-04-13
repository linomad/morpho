# Homebrew Cask 发布调研报告

> 调研日期: 2026-04-13
> 相关项目: Morpho - 系统级输入翻译 macOS 应用

---

## 一、Morpho 项目概况

**应用类型**: macOS GUI 菜单栏应用  
**构建输出**: `Morpho.app` bundle (通过 `scripts/package-macos-app.sh` 打包)  
**目标平台**: macOS 15.0+  
**Bundle ID**: `com.zhengyuelin.morpho`  
**签名状态**: 默认 ad-hoc 签名，支持 Developer ID 签名

### 关键特性评估

| 特性 | 状态 | 对 Cask 的影响 |
|------|------|---------------|
| 有 GUI | ✅ | 符合 Cask 定位 |
| 输出 .app bundle | ✅ | 符合 Cask 要求 |
| 开源 | ✅ | 支持 GitHub Releases 分发 |
| 辅助功能权限需求 | ⚠️ | 需要用户授权，不影响 Cask |
| 代码签名 | ⚠️ | 必须用 Apple Developer ID |

---

## 二、Homebrew Cask 基础

### 2.1 什么是 Cask

Cask 是 Homebrew 用于分发**闭源或 GUI 软件**的机制。与 Formula（从源码构建）不同，Cask 直接下载预编译的应用包（.app、.dmg、.pkg）。

### 2.2 适合 Cask 的场景

✅ **推荐使用 Cask**:
- GUI macOS 应用
- 预编译的第三方二进制
- 闭源软件
- 需要拖拽到 Applications 的应用

❌ **不适合 Cask** (应使用 Formula):
- CLI-only 开源工具
- 必须从源码构建的软件
- 需要特定编译选项的软件

### 2.3 基本 Cask 结构

```ruby
cask "morpho" do
  version "1.0"
  sha256 "abc123..."
  
  url "https://github.com/linomad/morpho/releases/download/v#{version}/Morpho.app.zip",
      verified: "github.com/linomad/morpho/"
  
  name "Morpho"
  desc "System-level input translation for macOS"
  homepage "https://github.com/linomad/morpho"
  
  livecheck do
    url :url
    strategy :github_latest
  end
  
  depends_on macos: ">= :sequoia"
  
  app "Morpho.app"
  
  zap trash: [
    "~/Library/Application Support/Morpho",
    "~/Library/Preferences/com.zhengyuelin.morpho.plist",
    "~/Library/Saved Application State/com.zhengyuelin.morpho.savedState",
  ]
end
```

---

## 三、Cask 发布流程

### 3.1 准备工作清单

1. **代码签名** (必需)
   - 使用 Apple Developer ID 签名应用
   - ad-hoc 签名无法通过 Apple Silicon 的 Gatekeeper
   - 命令: `codesign --force --deep --options runtime --sign "Developer ID" Morpho.app`

2. **创建 GitHub Release**
   - 上传签名的 `.app.zip`
   - 使用语义化版本号 (如 v1.0.0)
   - 提供稳定的下载 URL

3. **满足知名度门槛** (官方 Cask 要求)
   - 自建提交: 30+ forks, 30+ watchers, 75+ stars
   - 自我提交 (作者): 90+ forks, 90+ watchers, 225+ stars

### 3.2 创建 Cask 文件

```bash
# 生成分发 token
$(brew --repository homebrew/cask)/developer/bin/generate_cask_token "Morpho"

# 创建 cask 文件
brew create --cask <download-url> --set-name morpho

# 编辑生成的模板
brew edit morpho
```

### 3.3 测试与验证

```bash
# 禁用自动更新
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_FROM_API=1

# 安装测试
brew install morpho

# 卸载测试
brew uninstall morpho

# 审计检查
brew audit --new --cask morpho

# 风格检查
brew style morpho
```

### 3.4 提交到 Homebrew

```bash
# Fork homebrew/cask 仓库
# 添加 cask 文件到 Casks/m/morpho.rb
# 提交 PR，遵循 Git commit 规范: "morpho 1.0.0 (new cask)"
```

---

## 四、官方 Cask vs 自建 Tap

### 4.1 官方 Homebrew Cask (homebrew-cask)

**优势**:
- 用户只需 `brew install morpho`
- 自动更新支持 (`brew upgrade`)
- 高可信度和曝光度

**劣势**:
- 需要较高的知名度门槛
- 审核周期不确定
- 必须合规且通过审计

### 4.2 自建 Tap (推荐短期方案)

**创建方式**:

1. 创建 GitHub 仓库: `linomad/homebrew-morpho`

2. 在仓库中添加 `Casks/morpho.rb`

3. 用户安装方式:
```bash
brew tap linomad/morpho
brew install morpho
```

**优势**:
- 无知名度要求
- 完全控制更新节奏
- 立即可用

**劣势**:
- 用户需要多执行 `brew tap`
- 需要自行维护

---

## 五、Morpho 项目的建议方案

### 方案 A: 先自建 Tap (推荐)

**时间线**: 立即实施

**步骤**:
1. 创建 `linomad/homebrew-morpho` 仓库
2. 配置 Cask 文件指向 GitHub Release
3. 在 README 中添加安装说明

**适用阶段**: MVP 阶段，知名度积累期

### 方案 B: 官方 Cask (中长期)

**前置条件**:
- [ ] 获取 Apple Developer 证书 ($99/年)
- [ ] 用 Developer ID 签名发布
- [ ] GitHub 仓库达到知名度门槛

**适用阶段**: 产品成熟后，由社区成员或自己去提交

---

## 六、Cask 配置示例

### 6.1 Morpho Cask 完整模板

```ruby
cask "morpho" do
  version "1.0.0"
  sha256 "..."

  url "https://github.com/linomad/morpho/releases/download/v#{version}/Morpho.app.zip",
      verified: "github.com/linomad/morpho/"
  
  name "Morpho"
  desc "System-level input translation for macOS"
  homepage "https://github.com/linomad/morpho"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sequoia"

  app "Morpho.app"

  zap trash: [
    "~/Library/Application Support/Morpho",
    "~/Library/Preferences/com.zhengyuelin.morpho.plist",
    "~/Library/Saved Application State/com.zhengyuelin.morpho.savedState",
  ]
end
```

### 6.2 GitHub Actions 自动发布

在 `.github/workflows/release.yml` 中配置:

```yaml
- name: Build and Sign
  run: |
    ./scripts/package-macos-app.sh --sign-identity "${{ secrets.DEVELOPER_ID }}"
    shasum -a 256 dist/Morpho.app.zip
```

---

## 七、关键问题 FAQ

### Q1: 没有 Apple Developer 账号能发布 Cask 吗？
❌ **不能**。Apple Silicon Mac 要求应用必须签名才能通过 Gatekeeper，Homebrew Cask 明确拒绝未签名的应用。

### Q2: 知名度门槛可以跳过吗？
⚠️ 如果是**维护者或活跃贡献者**提交，可能有例外。但最安全的方式是等待或推广项目积累 stars。

### Q3: 可以用自建 Tap 作为临时方案吗？