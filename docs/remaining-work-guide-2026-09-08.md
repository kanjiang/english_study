# 小词星剩余工作执行 Guide

更新时间：2026-09-08

本文档用于继续推进小词星 MVP 发布前剩余事项。当前代码、Firebase 配置、48 词图片音频、游戏反馈音效、基础本地防作弊均已提交到 `master` 并推送到 GitHub。

## 0. 当前基线

- 仓库：`https://github.com/kanjiang/english_study`
- 当前分支：`master`
- Firebase 项目：`english-study-kanjiang`
- Android 包名：`com.xiaocixing.english_app`
- iOS Bundle ID：`com.xiaocixing.englishApp`
- Android Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`
- 调试 SHA-1：`7B:52:27:50:D7:B4:96:25:ED:B2:09:F4:FB:96:4D:41:0D:78:06:6A`
- 调试 SHA-256：`3B:96:6F:E3:58:17:A0:2A:EA:F6:6C:4C:85:19:73:F9:13:1F:53:7C:EE:A3:2E:75:93:5A:98:B1:9C:78:DC:89`
- 最近本地验证：
  - `flutter test`：82 tests passed
  - `flutter analyze`：No issues found
  - `flutter build apk --debug`：成功

## 1. Android Firebase SHA 登记

目的：让 Android App 可以稳定使用 Firebase Auth，尤其是 Phone Auth、Google Play Integrity 或后续涉及签名校验的能力。

执行位置：Firebase Console。

步骤：

- [ ] 打开 Firebase Console。
- [ ] 进入项目 `english-study-kanjiang`。
- [ ] 进入 Project settings。
- [ ] 找到 Android App：`com.xiaocixing.english_app`。
- [ ] 添加调试 SHA-1：
  - `7B:52:27:50:D7:B4:96:25:ED:B2:09:F4:FB:96:4D:41:0D:78:06:6A`
- [ ] 添加调试 SHA-256：
  - `3B:96:6F:E3:58:17:A0:2A:EA:F6:6C:4C:85:19:73:F9:13:1F:53:7C:EE:A3:2E:75:93:5A:98:B1:9C:78:DC:89`
- [ ] 下载更新后的 `google-services.json`。
- [ ] 替换本地文件：`android/app/google-services.json`。
- [ ] 运行：

```powershell
flutter clean
flutter pub get
flutter build apk --debug
flutter test
flutter analyze
```

完成标准：

- [ ] 构建成功生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- [ ] `flutter test` 全部通过。
- [ ] `flutter analyze` 无问题。
- [ ] 更新后的 `android/app/google-services.json` 已提交并推送。

## 2. Android 真机或模拟器安装验收

目的：验证 App 在真实 Android 环境可以启动、登录、建档、读写 Firebase、播放音频和加载图片。

准备：

- [ ] 连接 Android 真机并开启 USB 调试，或创建 Android 模拟器。
- [ ] 确认设备能访问 Firebase 和 Google 服务。
- [ ] 确认设备音量正常。

命令：

```powershell
flutter devices
flutter install --debug
```

手工验收：

- [ ] App 能正常启动，不停在白屏或 Firebase 初始化错误。
- [ ] 进入登录页。
- [ ] 用邮箱注册新账号。
- [ ] 创建孩子档案，设置 6 位家长 PIN。
- [ ] 首页显示孩子名、金币、剩余分钟和三个游戏入口。
- [ ] 三款游戏都能打开。
- [ ] 词图能显示。
- [ ] 听音选图能播放单词读音。
- [ ] 答对/答错有动画反馈和音效。
- [ ] 玩完一局后金币增加。
- [ ] 关闭并重新打开 App 后，档案、金币、时长仍能恢复。

完成标准：

- [ ] Android 主路径无阻断问题。
- [ ] 发现的问题记录到 issue 或状态文档。

## 3. 真实 Firebase 冒烟测试

目的：确认 Firebase Auth、Firestore 写入、监听和离线缓存不是只在 Fake Repository 测试中可用。

邮箱账号路径：

- [ ] 用邮箱注册。
- [ ] 创建孩子档案。
- [ ] 打开 Firestore Console。
- [ ] 确认出现 `users/{uid}` 文档。
- [ ] 确认文档包含孩子档案、钱包、时长、统计等字段。
- [ ] 退出登录。
- [ ] 重新登录同一邮箱。
- [ ] 确认档案恢复。
- [ ] 玩一局游戏。
- [ ] 确认金币和分数写回 Firestore。

离线路径：

- [ ] 登录并进入首页。
- [ ] 打开飞行模式。
- [ ] 玩游戏或停留计时。
- [ ] 恢复网络。
- [ ] 确认本地已用时长不会倒退。
- [ ] 确认金币待同步后能写回。

手机号路径：

- [ ] 用中国手机号请求验证码。
- [ ] 输入验证码完成登录。
- [ ] 创建孩子档案。
- [ ] 如果短信失败，检查 Firebase Usage、短信配额、账单、短信地区策略、Play Integrity 和网络可达性。

完成标准：

- [ ] 邮箱真实注册/登录通过。
- [ ] Firestore `users/{uid}` 创建和更新通过。
- [ ] 离线后恢复网络的数据合并通过。
- [ ] 手机号登录结果明确记录：通过，或记录具体失败原因。

## 4. 完整产品路径验收

目的：确认小朋友和家长的核心 MVP 闭环完整。

游戏路径：

- [ ] 寻宝翻牌完整玩一局。
- [ ] 消防员灭火完整玩一局。
- [ ] 打怪兽完整玩一局。
- [ ] 核对每局结束后的金币变化。
- [ ] 核对最近分数展示或保存结果。
- [ ] 验证答对/答错反馈不会卡住下一题。

商店路径：

- [ ] 用金币购买帽子。
- [ ] 穿戴帽子。
- [ ] 购买眼镜。
- [ ] 穿戴眼镜。
- [ ] 购买衣服。
- [ ] 穿戴衣服。
- [ ] 退出 App 后重新打开。
- [ ] 确认已拥有商品和穿戴状态恢复。

时长锁路径：

- [ ] 在家长区把每日限额调低到已用时长以下。
- [ ] 确认首页立即进入时长锁。
- [ ] 家长输入 PIN。
- [ ] 加时 10 分钟。
- [ ] 确认立即解锁。
- [ ] 再进入游戏，确认可以继续玩。

完成标准：

- [ ] 小朋友主路径可连续完成。
- [ ] 家长控制主路径可连续完成。
- [ ] 关键状态杀进程后仍能恢复。

## 5. 双设备同步验收

目的：验证一个账号在两台设备上的远程同步表现。

准备：

- [ ] 两台 Android 设备，或一台真机加一台模拟器。
- [ ] 两台设备登录同一个 Firebase 账号。

步骤：

- [ ] 设备 A 修改每日限额。
- [ ] 设备 B 观察限额是否更新。
- [ ] 设备 A 玩游戏获得金币。
- [ ] 设备 B 观察金币是否更新。
- [ ] 设备 B 加时 10 分钟。
- [ ] 设备 A 观察锁屏状态是否解除。
- [ ] 设备 A 离线玩一段时间。
- [ ] 设备 B 在线修改限额。
- [ ] 设备 A 恢复网络后确认合并结果合理。

完成标准：

- [ ] 远程监听可用。
- [ ] 金币合并不丢失。
- [ ] 已用时长不倒退。
- [ ] 家长限额变更不会被旧本地快照覆盖。

## 6. 手机账号和家长区认证补强

目的：补齐手机号账号下的重新认证、手机号换绑和忘记 PIN 体验。

当前状态：

- 邮箱密码账号的重新认证路径已有基础实现。
- 手机号登录本身已接入 Firebase Phone Auth。
- 家长 PIN 的忘记/重置页面已有基础 UI。
- 手机号账号下的重新认证、手机号换绑和忘记 PIN 仍需要真实短信验证闭环。

建议实现顺序：

- [ ] 抽象 `ParentReauthService`，让邮箱密码和短信验证码重新认证都走同一接口。
- [ ] 为邮箱账号保留当前密码重新认证。
- [ ] 为手机号账号增加“发送验证码”按钮。
- [ ] 保存 `verificationId`，输入短信验证码后创建 `PhoneAuthCredential`。
- [ ] 用 `reauthenticateWithCredential` 完成手机号账号重新认证。
- [ ] 修改手机号时，先验证新手机号，再调用 Firebase Auth 的手机号更新能力。
- [ ] Firestore 档案中的 `phone` 字段只在 Firebase Auth 更新成功后保存。
- [ ] 忘记 PIN 时，邮箱账号用密码重新认证，手机号账号用短信重新认证。
- [ ] 增加 Fake Service 的 Widget 测试，覆盖邮箱成功、手机号成功、验证码失败、空验证码等路径。

完成标准：

- [ ] 不再出现“手机号用户只能失败”的重新认证路径。
- [ ] 手机号换绑不会只改 Firestore 而不改 Firebase Auth。
- [ ] 忘记 PIN 对邮箱账号和手机号账号都有明确流程。
- [ ] 真机短信可用后完成端到端验收。

## 7. 服务端时间和反作弊

目的：降低用户通过改系统时间、篡改客户端或离线状态获得异常收益的风险。

当前状态：

- 已有本地保护：设备日期早于已记录日期时，不会把已用时长重置到过去日期。
- 本地缓存恢复时取更高的 `usedSeconds`。
- Firestore 规则限制用户只能读写自己的 `users/{uid}`。
- MVP 仍允许客户端写自己的金币和时长，不能抵御篡改客户端。

建议后续：

- [ ] 在 Firestore 文档中增加 `lastServerSeenAt`。
- [ ] 关键保存时写入 `FieldValue.serverTimestamp()`。
- [ ] 客户端加载快照时比较设备时间和服务端时间差。
- [ ] 如果时间差异常，提示家长校准系统时间，不直接跨日重置。
- [ ] 金币奖励保留本地体验，但增加基础异常检测。
- [ ] 后续如要强防作弊，把发金币逻辑迁移到 Cloud Functions。

完成标准：

- [ ] 设备回拨不会导致时长清零。
- [ ] 服务端时间字段可用于识别明显异常。
- [ ] 发布说明中明确 MVP 不是强防作弊架构。

## 8. Android Release 准备

目的：准备 Google Play 或内部测试所需的正式包。

步骤：

- [ ] 创建 Android release keystore。
- [ ] 将 keystore 放在安全位置，不提交到 Git。
- [ ] 用 `key.properties` 或环境变量配置签名。
- [ ] 将 `key.properties` 加入 `.gitignore`。
- [ ] 获取 release SHA-1 和 SHA-256。
- [ ] 在 Firebase Android App 中登记 release SHA。
- [ ] 下载更新后的 `google-services.json`。
- [ ] 构建 AAB：

```powershell
flutter build appbundle --release
```

验收：

- [ ] AAB 构建成功。
- [ ] 安装内部测试包后能登录、建档、玩游戏。
- [ ] Phone Auth 在 release 签名下可用。

## 9. iOS 准备

目的：在 macOS 上完成 iOS 构建、签名、Phone Auth 配置和 TestFlight。

当前限制：

- 当前开发环境是 Windows，不能执行 Xcode 构建、签名或 iOS 真机测试。

macOS 步骤：

- [ ] 安装 Xcode。
- [ ] 安装 Flutter。
- [ ] 拉取 GitHub 仓库。
- [ ] 运行 `flutter doctor`。
- [ ] 配置 Apple Developer Team。
- [ ] 确认 Bundle ID：`com.xiaocixing.englishApp`。
- [ ] 确认 `ios/Runner/GoogleService-Info.plist` 已加入 Runner Resources。
- [ ] 为 Firebase Phone Auth 配置 APNs Key。
- [ ] 配置 Push Notifications 和必要的 Background Modes。
- [ ] 运行：

```bash
flutter pub get
flutter build ios --debug
```

- [ ] 连接 iPhone 真机运行。
- [ ] 执行 iOS 主路径验收。
- [ ] Archive。
- [ ] 上传 TestFlight。

完成标准：

- [ ] iOS Debug 真机可运行。
- [ ] iOS 登录、建档、游戏、家长区可用。
- [ ] TestFlight 构建可安装。

## 10. 内容和美术精修

目的：提升发布观感，但不阻塞 MVP 功能验收。

当前状态：

- 48 个词已有独立 PNG 图片。
- 48 个词已有独立 WAV 读音。
- 当前词图是 MVP 本地生成闪卡图，不是最终美术品质。

后续：

- [ ] 按 4 个分类统一精修画风：动物、食物、颜色、家居。
- [ ] 图片保持 1:1、无文字、主体居中、儿童教育风格。
- [ ] 替换时保持原文件名不变：`assets/images/words/<word_id>.png`。
- [ ] 替换后运行 `flutter test`、`flutter analyze`、`flutter build apk --debug`。
- [ ] 抽查三款游戏中的显示效果。
- [ ] 检查 APK/AAB 大小是否可接受。

## 11. 每次改动后的标准验证

每轮代码或配置变更完成后，至少运行：

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

资源变更后额外检查：

```powershell
(Get-ChildItem "assets\images\words\*.png" | Measure-Object).Count
(Get-ChildItem "assets\audio\words\*.wav" | Measure-Object).Count
(Get-ChildItem "assets\audio\sfx\*.wav" | Measure-Object).Count
```

期望结果：

- 词图 PNG：48
- 单词 WAV：48
- 音效 WAV：2

## 12. 当前剩余事项总览

仍未完成：

- [ ] Android Firebase 调试 SHA 登记。
- [ ] 更新登记 SHA 后的 `google-services.json`。
- [ ] Android 真机或模拟器安装验收。
- [ ] 邮箱真实注册、登录、退出、恢复档案验收。
- [ ] 中国手机号真实短信登录验收。
- [ ] Firestore 真实文档创建和更新验收。
- [ ] 三款游戏完整主路径手工验收。
- [ ] 商店购买、穿戴、重启恢复手工验收。
- [ ] 家长区限额、锁屏、加时手工验收。
- [ ] 双设备同步验收。
- [ ] 手机号账号重新认证、手机号换绑和忘记 PIN 完整实现与真机验证。
- [ ] 服务端时间字段和更强反作弊方案。
- [ ] Android release keystore、release SHA、AAB 和内部测试。
- [ ] iOS macOS 构建、签名、真机和 TestFlight。
- [ ] 48 词图片后续美术精修。
