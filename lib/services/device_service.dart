import 'dart:io';

import 'package:flutter/services.dart';

import 'log_collector.dart';

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
    // 退出前日志抓取开启时静默自动保存（进程马上会被杀，这是最后机会）
    try {
      await LogCollector.instance.autoSave().timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await _deviceChannel.invokeMethod<bool>('exit');
    } catch (_) {
      // 通道不可用时直接结束进程，保证一定能退出
      exit(0);
    }
  }

  /// 开机计时（毫秒，不含深度休眠）：配合墙钟检测车辆熄火休眠
  Future<int> elapsedRealtime() async {
    if (!_isAndroid) return 0;
    try {
      return await _deviceChannel.invokeMethod<int>('elapsedRealtime') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 绑定系统亮/熄屏事件（车机熄火休眠时会熄屏）
  void bindScreenEvents({
    required void Function() onScreenOff,
    required void Function() onScreenOn,
  }) {
    _deviceChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'screenOff':
          onScreenOff();
        case 'screenOn':
          onScreenOn();
      }
      return null;
    });
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