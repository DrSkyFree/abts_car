import 'dart:io';

import 'package:flutter/services.dart';

/// 设备系统能力（走 MainActivity 原生通道）：
/// 电池优化忽略（后台留存保护）
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const _channel = MethodChannel('abts/battery');
  static const _deviceChannel = MethodChannel('abts/device');

  bool get _isAndroid => Platform.isAndroid;

  /// 完全退出：结束进程与后台播放服务。
  ///
  /// 车机一般没有「后台任务管理 / 上滑关闭」，用这个入口彻底退出应用。
  Future<void> exitApp() async {
    if (!_isAndroid) {
      exit(0);
    }
    try {
      await _deviceChannel.invokeMethod<bool>('exit');
    } catch (_) {
      // 通道不可用时直接结束进程，保证一定能退出
      exit(0);
    }
  }

  /// 是否已豁免电池优化
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoring') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳转系统设置请求豁免
  Future<void> requestIgnoreBatteryOptimization() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestIgnore');
    } catch (_) {}
  }
}