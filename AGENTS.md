# 阿B听书 Car · 开发交接说明

面向后续开发（包括 AI 协作）的项目约定。**这是独立仓库**，与手机/TV/桌面版无关。

## 项目定位

车机专用 Android 播放器：只适配车载中控，不提供 TV（Android TV）与 Windows 桌面端。

- 包名 `dev.pages.abts`，签名固定（`android/abts-release.keystore.b64`），**不要改 applicationId**，否则车机上无法覆盖升级
- 桌面显示名固定为「阿B听书」
- 最低 Android 7.0（API 24），适配 12~18 寸、720P~2.5K 横屏

## 工具链版本（勿随意升级）

| 项 | 版本 | 说明 |
|---|---|---|
| Flutter | 3.44.9（CI 固定） | `channel: stable` 会拉到 3.50+，要求 Gradle ≥9.3.1 导致构建失败 |
| Gradle / AGP / Kotlin | 8.14 / 8.11.1 / 2.2.20 | 与 Flutter 3.44.9 匹配 |
| compileSdk / targetSdk / minSdk | 由 Flutter 默认 / 36 / **24** | minSdk 固定 24 |

CI 会执行 `flutter analyze`（阻断）与 `flutter test`，提交前务必让两者通过。

## 显示系统（车机适配核心）

- `lib/core/theme/display_settings.dart`：单例 `DisplaySettings.instance`，保存「使用设备（车机竖屏 / 车机横屏）/ 界面缩放 / 字号 / 封面系数 / 四周边距」，落 SharedPreferences
- `lib/core/theme/display_frame.dart`：`MaterialApp.builder` 里的全局面板，用「缩小逻辑视口 + 等比放大」实现整体缩放，并按百分比补顶部留白
- `lib/core/theme/wide_mode.dart`：宽屏/遥控设备判定（`useWideLayout`、`isLeanback`、`textScalerFor`）
- 相关页面：`pages/theme_page.dart`（外观模式）、`pages/display_tuning_page.dart`（缩放与边距）

**布局约定**：涉及文字/按钮的固定高度都要能被字号撑开（用 `minHeight` / 自适应），否则 `字号 200%` 会裁字。搜索框曾因固定 46dp 出现裁字，已改为 `minHeight`。

## 构建与发布

推送 `main` 即触发 GitHub Actions（`.github/workflows/android-release.yml`）：

1. `flutter analyze` → `flutter test` → 构建 4 个 APK（split-per-abi + universal）
2. 重命名为 `abts_car-v{版本}-{abi}.apk`
3. 发布 Release，**历史 Release 全部保留**：每个版本的「本次更新」就是该版本的更新日志（README 不再维护更新日志）
4. 版本号来源：`pubspec.yaml` 的 `version`，需与 `lib/core/app_meta.dart` 的 `version` 保持一致（「检查更新」依赖它）

发布前流程：改版本 → 在工作流 `Publish GitHub Release` 的 body 里写好本次更新 → commit → push → 等 CI → 装模拟器验证。

## 本地验证环境

| 项 | 路径 / 值 |
|---|---|
| Android SDK | `D:\AppData\DevEnv\android-sdk` |
| AVD | `car720p`（1920×720 / density 160，Android 11 / API 30，x86_64） |
| 启动 | `emulator -avd car720p -gpu host`（无界面加 `-no-window`） |
| 安装 | `adb install -r abts_car-v{版本}-x86_64.apk` |
| 截图 | `adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png .` |

环境变量已写入用户作用域：`ANDROID_HOME`、`ANDROID_SDK_ROOT`、`ANDROID_USER_HOME`、`ANDROID_AVD_HOME`，PATH 含 `platform-tools`、`emulator`、`cmdline-tools/latest/bin`。

**精确改显示参数**（滑块难以对齐目标值）：`adb root` 后编辑
`/data/data/dev.pages.abts/shared_prefs/FlutterSharedPreferences.xml`，
double 值形如 `VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu` + `1.3`（该前缀是 Flutter 的 Double 标记），改完 `chown` 回应用 uid（`stat -c %u`）并 `chmod 660`。

## 代码结构

```
lib/core/      网络（WBI 签名/限速）、存储（书架/缓存/关注）、主题与显示设置
lib/pages/     书架 / 发现 / 搜索 / 详情 / 播放 / 我的 / 外观模式 / 缩放与边距 …
lib/widgets/   亚克力面板、书籍卡片、焦点环、字母键盘、页面骨架
lib/player/    BookPlayer（连播、断点续播、音频焦点、睡眠定时）
android/.../MainActivity.kt  音频焦点、设备形态、全屏、完全退出、缓存通知、重启等原生通道
test/          车机布局与显示设置单测（含 1920×720 视口断言）
```

## 约定

- 提交信息用中文，作者 `DrSkyFree <93423275+DrSkyFree@users.noreply.github.com>`
- 不引入体积大的识别/离线模型类依赖（APK 已 27~76MB）
- 不新增 TV/Windows 相关代码或配置
- 不提供任何对外分享入口（播放页分享按钮与 `share_plus` 依赖已移除，勿重新引入）
- 全屏只用窗口级 `FLAG_FULLSCREEN` + `LAYOUT_STABLE | LAYOUT_FULLSCREEN`（对齐百度地图），**不要**再加 `FLAG_LAYOUT_NO_LIMITS` 或沉浸式 `SYSTEM_UI_FLAG_HIDE_*`，否则部分车机自绘状态栏无法隐藏
- 车机交互优先：按钮可点面积、字号可读性、主驾在左的操作布局
