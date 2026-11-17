import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'display_settings.dart';

/// 宽屏 / 遥控操作设备的判定与显示补偿。
///
/// 车机中控常见「宽屏 + 无触摸或仅旋钮操作」的形态：判定优先走原生探测
/// （leanback 特性或无触摸屏 + 方向键，见 MainActivity 的 `abts/device` 通道），
/// 失败时回退到「方向键导航 + 大屏」启发式。
/// 这类设备常见 1920x720 ~ 2560x1440 逻辑分辨率，默认字号偏小，这里统一加
/// 一次温和的字号补偿；触摸车机则由「屏幕缩放与边距调整」里的字号设置精确控制。
class WideMode {
  WideMode._();

  static const _channel = MethodChannel('abts/device');

  static bool? _native;

  /// 原生探测是否为遥控 / 无触摸宽屏设备；启动时调用一次，异常静默回退启发式。
  static Future<void> detect() async {
    if (!Platform.isAndroid) {
      _native = false;
      return;
    }
    try {
      final r = await _channel
          .invokeMethod<bool>('isLeanback')
          .timeout(const Duration(seconds: 2));
      _native = r ?? false;
    } catch (_) {
      _native = false;
    }
  }

  /// 是否按遥控 / 无触摸宽屏设备对待（焦点描边、大屏布局）。
  static bool isLeanback(BuildContext context) {
    final native = _native;
    if (native != null) return native;
    // 原生结果未就绪时的兜底：上报方向键导航且达到宽屏基准尺寸
    if (!Platform.isAndroid) return false;
    final mq = MediaQuery.of(context);
    return mq.navigationMode == NavigationMode.directional &&
        mq.size.shortestSide >= 540;
  }

  /// 是否采用「宽屏形态」：车机/平板（短边 ≥ 600dp），或手机横屏
  /// （宽 ≥ 640dp 且横向）。主框架据此把底部导航换成左侧栏，播放页/详情页
  /// 据此切左右分栏；与方向键导航模式共用同一口径（见 main.dart）。
  static bool useWideLayout(BuildContext context) {
    // 车机：中控一律按宽屏侧栏布局（方向键/触屏都够用）
    if (DisplaySettings.instance.isCar) return true;
    if (isLeanback(context)) return true;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide >= 600) return true;
    return size.width > size.height && size.width >= 640;
  }

  /// 无触摸宽屏设备的字号补偿（触摸车机返回 null，交给字号设置处理）。
  ///
  /// 车机不在这里放大：车机字号由「屏幕缩放与边距调整」里的字号设置控制，
  /// 两处叠加会把字放得过大。
  static TextScaler? textScalerFor(BuildContext context) {
    if (DisplaySettings.instance.isCar) return null;
    if (!isLeanback(context)) return null;
    final mq = MediaQuery.of(context);
    final base = mq.textScaler.scale(1.0);
    final factor = mq.devicePixelRatio < 1.4 ? 1.3 : 1.15;
    return TextScaler.linear((base * factor).clamp(1.0, 2.0));
  }
}
