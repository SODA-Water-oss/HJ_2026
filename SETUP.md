# 花计2046 接线清单

## 快速测试（无需后端）

Debug 构建默认开启 `USE_MOCK_SERVICES = YES`，应用可在没有 Supabase / Stripe 配置的情况下启动运行。此时：
- 登录/注册会失败（无后端），但不会崩溃
- 可在 AuthView 界面看到 Matrix 风格 UI
- 适合快速验证 UI 和交互流程

如需完整功能测试，按以下步骤配置：

---

## 1. 先轮换已经暴露过的密钥

当前仓库历史里曾经出现过 Gemini API key。继续开发前，请在 Google AI Studio 或 Google Cloud 控制台吊销旧 key，并创建新的 `GEMINI_API_KEY`。

## 2. Supabase

1. 创建 Supabase 项目。
2. 在 SQL Editor 执行 `supabase/migrations/001_core_schema.sql`。
3. 确认 Auth 使用 email/password。
4. 在 Xcode 项目的 target build settings 里替换这些 Info.plist 生成值：
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_FUNCTIONS_URL`

`SUPABASE_FUNCTIONS_URL` 的格式通常是：

```text
https://YOUR_PROJECT.functions.supabase.co/functions/v1
```

## 3. Edge Functions

部署这三个函数：

```text
supabase/functions/parse-expense
supabase/functions/create-payment-sheet
supabase/functions/stripe-webhook
```

函数环境变量：

```text
GEMINI_API_KEY
STRIPE_SECRET_KEY
STRIPE_PRICE_ID
STRIPE_WEBHOOK_SECRET
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

## 4. Stripe

1. 创建产品和订阅价格，复制 price id 到 `STRIPE_PRICE_ID`。
2. 在 Stripe dashboard 创建 webhook endpoint，指向：

```text
https://YOUR_PROJECT.functions.supabase.co/functions/v1/stripe-webhook
```

3. 监听这些事件：
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
4. 把 webhook signing secret 填到 `STRIPE_WEBHOOK_SECRET`。
5. 在 Xcode 里把 `STRIPE_PUBLISHABLE_KEY` 替换成真实 publishable key。

## 5. Xcode Packages

项目源码需要这些 Swift Package：

```text
https://github.com/supabase/supabase-swift
https://github.com/stripe/stripe-ios
```

目前 Gemini 已经改为只在 Edge Function 中调用，iOS 客户端不再需要 GoogleGenerativeAI 包。

## 6. 在测试机安装

1. 用 Xcode 打开 `花计2046.xcodeproj`
2. 选择 Debug scheme
3. 连接测试设备或选择模拟器
4. `Product > Run` (⌘R)

Debug 模式下自动启用 Mock 模式，无需配置任何密钥即可启动。
如需连接真实后端，在 Build Settings 中将 `USE_MOCK_SERVICES` 设为 `NO`，并填入上述密钥。
