# 小词星 MVP 实施状态与后续步骤

更新时间：2026-09-07  
代码仓库：https://github.com/kanjiang/english_study  
Firebase 项目：`english-study-kanjiang`（显示名 `XiaoCiXing`）

## 1. 状态说明

- ✅ 已完成：已实现，并有自动化测试、构建结果或云端查询作为证据。
- 🟡 部分完成：主体已实现，但仍缺真实资源、真机或跨设备验证。
- ⬜ 未完成：尚未执行或尚未实现。
- ⛔ 外部条件：需要设备、macOS、发布证书、账单或人工账号操作。

## 2. 当前结论

- ✅ Flutter MVP 主体已经实现：登录/建档、三款游戏、金币、换装、家长 PIN、每日限额、离线缓存和时长锁均已有代码。
- ✅ Firebase 项目、Android/iOS App、Firestore 数据库、规则、邮箱登录和电话登录均已配置。
- ✅ Android Debug APK 已成功构建。
- 🟡 产品还不能视为“发布完成”：Android Firebase 签名登记、真机主路径、双设备同步、iOS 构建、发布签名和商店发布尚未完成。
- ✅ Firebase、Android/iOS 配置和 48 词资源已提交并推送到 GitHub。

## 3. 产品范围和设计

### 3.1 已确定的第一期范围

- ✅ 产品名：小词星。
- ✅ 目标年龄：3–8 岁；第一期界面和词库按 5–8 岁设计。
- ✅ 平台：Android + iOS。
- ✅ 技术：Flutter、Riverpod、Firebase Authentication、Cloud Firestore。
- ✅ 第一阶段闭环：记忆游戏 → 金币 → 角色换装 → 家长控制每日时长。
- ✅ 一个 Firebase 账号对应一个孩子档案。
- ✅ 每日限额：20/30/45/60 分钟，默认 30 分钟。
- ✅ 规格文档：`docs/superpowers/specs/2026-08-25-xiaocixing-mvp-design.md`。
- ✅ 实施计划：`docs/superpowers/plans/2026-08-25-xiaocixing-mvp.md`。

### 3.2 明确不在第一期的内容

- ⬜ 分级动画片、跟读和点读。
- ⬜ 完整宠物家园和家具摆放。
- ⬜ 一个家长账号管理多个孩子。
- ⬜ 微信登录、自建服务端和家长网页后台。
- ⬜ 服务端强防作弊。

## 4. 原实施计划 Task 1–14 状态

### Task 1：Flutter 工程和 TimeQuota

- ✅ Flutter Android/iOS 工程已创建。
- ✅ `TimeQuota` 支持每日限额、加时、计时、跨日重置和锁定。
- ✅ 上海时区初始化已实现。
- ✅ Android 最低版本为 API 26，iOS 最低版本为 13。
- ✅ 对应领域测试通过。

### Task 2：听音选图 / 看图选词 QuizEngine

- ✅ 10 题一局、4 个选项、答题后推进、不可重试。
- ✅ 答对 +3 金币，连续答对达到 3 后有额外金币。
- ✅ 错误答案不扣金币并清空连对。
- ✅ 完局边界和积分规则有单元测试。

### Task 3：翻牌配对 QuizEngine

- ✅ 6 对、12 张牌。
- ✅ 图与词配对成功得分。
- ✅ 不匹配时短暂停留后翻回，并在停留期间锁定输入。
- ✅ 第一张牌不会被错误判题或触发时长锁跳转。
- ✅ 对应单元和 Widget 测试通过。

### Task 4：Wallet 和 9 件换装

- ✅ 帽子、眼镜、衣服三个槽位，共 9 件商品。
- ✅ 支持购买、余额不足、重复购买、穿戴和脱下。
- ✅ 离线禁止购买且不扣金币。
- ✅ Wallet 集合防别名修改测试已覆盖。

### Task 5：PIN、用户快照、同步合并和本地缓存

- ✅ 6 位 PIN 校验。
- ✅ PIN 使用 `SHA-256(uid + pin)` 保存，不保存明文。
- ✅ 连续输错 5 次锁定 1 分钟。
- ✅ `UserSnapshot`、金币合并、时长合并和本地缓存已实现。
- ✅ 本地缓存恢复时取较高 `usedSeconds`，避免杀进程后减少已用时长。

### Task 6：UserRepository 和 Firestore 数据层

- ✅ UI 不直接依赖 Firestore。
- ✅ Fake 和 Firestore 两套仓库实现。
- ✅ `users/{uid}` 快照监听、保存、购买事务和待同步金币已实现。
- ✅ 登录状态变化后，Firestore 监听能在同一进程内自动接上。
- ✅ 前台计时只保存时长字段，不会用旧快照覆盖金币、PIN 或每日限额。

### Task 7：登录、注册、建档和 AuthGate

- ✅ 邮箱登录和注册界面已实现。
- ✅ 手机号验证码登录界面已实现。
- ✅ 首次建档支持孩子名、4 个头像和 6 位家长 PIN。
- ✅ `AuthGate` 管理登录 → 建档 → 首页，不再通过替换根路由破坏计时器。
- ✅ Firebase 邮箱/密码提供方已启用。
- ✅ Firebase 电话提供方已启用。
- ✅ 短信地区策略仅允许 `CN`。
- 🟡 邮箱与手机号真实登录尚未在 Android 真机验证。
- 🟡 手机号是否能在中国大陆稳定收到 Firebase 短信尚未验证，仍受网络、短信额度和 Firebase 政策影响。

### Task 8：首页、前台计时和时长锁

- ✅ 首页显示角色、金币和剩余分钟。
- ✅ 三个游戏入口和家长入口已实现。
- ✅ App 前台每秒计时，后台/暂停时停止并保存。
- ✅ 每 30 秒保存一次时长。
- ✅ 时间用完后显示指定锁屏文案。
- ✅ 登录后再出现用户快照时，计时器会继续工作。
- 🟡 “今天”仍按设备上的上海时区计算，不使用 Firestore 服务端时间；用户修改系统时间可能影响跨日判断。

### Task 9：48 词词库和音频接口

- ✅ 48 个词，动物/食物/颜色/家居各 12 个。
- ✅ 每个词有英文、中文、分类、图片路径和音频路径。
- ✅ `just_audio` 播放接口已接入。
- ✅ 48 个词已从 Material 图标切换为独立 PNG 图片资源：`assets/images/words/<word_id>.png`。
- ✅ 48 个词已从 `assets/audio/beep.mp3` 切换为独立 WAV 读音资源：`assets/audio/words/<word_id>.wav`。
- ✅ 图片和音频路径均按 `word.id` 派生，并有测试覆盖。
- 🟡 当前图片为 MVP 本地生成的儿童闪卡风格图，后续可继续替换为更精细的 AI/设计师插画。

### Task 10：三款游戏会话和中途锁

- ✅ 寻宝翻牌、消防员灭火、打怪兽三个主题页面已实现。
- ✅ 三款游戏共用 QuizEngine。
- ✅ 时间在题目中途用完时允许完成当前判题，然后进入时长锁。
- ✅ 每局金币入账和分数保存已有 Widget 测试。
- 🟡 反馈主要是基础 Widget 和 SnackBar，产品级角色动画、特效和音效尚未制作。

### Task 11：换装商店

- ✅ 在线购买、金币扣除、已拥有状态和立即穿戴已实现。
- ✅ 离线购买失败文案和金币不变已测试。
- 🟡 角色及服装使用基础图形，尚未替换为产品级美术资源。

### Task 12：家长区

- ✅ PIN 门禁、错误次数锁定、每日限额、加时和重置 PIN 界面已实现。
- ✅ 邮箱重新认证路径已实现。
- 🟡 修改手机号目前只更新 Firestore 档案，没有完成 Firebase `verifyPhoneNumber` 换绑流程。
- 🟡 手机账号的重新认证/忘记 PIN 流程仍未完整实现；当前重新认证主要支持邮箱密码。
- 🟡 PIN 错误次数锁定只保存在内存，重启 App 后会清空。

### Task 13：Firestore 规则和离线失败

- ✅ 默认 Firestore 数据库已创建。
- ✅ 区域：香港 `asia-east2`。
- ✅ 类型：Standard / Firestore Native。
- ✅ 规则已编译并成功部署。
- ✅ 规则只允许登录用户读写自己的 `users/{uid}`。
- ✅ 上报失败时保留本地已用秒数。
- 🟡 当前客户端仍可写自己的金币和时长，不能抵御篡改客户端；这是 MVP 已接受的限制。

### Task 14：手工验收

- ✅ 自动化层面：80 项 Flutter 测试通过。
- ✅ 静态检查：`flutter analyze` 无问题。
- ✅ Android Debug APK 构建成功。
- ⬜ Android 真机完整主路径。
- ⬜ 邮箱注册、退出、再次登录。
- ⬜ 手机号真实短信注册和登录。
- ⬜ 建档后三款游戏各完整玩一局。
- ⬜ 金币购买、穿戴、退出 App 后恢复。
- ⬜ 调低限额直到锁屏，再由家长加时解锁。
- ⬜ 飞行模式玩到锁、恢复网络后同步。
- ⬜ 两台设备远程修改限额并观察秒级更新。
- ⬜ iOS 真机完整主路径。

## 5. Firebase 云端状态

### 5.1 项目和移动应用

- ✅ 项目 ID：`english-study-kanjiang`。
- ✅ 项目编号：`130607768761`。
- ✅ Android App ID：`1:130607768761:android:ce0f9b8f3addce2dbaa768`。
- ✅ Android 包名：`com.xiaocixing.english_app`。
- ✅ iOS App ID：`1:130607768761:ios:9e507870df967183baa768`。
- ✅ iOS Bundle ID：`com.xiaocixing.englishApp`。
- ✅ Android 配置：`android/app/google-services.json`。
- ✅ iOS 配置：`ios/Runner/GoogleService-Info.plist`。
- ✅ Dart 配置：`lib/firebase_options.dart`。
- ✅ iOS plist 已加入 Runner 的 Xcode Resources。
- ✅ Android Google Services Gradle 插件已加入。
- ✅ App 启动时会等待真实 Firebase 初始化，不再吞掉配置错误。

### 5.2 Authentication

- ✅ Identity Toolkit API 已启用。
- ✅ 邮箱/密码：`enabled=true`、`passwordRequired=true`。
- ✅ 电话：`enabled=true`。
- ✅ 短信地区白名单：仅 `CN`。
- ⬜ Android SHA-1 尚未登记到 Firebase。
- ⬜ Android SHA-256 尚未登记到 Firebase。
- ⬜ 登记 SHA 后重新下载 `google-services.json`。
- ⬜ Android 手机号登录真实短信验证。
- ⬜ iOS Phone Auth 所需 APNs、推送能力和回退验证配置。

### 5.3 Firestore

- ✅ `(default)` 数据库已创建。
- ✅ 数据库区域为 `asia-east2`。
- ✅ `firebase.json` 和 `.firebaserc` 已创建。
- ✅ `firebase/firestore.rules` 已部署。
- ⬜ 在真机上创建首个 `users/{uid}` 文档并验证实时监听。
- ⬜ 双设备同步验证。

## 6. Android 工具链和构建

- ✅ Flutter `3.47.1`、Dart `3.13.1`。
- ✅ Android CLI 已安装。
- ✅ Android SDK 路径：`C:\Users\kanjiang\AppData\Local\Android\Sdk`。
- ✅ Android Platform 34、35、36 已安装。
- ✅ Build Tools 36.0.0、Platform Tools 37.0.1、CMake 3.22.1 已安装。
- ✅ NDK `28.2.13676358` 已安装并用官方 SHA-1 校验。
- ✅ 便携 OpenJDK 17 已安装。
- ✅ `JAVA_HOME` 和 `ANDROID_HOME` 已写入当前用户环境变量。
- ✅ Gradle 分发包改用腾讯镜像，避免官方地址在当前网络下长时间阻塞。
- ✅ Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`。
- ✅ APK 大小：163,585,657 字节，约 156 MiB。
- ✅ 调试 SHA-1：`7B:52:27:50:D7:B4:96:25:ED:B2:09:F4:FB:96:4D:41:0D:78:06:6A`。
- ✅ 调试 SHA-256：`3B:96:6F:E3:58:17:A0:2A:EA:F6:6C:4C:85:19:73:F9:13:1F:53:7C:EE:A3:2E:75:93:5A:98:B1:9C:78:DC:89`。
- 🟡 `flutter doctor` 因新版 Android CLI 仍显示“Android license status unknown”，但实际 SDK 安装和 APK 构建已经成功。
- ⬜ Firebase 登记调试 SHA-1/SHA-256。
- ⬜ 连接 Android 真机或创建模拟器。
- ⬜ 安装 APK 并执行冒烟测试。
- ⬜ 创建正式 release keystore。
- ⬜ 将正式 SHA-1/SHA-256 登记到 Firebase。
- ⬜ 用安全方式配置 release 签名；当前 release 仍使用 debug 签名。
- ⬜ 构建 AAB 并准备 Google Play 发布资料。

## 7. iOS 工具链和构建

- ✅ iOS 工程和 Firebase App 已配置。
- ✅ 最低版本为 iOS 13。
- ✅ `GoogleService-Info.plist` 已加入 Xcode 工程资源。
- ⛔ 当前为 Windows 环境，无法执行 Xcode 构建、签名或真机测试。
- ⬜ 在 macOS 安装 Xcode、Flutter 和 CocoaPods/Swift Package 依赖。
- ⬜ 配置 Apple Developer Team 和正式 Bundle 签名。
- ⬜ 为 Phone Auth 配置 APNs Key、Push Notifications 和 Background Modes。
- ⬜ 构建并运行 iOS Debug 版本。
- ⬜ 执行 iOS 主路径验收。
- ⬜ Archive、TestFlight 和 App Store 发布。

## 8. 自动化验证记录

- ✅ `flutter analyze`：No issues found。
- ✅ `flutter test`：80 tests passed。
- ✅ Word assets：48 个 PNG 图片和 48 个 WAV 音频文件均已生成并登记。
- ✅ Firestore rules：编译和部署成功。
- ✅ Firebase 管理接口：邮箱和电话提供方均为 enabled。
- ✅ Firebase 客户端邮箱接口：返回 `WEAK_PASSWORD`，证明认证配置已生效；测试请求未创建用户。
- ✅ `flutter build apk --debug`：成功。
- 🟡 目前自动化测试主要使用 Fake Repository；没有连接真实 Firebase Emulator Suite 或生产 Firebase 的集成测试。

## 9. Git 和文件状态

- ✅ 当前分支：`master`。
- ✅ 本地分支跟踪：`origin/master`。
- ✅ GitHub 上最后已推送提交：`164a90d feat: complete MVP Firebase setup and word assets`。
- ✅ Firebase/Android/iOS 配置、48 词图片音频资源和相关状态文档已提交并推送。
- ℹ️ Firebase 移动端 API Key 通常属于客户端公开配置，可以提交；仍应在 Google Cloud 中按包名、Bundle ID 和 API 范围限制 Key。

## 10. 下一步执行顺序

### 第一优先级：完成 Android Firebase 身份校验

- ⬜ 1. 将调试 SHA-1 登记到 Android Firebase App。
- ⬜ 2. 将调试 SHA-256 登记到 Android Firebase App。
- ⬜ 3. 重新下载 `google-services.json`。
- ⬜ 4. 再构建一次 Debug APK。
- ⬜ 5. 连接 Android 真机并安装 APK。

### 第二优先级：真实 Firebase 冒烟测试

- ⬜ 6. 邮箱注册并创建孩子档案。
- ⬜ 7. 确认 Firestore 出现对应 `users/{uid}`。
- ⬜ 8. 退出并重新登录，确认档案恢复。
- ⬜ 9. 用中国手机号请求验证码并完成登录。
- ⬜ 10. 如果短信失败，检查 Firebase Usage、短信配额、账单、地区政策、Play Integrity 和网络可达性。

### 第三优先级：完整产品路径

- ⬜ 11. 玩完三种游戏并核对金币和分数。
- ⬜ 12. 购买并穿戴商品，杀进程后确认恢复。
- ⬜ 13. 把每日限额调整到已用时长以下，确认立即锁定。
- ⬜ 14. 家长加时 10 分钟，确认立即解锁。
- ⬜ 15. 飞行模式计时并恢复网络，核对已用时长不倒退。
- ⬜ 16. 两台设备登录同一账号，验证远程限额同步。

### 第四优先级：内容和产品质量

- ✅ 17. 替换 48 个词的 beep 占位音频。
- ✅ 18. 替换 Material 图标为儿童闪卡图片。
- ⬜ 19. 增加游戏成功/失败动画和音效。
- ⬜ 20. 完成手机账号重新认证、手机号换绑和忘记 PIN 流程。
- ⬜ 21. 评估服务端时间和基础反作弊方案。

### 第五优先级：版本控制和发布

- ✅ 22. 复查配置 diff，提交 Firebase/Android 集成改动。
- ✅ 23. 推送 `master` 到 GitHub。
- ⬜ 24. 配置 Android release keystore 和正式 Firebase SHA。
- ⬜ 25. 构建 AAB 并进行内部测试。
- ⬜ 26. 在 macOS 完成 iOS 构建、签名和 TestFlight。

## 11. 当前不能声称已完成的事项

- 不能声称 48 个词图已经达到最终美术品质；当前为 MVP 本地生成闪卡图，可继续精修。
- 不能声称手机号短信登录已经真机可用。
- 不能声称双设备家长控制已经在真实 Firebase 上验收。
- 不能声称 iOS 可以构建或已验收。
- 不能声称应用具有生产级防作弊。
- 不能声称 Android/iOS 已配置正式发布签名。
