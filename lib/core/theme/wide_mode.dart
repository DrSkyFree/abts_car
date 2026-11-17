import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 宽屏 / 遥控操作设备的判定与显示补偿。
///
/// 本应用只面向车机中控：布局一律按「宽屏 + 侧栏」处理，不再区分手机/平板。
/// 焦点描边与遥控输入相关的判定仍保留（车机可能只有旋钮/方向盘按键），
/// 原生探测见 MainActivity 的 `abts/device` 通道，失败时回退到启发式。
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

  /// 是否采用「宽屏形态」：车机一律为宽屏侧栏布局。
  static bool useWideLayout(BuildContext context) => true;

  /// 车机不再做额外字号补偿：字号统一由「屏幕缩放与边距调整」控制，
  /// 两处叠加会把字放得过大。
  static TextScaler? textScalerFor(BuildContext context) => null;
}
