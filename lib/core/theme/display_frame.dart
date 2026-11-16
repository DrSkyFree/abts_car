import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'display_settings.dart';
import 'wide_mode.dart';

/// 全局面板：把「字号缩放 / 界面缩放 / 四周边距」套到整棵组件树。
///
/// 车机中控的状态栏是系统覆盖层，应用拿到的 `MediaQuery.padding` 往往为 0，
/// 内容会被顶栏压住；这里用占屏幕百分比的边距留出安全区。界面缩放采用
/// 「缩小逻辑视口 + 等比放大绘制」的方式（与系统显示大小调节一致），
/// 所以字体、按钮、列表、封面一起等比变化，且文字仍是矢量绘制不会糊。
class DisplayFrame extends StatelessWidget {
  final Widget child;
  const DisplayFrame({super.key, required this.child});

  /// 当前屏幕下内容实际可用的逻辑尺寸（扣除四周边距后按缩放系数换算）。
  /// 单独抽出来是为了便于测试与调试。
  static Size logicalSizeFor(Size physical) {
    final ds = DisplaySettings.instance;
    final insets = ds.insetsFor(physical);
    final availW = (physical.width - insets.horizontal).clamp(1.0, physical.width);
    final availH = (physical.height - insets.vertical).clamp(1.0, physical.height);
    return Size(availW / ds.scale, availH / ds.scale);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ds = DisplaySettings.instance;
    final wide = WideMode.useWideLayout(context);
    // 宽屏无触摸设备的字号补偿（车机走自己的字号设置，避免与之叠加）
    final leanbackScaler = WideMode.textScalerFor(context);
    final textScaler = TextScaler.linear(
      (leanbackScaler?.scale(1.0) ?? mq.textScaler.scale(1.0)) * ds.textScale,
    );

    // 没有 AppBar 的宽屏页面也要保证状态栏图标与主题明暗一致
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
        : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    final insets = ds.insetsFor(mq.size);
    final hasInsets = insets.top > 0 ||
        insets.bottom > 0 ||
        insets.left > 0 ||
        insets.right > 0;
    final zoom = ds.scale;

    // 系统上报的内边距是外层物理尺寸，换算到缩放后的逻辑坐标系；
    // 车机拿不到状态栏留白（padding 为 0），由用户设置的边距补足。
    EdgeInsets scaled(EdgeInsets e) => EdgeInsets.fromLTRB(
          e.left / zoom,
          e.top / zoom,
          e.right / zoom,
          e.bottom / zoom,
        );

    MediaQueryData base() => mq.copyWith(
          textScaler: textScaler,
          navigationMode: wide ? NavigationMode.directional : mq.navigationMode,
        );

    Widget content;
    if (hasInsets || zoom != 1.0) {
      final availW =
          (mq.size.width - insets.horizontal).clamp(1.0, mq.size.width);
      final availH =
          (mq.size.height - insets.vertical).clamp(1.0, mq.size.height);
      final logical = Size(availW / zoom, availH / zoom);
      content = Padding(
        padding: insets,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: logical.width,
              height: logical.height,
              child: MediaQuery(
                data: base().copyWith(
                  size: logical,
                  padding: scaled(mq.padding),
                  viewPadding: scaled(mq.viewPadding),
                  viewInsets: scaled(mq.viewInsets),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    } else {
      content = MediaQuery(data: base(), child: child);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: content,
    );
  }
}
