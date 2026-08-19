# 花计2046 接线清单

## 快速开始（密钥配置）

项目密钥不再写入源码，而是通过 `Configs/Local.xcconfig` 注入到 Info.plist。

1. 复制模板文件：
   ```bash
   cp Configs/Local.xcconfig.example Configs/Local.xcconfig
   ```

2. 编辑 `Configs/Local.xcconfig`，填入你的真实密钥：
   ```text
   SUPABASE_URL = https://your-project.supabase.co
   SUPABASE_FUNCTIONS_URL = https://your-project.functions.supabase.co/functions/v1
   SUPABASE_ANON_KEY = your-anon-key
   DEEPSEEK_API_KEY = your-deepseek-key       # 仅 DEBUG 文字解析使用
   ```

3. `Configs/Local.xcconfig` 已被 `.gitignore` 忽略，**切勿提交到版本库**。

> ⚠️ 如果之前已将密钥提交到 Git 历史，请立即在对应服务商后台轮换（revoke）旧密钥并生成新密钥。

---

## 快速测试（无需后端）

Debug 构建可通过 `Configs/Debug.xcconfig` 中的 `INFOPLIST_KEY_USE_MOCK_SERVICES` 控制 Mock 模式。

- 默认 `NO`：连接真实 Supabase 后端。
- 改为 `YES`：启用本地 Mock，适合快速验证 UI 和交互流程（此时登录/注册会失败，但不会崩溃）。

修改后无需改动源码即可切换。

---

## 1. App Store Connect（免费版）

当前版本为**全免费版**，不包含应用内购买（IAP）或订阅。

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)。
2. 确保 App 的 Bundle ID 为 `com.nsoft.huaji2046`。
3. 定价选择免费。

---

## 2. Supabase

1. 创建 Supabase 项目。
2. 在 SQL Editor 按顺序执行 `supabase/migrations/` 下的迁移文件：
   - `001_core_schema.sql`
   - `002_income_support.sql`
   - `003_user_logs.sql`
   - `004_currency_field.sql`
   - `005_user_settings.sql`
   - `006_bill_reminders.sql`
   - `008_bill_reminders_once.sql`
   - `009_bill_reminders_weekly.sql`
   - `011_income_category_investment.sql`
   - `012_goal_targets.sql`
   - `013_profiles_name.sql`
   - `014_parse_usage.sql`
3. 确认 Auth 使用 email/password。
4. 将项目 URL 与 Anon Key 填入 `Configs/Local.xcconfig`。

## 3. Edge Functions

部署以下函数（`parse-expense` 同时支持文字和语音解析）：

```text
supabase/functions/parse-expense
supabase/functions/delete-account
supabase/functions/spending-review
```

函数环境变量：

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
GEMINI_API_KEY
DEEPSEEK_API_KEY
```

## 4. Xcode Packages

项目源码需要这些 Swift Package：

```text
https://github.com/supabase/supabase-swift
```

Stripe iOS SDK 已移除。

## 5. 在测试机安装

1. 用 Xcode 打开 `花计2046.xcodeproj`
2. 选择 Debug scheme
3. 连接测试设备或选择模拟器
4. `Product > Run` (⌘R)

---

## 安全开发约定

- 所有密钥通过 `Local.xcconfig` 管理，源码和 `project.pbxproj` 中不再保留真实密钥。
- 提交前运行 `git status`，确认 `Local.xcconfig` 未被加入暂存区。

## 6. 隐私清单

项目已配置 `花计2046/PrivacyInfo.xcprivacy`，声明了以下隐私相关内容：

- **收集的数据类型**：邮箱、语音输入、用户输入文本、用户 ID、产品交互日志
- **访问的 API**：UserDefaults（用于保存应用设置和每日限额状态）
- **追踪**：不进行跨 App/网站追踪

提交 App Store 前，请根据实际情况复核该文件中的声明是否完整准确。

## 7. 隐私政策与服务条款

项目已内置本地法律文档：

- `花计2046/Legal/PrivacyPolicy.html` — 隐私政策
- `花计2046/Legal/TermsOfService.html` — 服务条款

这两个文件同时满足：
1. **应用内查看**：登录页（注册时勾选同意）和「我的」页面均可直接打开查看。
2. **网站托管**：可将 HTML 内容部署到官网，把链接填入 App Store Connect 的隐私政策 URL。

建议将隐私政策页面托管到稳定域名，例如：
```text
https://your-domain.com/privacy
https://your-domain.com/terms
```

提交 App Store 时，必须在 App Store Connect 中填写隐私政策 URL。

## 8. 账号删除

应用内「我的」页面提供「注销账号」功能，调用 `supabase/functions/delete-account` Edge Function。

该函数会删除以下数据：

- `profiles` 用户资料
- `records` 记账记录
- `user_settings` 用户设置
- `bill_reminders` 账单提醒
- `user_logs` 操作记录
- `auth.users` 认证账号

部署该函数需要环境变量：

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

> 当前版本为免费版，不涉及订阅或应用内购买。

## 9. 密码重置

登录页「忘记密码？」已接通 Supabase 邮件重置流程：

1. 用户输入邮箱，App 调用 Supabase `resetPasswordForEmail` 发送重置邮件。
2. 邮件链接的 redirect URL 为 `huaji2046://reset-password`（App 自定义 scheme）。
3. 用户点击邮件链接后唤起 App，`__2046App.onOpenURL` 捕获 token 并建立重置会话。
4. App 弹出「设置新密码」界面，调用 `auth.update` 完成修改。

### Supabase 侧配置

在 Supabase 控制台 → Authentication → URL Configuration 中，将 **Redirect URLs** 添加：

```text
huaji2046://reset-password
```

> 邮件模板默认包含 `redirect_to` 参数，确保模板中使用了 `{{ .RedirectTo }}` 占位符。
> 自定义 scheme 在真机上测试才有效，模拟器不支持邮件唤起。

## 10. 设备支持

应用仅支持 **iPhone**（`TARGETED_DEVICE_FAMILY = 1`），不支持 iPad。

- AppIcon 只需 iPhone 尺寸（已配置）。
- App Store 提交时按 iPhone 应用提交。
- 如需未来支持 iPad，需在 `Assets.xcassets/AppIcon.appiconset` 中补充 iPad 图标尺寸，并将 `TARGETED_DEVICE_FAMILY` 改回 `1,2`。

## 11. 单元测试

测试位于 `花计2046Tests/`，使用 Swift Testing 框架。

覆盖范围：
- 数学计算器（`MathCalculatorTests`）
- 搜索过滤（`SearchFilterTests`）
- 图表 ID 稳定性（`AnalyticsChartIDTests`）
- Record 模型与编码（`RecordModelTests`、`RecordTypeTests`）
- 月份分组汇总（`MonthRecordGroupTests`、`MonthExpenseGroupTests`）
- 每日解析限额（`DailyLimitManagerTests`）
- 成就引擎与持久化（`AchievementEngineTests`、`AchievementPersistenceTests`）

运行测试：

```bash
xcodebuild test \
  -project 花计2046.xcodeproj \
  -scheme 花计2046 \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

当前状态：63 个测试全部通过。

## 12. 智能体配置

用户在注册页和「我的 → 智能体配置」中可以配置自己的大模型智能体：

- 支持 DeepSeek、OpenAI、Kimi、通义千问、智谱 GLM、Gemini、豆包及 OpenAI 兼容自定义接口。
- API Key 保存在本机 Keychain，不上传云端。
- 保存前会实际调用一次接口验证；Key 无效提示「请正确配置智能体」，欠费/限流/服务异常会提示对应原因。
- 配置成功后，AI 解析、语音入账和最近收支评价优先调用用户自己的智能体，且不受每日 30 次限制。
- 用户智能体调用失败时自动临时降级到默认智能体，并在 App 内提示异常原因。

## 13. 已完成的 P2/P3 优化

| 任务 | 说明 |
|---|---|
| 共享组件提取 | 通用组件（AmountTextField、KeyboardDoneTextEditor、MatrixTextView、DateWheelPicker）集中到 `Views/SharedComponents.swift` |
| 错误提示优化 | 编辑保存失败回滚本地并提示；删除失败提示；修复编辑页校验错误无提示的 bug |
| SearchState 拆分 | 搜索筛选状态从 SupabaseService 拆到 `Views/SearchState.swift`（共享单例，跨页联动） |
| 大数据量性能优化 | `categories` / `yearOptions` 派生数据改为缓存，避免每次渲染全量过滤 |

### 待办：国际化（P3）

完整国际化尚未实施。规模评估：

- 54 个源文件含中文
- 1285 行代码含中文
- 1139 处中文字符串字面量
- 614 个唯一中文字符串

**建议**：中文 App 上架不强制国际化；如计划出海，需单独一轮大改造：
1. Xcode 创建 String Catalog（Localizable.xcstrings）
2. 提取全部 UI 文案并替换为 `Text("key")` / `NSLocalizedString`
3. 提供英文（及更多语言）翻译
4. 本地化 Info.plist 权限文案（InfoPlist.strings）
5. 回归测试

预计工作量 1–2 天（全职）。

## 14. 国际化（已完成基础版）

已创建 `花计2046/Localizable.xcstrings`（String Catalog），收录 **413 条中→英翻译**。

- **机制**：SwiftUI `Text("中文")` 自动通过 `LocalizedStringKey` 在 String Catalog 中查找英文翻译，无需改动任何业务代码。
- **效果**：设备语言为英文时，主要 UI 文案显示英文；中文设备显示中文（行为不变）。
- **验证**：编译产物中已生成 `en.lproj/Localizable.strings`；62 个测试全部通过。

### 未覆盖部分（后续可补充）

1. 带插值/格式符的字符串（约 131 条，如 `已选 \(count) 条记录`）——String Catalog 需以 `%lld` 格式收录，建议在 Xcode 的 String Catalog 编辑器中手动处理
2. 日志类中文字符串（不翻译，不影响 UI）
3. 若需更多语言，在 Xcode 中打开 `Localizable.xcstrings` 添加语言即可

翻译字典备份：`docs/translations.py`（中→英映射，可复用生成脚本）。
