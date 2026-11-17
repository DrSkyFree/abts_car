import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 使用设备：车机（竖屏）/ 车机（横屏）
///
/// - 竖屏：走大屏手机的布局逻辑（底部导航、触屏操作），适用于竖装中控
/// - 横屏：宽屏侧栏布局，预留顶部状态栏空间，字号放大
enum DeviceProfile {
  phone,
  car;

  String get label => switch (this) {
        DeviceProfile.phone => '车机（竖屏）',
        DeviceProfile.car => '车机（横屏）',
      };

  String get desc => switch (this) {
        DeviceProfile.phone => '大屏手机布局，底部导航、触屏操作，适合竖装中控',
        DeviceProfile.car => '宽屏侧栏布局，预留顶部状态栏空间，字号放大',
      };
}

/// 屏幕显示设置：使用设备、整体缩放、字号、封面尺寸与四周边距。
///
/// 车机中控常见问题：系统状态栏/底栏是画在应用之上的覆盖层，应用拿不到
/// `MediaQuery.padding`，于是内容被顶栏压住；同时 1920 宽的大屏按 dp 渲染
/// 会让字显得很小、封面却很大。这里把四周边距（占屏幕百分比）与缩放做成
/// 可调项，由 [main.dart] 的 MaterialApp.builder 统一套用到整棵组件树，
/// 因此改动即时生效。
class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance = DisplaySettings._();

  static const _channel = MethodChannel('abts/device');

  static const _kDevice = 'display_device';
  static const _kScale = 'display_scale';
  static const _kTextScale = 'display_text_scale';
  static const _kCoverScale = 'display_cover_scale';
  static const _kMarginTop = 'display_margin_top';
  static const _kMarginBottom = 'display_margin_bottom';
  static const _kMarginLeft = 'display_margin_left';
  static const _kMarginRight = 'display_margin_right';
  static const _kFullscreen = 'display_fullscreen';

  // 可调范围（界面缩放同时作用于按钮、列表、封面等所有 dp 尺寸）
  static const double minScale = 0.7;
  static const double maxScale = 1.4;
  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;
  static const double minCoverScale = 0.6;
  static const double maxCoverScale = 1.3;
  static const double maxMargin = 30;

  DeviceProfile _device = DeviceProfile.phone;
  double _scale = 1.0;
  double _textScale = 1.0;
  double _coverScale = 1.0;
  double _marginTop = 0;
  double _marginBottom = 0;
  double _marginLeft = 0;
  double _marginRight = 0;

  /// 全屏模式：隐藏系统状态栏/导航栏（沉浸式），开启后四周边距不再生效
  bool _fullscreen = false;

  DeviceProfile get device => _device;
  bool get isCar => _device == DeviceProfile.car;
  bool get fullscreen => _fullscreen;

  /// 整体界面缩放：1.0 为原始尺寸
  double get scale => _scale;

  /// 字号额外缩放（在系统/车机补偿之上再乘一次）
  double get textScale => _textScale;

  /// 封面尺寸系数：>1 封面更大（每行列数更少）
  double get coverScale => _coverScale;

  // 边距按屏幕宽高的百分比计算
  double get marginTop => _marginTop;
  double get marginBottom => _marginBottom;
  double get marginLeft => _marginLeft;
  double get marginRight => _marginRight;

  /// 全屏模式下四周边距不生效（系统栏已隐藏，无需避让）
  EdgeInsets insetsFor(Size viewport) {
    if (_fullscreen) return EdgeInsets.zero;
    return EdgeInsets.fromLTRB(
      viewport.width * _marginLeft / 100,
      viewport.height * _marginTop / 100,
      viewport.width * _marginRight / 100,
      viewport.height * _marginBottom / 100,
    );
  }

  bool get hasTuning =>
      _scale != 1.0 ||
      _textScale != 1.0 ||
      _marginTop != 0 ||
      _marginBottom != 0 ||
      _marginLeft != 0 ||
      _marginRight != 0;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _device = sp.getString(_kDevice) == DeviceProfile.car.name
        ? DeviceProfile.car
        : DeviceProfile.phone;
    _scale = sp.getDouble(_kScale) ?? 1.0;
    _textScale = sp.getDouble(_kTextScale) ?? 1.0;
    _coverScale = sp.getDouble(_kCoverScale) ?? 1.0;
    _marginTop = sp.getDouble(_kMarginTop) ?? 0;
    _marginBottom = sp.getDouble(_kMarginBottom) ?? 0;
    _marginLeft = sp.getDouble(_kMarginLeft) ?? 0;
    _marginRight = sp.getDouble(_kMarginRight) ?? 0;
    _fullscreen = sp.getBool(_kFullscreen) ?? false;
    // 启动时把全屏状态同步给原生（沉浸式需要原生侧设置窗口 flag）
    await _applyFullscreen();
  }

  /// 开关全屏：原生隐藏系统状态栏/导航栏，随后持久化
  Future<void> setFullscreen(bool v) async {
    if (_fullscreen == v) return;
    _fullscreen = v;
    notifyListeners();
    await _persist();
    await _applyFullscreen();
  }

  /// 把全屏状态交给原生 `abts/device` 通道处理
  Future<void> _applyFullscreen() async {
    try {
      await _channel.invokeMethod<bool>('setFullscreen', {'on': _fullscreen});
    } catch (_) {
      // 通道不可用时静默降级：界面仍按无边距绘制
    }
  }

  /// 切换设备并套用该设备的推荐预设（本次优化：选车机后自动重启）
  Future<void> setDevice(DeviceProfile d) async {
    if (_device == d) return;
    _device = d;
    _applyPresetValues(d);
    notifyListeners();
    await _persist();
  }

  /// 把当前设备的推荐值写回（用于「恢复默认」）
  ///
  /// 同时退出全屏：恢复默认应当回到「带边距避让」的常规形态
  Future<void> resetToPreset() async {
    _applyPresetValues(_device);
    _fullscreen = false;
    notifyListeners();
    await _persist();
    await _applyFullscreen();
  }

  void _applyPresetValues(DeviceProfile d) {
    switch (d) {
      case DeviceProfile.phone:
        _scale = 1.0;
        _textScale = 1.0;
        _coverScale = 1.0;
        _marginTop = 0;
        _marginBottom = 0;
        _marginLeft = 0;
        _marginRight = 0;
      case DeviceProfile.car:
        // 顶部留 7% 避开中控状态栏；字号放大、封面缩小，两者独立可调
        _scale = 1.0;
        _textScale = 1.3;
        _coverScale = 0.85;
        _marginTop = 7;
        _marginBottom = 0;
        _marginLeft = 0;
        _marginRight = 0;
    }
  }

  Future<void> setScale(double v) => _set(() => _scale = _clamp(v, minScale, maxScale));
  Future<void> setTextScale(double v) =>
      _set(() => _textScale = _clamp(v, minTextScale, maxTextScale));
  Future<void> setCoverScale(double v) =>
      _set(() => _coverScale = _clamp(v, minCoverScale, maxCoverScale));
  Future<void> setMarginTop(double v) =>
      _set(() => _marginTop = _clamp(v, 0, maxMargin));
  Future<void> setMarginBottom(double v) =>
      _set(() => _marginBottom = _clamp(v, 0, maxMargin));
  Future<void> setMarginLeft(double v) =>
      _set(() => _marginLeft = _clamp(v, 0, maxMargin));
  Future<void> setMarginRight(double v) =>
      _set(() => _marginRight = _clamp(v, 0, maxMargin));

  double _clamp(double v, double min, double max) =>
      double.parse(v.clamp(min, max).toStringAsFixed(2));

  Future<void> _set(VoidCallback change) async {
    change();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDevice, _device.name);
    await sp.setDouble(_kScale, _scale);
    await sp.setDouble(_kTextScale, _textScale);
    await sp.setDouble(_kCoverScale, _coverScale);
    await sp.setDouble(_kMarginTop, _marginTop);
    await sp.setDouble(_kMarginBottom, _marginBottom);
    await sp.setDouble(_kMarginLeft, _marginLeft);
    await sp.setDouble(_kMarginRight, _marginRight);
    await sp.setBool(_kFullscreen, _fullscreen);
  }

  /// 关闭进程并重新拉起应用（车机模式切换后让布局彻底重建）
  Future<void> restartApp() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('restart');
    } catch (_) {
      // 通道不可用时静默降级：用户下次手动启动同样生效
    }
  }
}
