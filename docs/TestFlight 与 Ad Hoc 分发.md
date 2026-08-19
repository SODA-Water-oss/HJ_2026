# 花计2046 — TestFlight / Ad Hoc 稳定测试分发

> Debug 真机安装通常依赖短期 Development Profile，过期后设备会拒绝启动；当前项目已生成了 365 天有效的 Development Profile。
> 要长期稳定测试，应改用 TestFlight 或 Ad Hoc 分发，它们使用有效期更长的 Distribution 签名。

---

## 一、当前签名状态

本机当前已同时具备 `Apple Development` 和 `Apple Distribution` 证书，可以直接生成 Development、TestFlight 和 Ad Hoc 包。

要生成 TestFlight / Ad Hoc IPA，仍需完成 Distribution 配置：

1. 打开 Xcode → Settings → Accounts。
2. 登录你的 Apple Developer 账号。
3. 让 Xcode 自动下载 `Apple Distribution` 证书和签名身份。
4. 确认钥匙串里有有效身份：

```bash
security find-identity -v -p codesigning
```

正常应看到 `1) ... "Apple Distribution: ..."` 或 `"Apple Development: ..."`。

---

## 二、立即可用的 Development 长期真机包

当前描述文件 `dc0cbb9a-52f9-458e-84e1-89ec5d39aa14`：

- 类型：`iOS Team Provisioning Profile: com.nsoft.huaji2046`
- 有效期：到 2027-08-19（365 天）
- 已注册设备：`00008130-001E4DE022FA001C`

```bash
cd /Volumes/MyData/【01工作资料】/【MyWork】/MyAPP/001_HJ/花计2046
./scripts/build-development.sh
```

产物：

```text
Build/Development/花计2046.xcarchive
Build/Development/花计2046.ipa
```

当前已导出一份可直接安装的 IPA：

```text
Build/Development/花计2046.ipa
```

已用 `xcrun devicectl` 安装并启动到在线设备 `Axo Luck`（`02372313-8E4B-5F36-9A27-3EB6441901DA`）。

安装到其他已注册设备：

```bash
xcrun devicectl device install app \
  --device <设备UDID> \
  Build/Development/花计2046.ipa
```

这个方案不需要 Distribution 证书，且描述文件有效期一年，已经解决“几天重装一次”的问题。

---

## 三、TestFlight 打包

项目已提供一键脚本：

```bash
cd /Volumes/MyData/【01工作资料】/【MyWork】/MyAPP/001_HJ/花计2046
chmod +x scripts/build-testflight.sh
./scripts/build-testflight.sh
```

脚本会优先读取本机 `Configs/Local.xcconfig` 中的 Supabase 信息；也可以通过环境变量覆盖：

```bash
export SUPABASE_URL="https://你的项目.supabase.co"
export SUPABASE_FUNCTIONS_URL="https://你的项目.functions.supabase.co/functions/v1"
export SUPABASE_ANON_KEY="你的匿名key"
```

`SUPABASE_*` 只作为构建参数注入，不会写入源码或 Git。缺失时脚本会直接报错，避免打出连不上后端的包。

脚本会：

1. 校验本机存在 `Apple Distribution` 签名身份。
2. 用 Release 配置生成 Archive。
3. 按 `scripts/ExportOptions/AppStore.plist` 导出 TestFlight IPA。

产物位置：

```text
Build/TestFlight/花计2046.xcarchive
Build/TestFlight/花计2046.ipa
```

上传方式二选一：

- Xcode → Window → Organizer → 选择 Archive → Distribute App → App Store Connect。
- 使用 Transporter 上传 `Build/TestFlight/花计2046.ipa`。

上传后在 App Store Connect 添加测试员，等构建处理完成即可在 TestFlight 安装。

---

## 四、Ad Hoc 打包

Ad Hoc 适合不通过 TestFlight、直接装到指定设备：

```bash
./scripts/build-adhoc.sh
```

脚本会按 `scripts/ExportOptions/AdHoc.plist` 导出 IPA：

```text
Build/AdHoc/花计2046.xcarchive
Build/AdHoc/花计2046.ipa
```

注意事项：

- 测试设备的 UDID 必须先在 Apple Developer 后台注册。
- 首次运行脚本用了 `-allowProvisioningDeviceRegistration`，Xcode 自动签名时会把已连接设备注册进 Ad Hoc Profile。
- 安装 IPA 可以用 Apple Configurator、Xcode Device 窗口或 MDM。

---

## 五、有效期说明

| 分发方式 | 签名有效期 | 是否需要频繁重装 |
|---|---|---|
| Debug 真机 | 通常 7 天（当前项目已用 365 天 Profile） | 一般不重复出现 |
| TestFlight | 按构建保留，签名有效期约 1 年 | 不需要 |
| Ad Hoc | 约 1 年 | 到期后重新导出 |
| App Store | 长期 | 不需要 |

Distribution 证书和描述文件到期后只需在 Xcode 重新下载/自动续签，不需要每 7 天重装一次。

---

## 六、一键修复后仍需人工确认的项

- 登录开发者账号并下载证书。
- App Store Connect 中创建 App 记录（Bundle ID：`com.nsoft.huaji2046`）。
- TestFlight 测试员账号。
- Ad Hoc 设备 UDID 注册。
- 上传前确认 `Configs/Release.xcconfig` 不含真实密钥，Supabase 密钥通过正式 Release 环境注入。
