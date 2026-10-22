import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 车机适配配置控制器（持久化到本地）
///
/// 面向安卓横屏车机 / 大屏显示设备，解决两类问题：
///  1. 车机状态栏、导航栏是「悬浮覆盖」在应用之上的，拿不到系统 inset，
///     顶部/底部按钮会被压住无法点击 → 用 [edgeTop] / [edgeBottom] 手动留白；
///  2. 车机屏幕物理尺寸小、观看距离远，需要整体放大/缩小界面 → 用 [scale]。
///
/// [edgeTop] / [edgeBottom] 单位是**屏幕物理像素**，设置页按物理像素呈现，
/// 用户对照车机状态栏高度直接填数字即可。
class DisplayPrefs extends ChangeNotifier {
  DisplayPrefs._();
  static final DisplayPrefs instance = DisplayPrefs._();

  /// 构建期标记：`flutter build apk --dart-define=ABTS_CAR=1` 产出车机版，
  /// 默认开启横屏锁定与车机模式底色。
  static const bool isCarBuild = bool.fromEnvironment('ABTS_CAR');

  static const String _kScale = 'car_ui_scale';
  static const String _kEdgeTop = 'car_edge_top';
  static const String _kEdgeBottom = 'car_edge_bottom';
  static const String _kLandscape = 'car_landscape_lock';
  static const String _kFullscreen = 'car_fullscreen';

  /// 缩放范围：0.6（小屏收窄内容）~ 1.6（大字大按钮）
  static const double minScale = 0.6;
  static const double maxScale = 1.6;
  static const double defaultScale = 1.0;

  /// 上下边距范围：0~100 物理像素
  static const double minEdge = 0;
  static const double maxEdge = 100;

  double _scale = defaultScale;
  double _edgeTop = 0;
  double _edgeBottom = 0;
  bool _landscapeLock = isCarBuild;
  bool _fullscreen = false;
  Future<void>? _loading;

  double get scale => _scale;
  double get edgeTop => _edgeTop;
  double get edgeBottom => _edgeBottom;

  /// 锁定横屏（车机版默认锁定，可手动关闭）
  bool get landscapeLock => _landscapeLock;

  /// 沉浸式全屏：隐藏状态栏/导航栏。默认关闭——多数车机仍需显示状态栏。
  bool get fullscreen => _fullscreen;

  bool get isDefault =>
      _scale == defaultScale &&
      _edgeTop == 0 &&
      _edgeBottom == 0 &&
      _landscapeLock == isCarBuild &&
      !_fullscreen;

  /// 是否已经和默认配置不同（设置页用于高亮提示）
  bool get customized => !isDefault;

  /// 加载本地配置并同步系统方向/UI 模式。并发调用共享同一个 Future。
  Future<void> load() {
    if (_loading != null) return _loading!;
    final f = _doLoad();
    _loading = f;
    return f;
  }

  Future<void> _doLoad() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _scale = _clampScale(
        (sp.getDouble(_kScale) ?? defaultScale).toDouble(),
      );
      _edgeTop = _clampEdge((sp.getDouble(_kEdgeTop) ?? 0).toDouble());
      _edgeBottom = _clampEdge((sp.getDouble(_kEdgeBottom) ?? 0).toDouble());
      _landscapeLock = sp.getBool(_kLandscape) ?? isCarBuild;
      _fullscreen = sp.getBool(_kFullscreen) ?? false;
    } catch (e) {
      debugPrint('[DisplayPrefs] load failed: $e');
    }
    await applySystemUi();
  }

  Future<void> setScale(double v) async {
    final next = _clampScale(v);
    if (_scale == next) return;
    _scale = next;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kScale, next);
  }

  /// [top] / [bottom] 均为屏幕物理像素
  Future<void> setEdge({double? top, double? bottom}) async {
    final t = _clampEdge(top ?? _edgeTop);
    final b = _clampEdge(bottom ?? _edgeBottom);
    if (_edgeTop == t && _edgeBottom == b) return;
    _edgeTop = t;
    _edgeBottom = b;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kEdgeTop, t);
    await sp.setDouble(_kEdgeBottom, b);
  }

  Future<void> setLandscapeLock(bool v) async {
    if (_landscapeLock == v) return;
    _landscapeLock = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kLandscape, v);
    await applySystemUi();
  }

  Future<void> setFullscreen(bool v) async {
    if (_fullscreen == v) return;
    _fullscreen = v;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kFullscreen, v);
    await applySystemUi();
  }

  /// 恢复出厂：缩放 100%、边距 0、恢复当前构建默认的方向/全屏策略
  Future<void> resetDefault() async {
    _scale = defaultScale;
    _edgeTop = 0;
    _edgeBottom = 0;
    _landscapeLock = isCarBuild;
    _fullscreen = false;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kScale);
    await sp.remove(_kEdgeTop);
    await sp.remove(_kEdgeBottom);
    await sp.remove(_kLandscape);
    await sp.remove(_kFullscreen);
    await applySystemUi();
  }

  /// 快捷预设：一键解决「状态栏遮挡」与「屏幕偏小」
  Future<void> applyPreset(CarPreset preset) async {
    switch (preset) {
      case CarPreset.none:
        await resetDefault();
        break;
      case CarPreset.statusBarAvoid:
        // 上移 48px、下移 24px，避开悬浮状态栏 + 手势条
        await setEdge(top: 48, bottom: 24);
        break;
      case CarPreset.compact:
        // 缩小到 85%，一屏放下更多内容
        await setScale(0.85);
        break;
      case CarPreset.farView:
        // 放大到 130%，车机远距离观看、点按容错高
        await setScale(1.3);
        break;
    }
  }

  /// 把配置同步到系统：屏幕方向 + 系统 UI 模式（沉浸式）
  Future<void> applySystemUi() async {
    try {
      await SystemChrome.setPreferredOrientations(_landscapeLock
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : DeviceOrientation.values);
      if (_fullscreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      debugPrint('[DisplayPrefs] applySystemUi failed: $e');
    }
  }

  static double _clampScale(double v) {
    if (v.isNaN) return defaultScale;
    return math.min(maxScale, math.max(minScale, v));
  }

  static double _clampEdge(double v) {
    if (v.isNaN) return 0;
    return math.min(maxEdge, math.max(minEdge, v));
  }
}

/// 车机适配预设
enum CarPreset {
  none('恢复默认'),
  statusBarAvoid('避开状态栏'),
  compact('紧凑模式'),
  farView('远距离放大');

  const CarPreset(this.label);
  final String label;
}
