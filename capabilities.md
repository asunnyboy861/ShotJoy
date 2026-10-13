# ShotJoy — 配置文档

生成时间：2026-10-13

---

## 一、⚠️ 手动配置（增强功能 — 不配置不影响基本使用）

> **重要说明**：以下配置项均为**增强功能**。不配置这些项，App 仍可正常使用全部核心功能（计算器、记录、身体地图、提醒、库存、症状、目标、Face ID 加密、AI 端侧兜底）。

### 🟡 Capabilities 增强配置

#### iCloud / CloudKit（跨设备同步）

**增强功能**：多设备数据同步（SwiftData + CloudKit 私有数据库）
**不配置的影响**：仅本地存储，App 完全正常运行，数据不跨设备同步
**当前状态**：App 已内置优雅降级链（CloudKit → 纯本地 → 内存兜底），无需配置即可正常使用

**已自动配置部分**：
- ✅ entitlements 已含 `com.apple.developer.icloud-services: [CloudKit]` + 容器 `iCloud.com.zzoutuo.ShotJoy`
- ✅ ASC App ID（6U3633YXYK）已启用 iCloud 能力（CloudKit XCODE_6）
- ✅ 代码已实现降级链（`ShotJoyApp.container`）
- ✅ Info.plist 已含 `UIBackgroundModes: remote-notification`（CloudKit 长连接推送）

**如需启用增强功能，请手动完成**：
1. **容器注册**（一次性）：用你的 Apple ID 打开 Xcode → Settings → Accounts 登录团队账号（JP4TN5PTS3）→ 首次执行 Product → Archive 或真机构建时，Xcode 会**自动**在开发者门户注册 `iCloud.com.zzoutuo.ShotJoy` 容器并生成带 iCloud 的描述文件（ASC API 无法创建容器，此步必须由 Xcode 完成）
2. **Schema 上线**（TestFlight 之后）：https://icloud.developer.apple.com → 选择容器 `iCloud.com.zzoutuo.ShotJoy` → **Deploy Schema Changes to Production**（也可让 AI 通过浏览器自动化完成，无需手动操作）

---

### 🔵 IAP StoreKit 配置（必须 — 否则订阅无法购买）

**影响功能**：不创建 IAP 产品，Paywall 加载不出价格，订阅/买断无法购买（免费核心功能不受影响）

**配置步骤**：
1. 打开 [App Store Connect](https://appstoreconnect.apple.com) → 我的 App → **创建 App 记录**（名称 ShotJoy、主语言 English (U.S.)、Bundle ID `com.zzoutuo.ShotJoy`、SKU `shotjoy001`）— 首次提审时创建即可
2. 进入 App → **Features → In-App Purchases**（订阅产品在 **Subscriptions**）
3. 创建订阅组 `ShotJoy Pro`，然后创建两个自动续订订阅：

| 产品 | Reference Name | Product ID | 价格 | 试用 |
|------|---------------|-----------|------|------|
| 月付 | ShotJoy Pro Monthly | `com.zzoutuo.shotjoy.pro.monthly` | $9.99/月 | 无 |
| 年付 | ShotJoy Pro Annual | `com.zzoutuo.shotjoy.pro.yearly` | $49.99/年 | 7 天免费试用 |

4. 再创建一个非消耗型内购：

| 产品 | Reference Name | Product ID | 价格 |
|------|---------------|-----------|------|
| BYO 终身买断 | ShotJoy BYO Lifetime | `com.zzoutuo.shotjoy.pro.lifetime` | $39.99 一次性 |

5. Display Name / Description 直接复制 `price.md` 中对应字段（已按 ≤35/≤55 字符校验）
6. ⚠️ 订阅组本地化、价格、审核截图（可用 App 内 Paywall 截图）需一并填写；产品创建后等待 Apple 处理（通常 1-2 小时）
7. 本地测试：Xcode 中可用 StoreKit Configuration 文件模拟（产品 ID 已在 `PurchaseManager.swift` 中对齐）

---

### 🟢 App Store Connect 审核信息配置（必须 — 防 Guideline 2.1(a) 拒审）

**影响功能**：不配置则审核员可能无法验证 AI/订阅功能

**配置步骤**：
1. App Store Connect → 你的 App → **App Review Information**
2. **Demo Account** 字段：粘贴 `app_review_info.md` 中 "Demo Account for Apple Review" 部分（含 Apple Intelligence 说明与模拟器 BYO Key 配置步骤）
3. **Notes** 字段：粘贴 `app_review_info.md` 的 "Review Notes" 部分（医疗合规框架、HealthKit 标识、AI 三通道、订阅测试信息）
4. ⚠️ 审核员设备无 Apple Intelligence 时（旧机型），Notes 里的 BYO Key 步骤可让其完成 AI 验证
5. **Privacy Policy URL**：`https://asunnyboy861.github.io/shotjoy/privacy.html`
6. **Terms of Use (EULA) URL**：`https://asunnyboy861.github.io/shotjoy/terms.html`（订阅 App 必填）
7. **Support URL**：`https://asunnyboy861.github.io/shotjoy/support.html`

---

## 二、✅ 自动配置记录（已由系统完成，无需操作）

### Capabilities 自动配置

| Capability | 说明 | 状态 |
|------------|------|------|
| HealthKit | entitlement + 4 条 usage strings + 合规 UI（header/图标/Learn More/InfoView/footer） | ✅ 已配置 |
| Push Notifications (aps-environment) | ASC 能力已启用 + entitlement（CloudKit 推送依赖） | ✅ 已配置 |
| iCloud/CloudKit | entitlements + ASC 能力启用（容器注册见 Section 一） | ✅ 已配置（容器待首归档） |
| Background Modes | remote-notification（CloudKit） | ✅ 已配置 |
| 相机 / Face ID | usage strings 已配置 | ✅ 已配置 |
| 隐私清单 | PrivacyInfo.xcprivacy（无追踪、无收集；UserDefaults/FileTimestamp 声明） | ✅ 已配置 |
| 本地通知 | 无需 capability，代码已实现 Shot Day 周提醒 | ✅ 已配置 |

### 后端与云服务

| 服务 | 说明 | 状态 |
|------|------|------|
| ASC App ID | `com.zzoutuo.ShotJoy`（6U3633YXYK）已注册并启用 HealthKit/iCloud/Push | ✅ 已完成 |
| 签名 Profile | ShotJoy Dev（开发验证）/ ShotJoy Dist（上架导出）已就绪 | ✅ 已完成 |
| GLM 共享 Worker | appId `shotjoy` ↔ `com.zzoutuo.ShotJoy` 已入 D1 白名单；E2E 200/400/401/405 全部通过 | ✅ 已完成 |
| GLM devKey（测试期） | 已注入 `ShotJoy/GLMProxySecret.txt`（gitignored，Release 构建自动排除）；生产走 StoreKit JWS 验签 | ✅ 已完成 |
| 联系客服后端 | `https://msg.calcs.top/api/feedback` 已部署并写入代码 | ✅ 已部署 |
| GitHub 仓库 | https://github.com/asunnyboy861/ShotJoy（53 文件，敏感文件零追踪） | ✅ 已推送 |
| GitHub Pages | Landing + Support + Privacy + Terms 已上线（HTTP 200） | ✅ 已部署 |
| App 图标 | Agnes Image 生成，RGB 无透明通道，1024 catalog | ✅ 已配置 |

### 代码与质量

| 模块 | 说明 | 状态 |
|------|------|------|
| 核心功能 | 20 个主功能全实现（MVVM + SwiftData + Swift Charts） | ✅ 已完成 |
| DrawGuard 引擎 | 纯函数 6 守卫 + 10 个单元测试全部通过 | ✅ 已完成 |
| AI 层 | AIRouter + Apple 端侧（免费 5 次/天）+ GLM Worker（Pro）+ BYO 六供应商（Keychain） | ✅ 已完成 |
| IAP 响应式 | PurchaseManager @Published + Transaction.updates 监听 + @StateObject 绑定 | ✅ 已完成 |
| 合规 | 13 项 BYO/订阅合规检查通过；四层医疗免责；HealthKit UI 标识齐全 | ✅ 已完成 |
| ASO | keytext.md 15 项验证全过（关键词 97/100 字符利用） | ✅ 已完成 |

### 💡 使用提示（非开发者配置，App 内操作即可）

**AI 功能**：App 默认使用 Apple Intelligence（设备端 + Private Cloud Compute，免费、无需任何配置）。不支持的设备上，用户可在 **Settings → AI → AI Engine (BYO)** 输入自己的 API Key（支持 GLM / OpenAI / DeepSeek / Gemini / Claude / 自定义兼容端点）。这是用户操作，不是开发者配置。

---

## 三、能力检测详情

> 以下为 PHASE 2 原始检测数据，已按新格式重组。

### Analysis

关键词检测：健康/HealthKit（指南"HealthKit 同步（体重/睡眠/步数）"）、通知/提醒（Shot Day ritual）、相机（SnapLog 拍瓶贴/拍餐）、Face ID（应用锁）、iCloud/同步（可选增强）、订阅（四档定价）。未检测到：定位、Siri、Watch（COULD 路线图未实现）、Widget（COULD 路线图未实现）。

### No Configuration Needed

- 定位、Siri、Family Controls、App Groups（MVP 无 Widget/Watch target）
- 出站网络（全 HTTPS，无需 ATS 例外；GLM Worker、反馈后端、政策页均为 HTTPS）

### Verification

- 模拟器构建（iOS 26.4 iPhone 16 / iPad Pro 13-inch M5）：✅ BUILD SUCCEEDED
- 签名验证（generic/platform=iOS，Manual + ShotJoy Dev Profile）：✅ PASSED（真实证书 Apple Development: he zhou (VX3Q75X27B)）
- 单元测试：✅ 10/10 DrawGuardTests 通过
- 自动签名限制说明：本机 Xcode 无登录账号，xcodebuild API-Key 自动签名报已知 "Authentication failed"（ios-appstore-upload SKILL.md 有记录）；Archive 时用 Xcode 账号自动签名，或 exportArchive 阶段 API Key 重签（始终可用）
