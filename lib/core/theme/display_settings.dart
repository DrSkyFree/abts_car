import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 屏幕显示设置：整体缩放、字号、封面尺寸与四周边距。
///
/// 本应用只面向车机中控，「使用设备」固定为车机，不再提供手机/平板预设。
///
/// 车机中控常见问题：系统状态栏/底栏是画在应用之上的覆盖层，应用拿不到
/// `MediaQuery.padding`，于是内容被顶栏压住；同时 1920 宽的大屏按 dp 渲染
/// 会让字显得很小、封面却很大。这里把四周边距（占屏幕百分比）与缩放做成
/// 可调项，由 [main.dart] 的 MaterialApp.builder 统一套用到整棵组件树，
/// 因此改动即时生效。
class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance = DisplaySettings._();

  static const _kScale = 'display_scale';
  static const _kTextScale = 'display_text_scale';
  static const _kCoverScale = 'display_cover_scale';
  static const _kMarginTop = 'display_margin_top';
  static const _kMarginBottom = 'display_margin_bottom';
  static const _kMarginLeft = 'display_margin_left';
  static const _kMarginRight = 'display_margin_right';

  // 可调范围（界面缩放同时作用于按钮、列表、封面等所有 dp 尺寸）
  static const double minScale = 0.7;
  static const double maxScale = 1.4;
  static const double minTextScale = 0.8;
  static const double maxTextScale = 2.0;
  static const double minCoverScale = 0.6;
  static const double maxCoverScale = 1.3;
  static const double maxMargin = 30;

  // 默认即车机预设：顶部留 7% 避开中控状态栏，字号放大、封面缩小
  static const double defaultScale = 1.0;
  static const double defaultTextScale = 1.3;
  static const double defaultCoverScale = 0.85;
  static const double defaultMarginTop = 7;

  double _scale = defaultScale;
  double _textScale = defaultTextScale;
  double _coverScale = defaultCoverScale;
  double _marginTop = defaultMarginTop;
  double _marginBottom = 0;
  double _marginLeft = 0;
  double _marginRight = 0;

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

  EdgeInsets insetsFor(Size viewport) => EdgeInsets.fromLTRB(
        viewport.width * _marginLeft / 100,
        viewport.height * _marginTop / 100,
        viewport.width * _marginRight / 100,
        viewport.height * _marginBottom / 100,
      );

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _scale = sp.getDouble(_kScale) ?? defaultScale;
    _textScale = sp.getDouble(_kTextScale) ?? defaultTextScale;
    _coverScale = sp.getDouble(_kCoverScale) ?? defaultCoverScale;
    _marginTop = sp.getDouble(_kMarginTop) ?? defaultMarginTop;
    _marginBottom = sp.getDouble(_kMarginBottom) ?? 0;
    _marginLeft = sp.getDouble(_kMarginLeft) ?? 0;
    _marginRight = sp.getDouble(_kMarginRight) ?? 0;
  }

  /// 恢复车机默认预设
  Future<void> resetToPreset() async {
    _scale = defaultScale;
    _textScale = defaultTextScale;
    _coverScale = defaultCoverScale;
    _marginTop = defaultMarginTop;
    _marginBottom = 0;
    _marginLeft = 0;
    _marginRight = 0;
    notifyListeners();
    await _persist();
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
    await sp.setDouble(_kScale, _scale);
    await sp.setDouble(_kTextScale, _textScale);
    await sp.setDouble(_kCoverScale, _coverScale);
    await sp.setDouble(_kMarginTop, _marginTop);
    await sp.setDouble(_kMarginBottom, _marginBottom);
    await sp.setDouble(_kMarginLeft, _marginLeft);
    await sp.setDouble(_kMarginRight, _marginRight);
  }
}
