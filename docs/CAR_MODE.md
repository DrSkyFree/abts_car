# 车机版 / 大屏适配说明

阿B听书为安卓**横屏车机**（车载中控屏、盒子、后视镜屏等）提供专门的构建版本，
解决车机环境下最常见的两类问题：

1. **车机状态栏是悬浮覆盖在应用之上的**，应用拿不到系统 inset，
   导致顶部/底部按钮被压在状态栏或手势条下面，点不到；
2. **车机屏幕物理尺寸小、观看距离远**，需要整体放大或缩小界面，
   或者加大上下留白来保证可点区域。

## 一、构建车机版

```bash
# 方式一：脚本（推荐）
./tool/build_car.sh            # release APK
./tool/build_car.sh --split    # 按 CPU 架构拆分
./tool/build_car.sh --debug    # debug 包快速验证

# 方式二：原生命令
flutter build apk --release --dart-define=ABTS_CAR=true
```

车机版与手机版的差异：

| 项目 | 手机版 | 车机版 |
| --- | --- | --- |
| 包名 | `dev.pages.abts` | `dev.pages.abts.car` |
| 应用名 | 阿B听书 | 阿B听书车机版 |
| 默认方向 | 跟随系统 | **锁定横屏** |
| 显示设置 | 可用，默认全默认 | 可用，默认开启分组 |
| 更新引导 | 检查 GitHub Releases | 关闭（包名不同无法覆盖安装） |

> 两个版本**包名不同，可同时安装在一台设备上**，互不覆盖、数据互不影响。
> 车机版不参与自动更新，需要更新时从仓库手动下载新的车机版 APK。

## 二、在设置里调边距与缩放

入口：**我的 → 系统设置 → 显示与缩放 →（或直接在设置页点「显示与缩放」）**

设置项改动**立即生效**并自动保存，下次启动保持不变。

### 1. 一键预设

| 预设 | 效果 | 适用 |
| --- | --- | --- |
| 避开状态栏 | 顶部留 48px、底部留 24px | 状态栏/手势条遮挡按钮 |
| 紧凑模式 | 缩放 85% | 一屏想多显示几本书 |
| 远距离放大 | 缩放 130% | 车机观看距离远、点按不准 |
| 恢复默认 | 全部还原 | 调乱了重来 |

### 2. 显示界面上下边距（0–100 px）

- **独立调节顶部和底部**，互不影响；
- 单位是**屏幕物理像素**（不是逻辑 dp），所以填 48 就是屏幕上真实的 48 像素留白，
  可以直接对照车机状态栏的截图高度来填，不用换算；
- 面板上会显示本机像素密度（如 `本机 1.50x`）作为参考。

调法：截图看按钮被压住的高度 → 往对应方向的边距填同样的像素数 → 拖滑块实时看效果。

### 3. 界面缩放（60%–160%）

- 滑块连续可调，或点 `70% / 85% / 100% / 115% / 130%` 快捷档；
- 缩小 → 同屏内容更多、网格列数可能增加；
- 放大 → 字体和按钮更大，车机远距离点按容错更高。

### 4. 方向与全屏

- **锁定横屏**：车机固定安装时打开，竖屏误触也不会转屏；
- **沉浸式全屏（隐藏状态栏）**：如果不需要看到系统状态栏，直接隐藏掉最省事，
  比手动留边距更彻底。两者可叠加使用。

## 三、实现要点（给二次开发者）

### 全局适配层

`lib/core/settings/display_adjust.dart` 挂在 `MaterialApp.builder` 上：

```dart
builder: (context, child) => DisplayAdjust(child: child ?? const SizedBox.shrink()),
```

结构是「**边距在外、缩放在内**」：

```
Padding(上/下边距，物理像素 → 逻辑像素)
└── SizedBox(外层尺寸 w×h)
    └── OverflowBox(紧约束 innerW×innerH)   ← 强制按缩小后的视口布局
        └── Transform.scale(scale)            ← 绘制时放大回 w×h
            └── MediaQuery(size: innerW×innerH, dpr: dpr×scale, inset÷scale)
                └── 整棵应用树
```

三个关键设计：

1. **边距不受缩放影响。** 边距在最外层，按物理像素换算成逻辑像素，
   用户填 48 就是稳定的 48px 留白，不会因为调了缩放而漂移。
2. **缩放用「缩小布局视口 + Transform 放大还原」，而不是单纯的 `Transform.scale`。**
   前者会同步缩小 `MediaQuery.size`，网格列数、间距会真正重排；
   且命中测试由 `RenderTransform` 自动逆变换，不会出现「按钮看着在那儿却点不到」
   的偏移——这对车机（触控精度差、屏幕小）是硬需求。
   `OverflowBox` 保证子节点拿到的是**缩放后视口的紧约束**（不会被外层约束裁掉），
   `Transform.scale` 再把绘制结果放大，两者相乘恰好还原成 `w×h`，既不变形也不溢出。
3. **MediaQuery 的换算方向容易搞反**，实测结论：
   - `devicePixelRatio` 要**乘** `scale`（1 内层逻辑像素 = `scale`×`dpr` 物理像素）；
   - `padding` / `viewPadding` / `viewInsets` / `viewInsetsPadding` /
     `systemGestureInsets` **全部是逻辑像素**（见 `MediaQueryData.fromView`
     里统一经 `EdgeInsets.fromViewPadding(..., devicePixelRatio)` 换算），
     内层要**除以** `scale`，否则 `SafeArea` 会双重留白。

### 配置存储

`lib/core/settings/display_prefs.dart`，单例 + `SharedPreferences`，
与项目里 `ThemeController` 同一套模式，键名前缀 `car_`：

| 键 | 含义 |
| --- | --- |
| `car_ui_scale` | 缩放系数（0.6–1.6） |
| `car_edge_top` / `car_edge_bottom` | 上下边距（物理 px，0–100） |
| `car_landscape_lock` | 锁定横屏 |
| `car_fullscreen` | 沉浸式全屏 |

Gradle 侧通过解码 `dart-defines` 判断车机构建，与 Dart 的
`bool.fromEnvironment('ABTS_CAR')` 保持同源，避免两边判断不一致。

## 四、注意事项

- 上下边距只影响应用**内容区**，播放页的弹层（`showModalBottomSheet`）、
  对话框会跟随 MediaQuery 一起缩放，所以边距同样生效。
- 缩放作用于整棵应用树，包括列表虚拟滚动的可见范围计算，不会破坏滚动性能。
- 若车机为**红外遥控/方向盘按键**操作（非触摸），缩放到 130% 以上、
  边距归零的操作体验通常最好。
- 车机多为定制 ROM，可能缺少 Google 服务；本应用不依赖 GMS，可正常运行。
