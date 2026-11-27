import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量日志抓取单例（默认关闭；主驾遇到播放异常时手动开启）。
///
/// 设计要点：
/// - **默认关**：`enabled` 持久化到 SharedPreferences，App 重启后恢复用户选择
/// - **双缓冲保留策略（覆盖熄火场景）**：
///   - `_entries` 普通 buffer：最近 100 条 FIFO 滚动，播放期高频日志会淘汰旧条目
///   - `_keyEntries` 关键 buffer：独立 100 条，只收「W/E 级 + 高价值来源」
///     （门闩/音频焦点/生命周期/媒体会话），永不被高频日志挤掉——
///     熄火前的播放决策链（焦点争夺、门闩锁定、媒体指令）在几小时后导出时仍在
///   - 导出 = 关键 buffer 全量 + 普通 buffer 最近段，按时间合并去重（约 100~200 条）
/// - **不阻塞主线程**：内部只做 List.add + StringBuffer，无 async
/// - **导出走 Download 目录**：Android 9+ 车机无分区存储限制，
///   `WRITE_EXTERNAL_STORAGE` 即可；失败时回落到应用私有目录
/// - **埋点风格**：`LogCollector.i('player', 'play start');` 三参
class LogCollector {
  LogCollector._();
  static final LogCollector instance = LogCollector._();

  static const _kEnabled = 'log_capture_enabled';
  static const _kMaxEntries = 100;
  static const _kMaxKeyEntries = 100;

  /// 关键事件来源白名单：熄火排查的决策链埋点（与各埋点文件保持一致）
  static const _keySources = {
    'Gate', // 播放门闩读写/媒体指令判定
    'AudioFocus', // 音频焦点争夺（点火后暂停的直接证据）
    'Lifecycle', // App 生命周期（熄屏/唤醒）
    'MediaSession', // 系统媒体会话回调（解锁后自动 PLAY 指令）
    'LogCollector', // 自动保存/导出自身
  };

  final List<_LogEntry> _entries = [];
  final List<_LogEntry> _keyEntries = [];
  final List<String> _savedFiles = []; // 最近已导出文件列表
  int _seq = 0; // 自增序号：合并导出时去重

  bool _enabled = false;

  /// 是否正在抓取（持久化值）
  bool get enabled => _enabled;

  /// 当前已采集条目数（UI 展示）
  int get count => _entries.length;

  /// 最近导出的文件（用于 UI 列表）
  List<String> get savedFiles => List.unmodifiable(_savedFiles);

  /// 最近 n 条日志的格式化行（关于页实时状态展示用，与导出格式一致）
  List<String> recentLines([int n = 5]) {
    final start = _entries.length > n ? _entries.length - n : 0;
    return _entries
        .sublist(start)
        .map((e) => '${e.stamp} [${e._levelLabel}] [${e.source}] ${e.msg}')
        .toList();
  }

  // ---------- 生命周期 ----------

  /// App 启动时调一次，恢复开关状态
  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _enabled = sp.getBool(_kEnabled) ?? false;
    } catch (_) {
      _enabled = false;
    }
  }

  Future<void> setEnabled(bool v) async {
    if (v == _enabled) return;
    _enabled = v;
    if (v) {
      _entries.clear(); // 新一轮抓取清空旧日志，避免语义混杂
      _keyEntries.clear();
    }
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_kEnabled, v);
    } catch (_) {}
  }

  // ---------- 导出 ----------

  /// 请求存储权限并导出到 Download；返回 ("路径", null) 或 (null, "错误信息")
  Future<(String? path, String? error)> export() async {
    // Android 9 车机（API 28）：WRITE_EXTERNAL_STORAGE 即可
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      return (null, '存储写入权限被拒绝');
    }
    return _writeOut();
  }

  /// 熄火/退出时的静默自动保存（best-effort）：
  /// - 不弹权限请求（熄屏瞬间弹窗会打断流程，没授权过就放弃）
  /// - 成功后清空内存日志，开始新一轮采集
  /// - 返回保存路径，失败返回 null
  Future<String?> autoSave() async {
    if (!_enabled || (_entries.isEmpty && _keyEntries.isEmpty)) return null;
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) return null;
    } catch (_) {
      return null;
    }
    final (path, err) = await _writeOut();
    if (path != null) {
      _entries.clear();
      _keyEntries.clear();
      // 注意：清空后再记，这条属于新一轮采集
      i('LogCollector', '熄火/退出自动保存成功: $path');
    } else {
      // 注意：_writeOut 失败时不清空，下次手动导出还能救回来
      w('LogCollector', '熄火/退出自动保存失败: $err');
    }
    return path;
  }

  /// 把当前日志写出为 txt（export 与 autoSave 共用）：
  /// 内容 = 关键 buffer 全量 + 普通 buffer 全量，按采集顺序合并去重；
  /// 优先 Download，其次应用外部存储，最后应用私有目录
  Future<(String? path, String? error)> _writeOut() async {
    if (_entries.isEmpty && _keyEntries.isEmpty) {
      return (null, '还没有日志可以保存');
    }

    // 双 buffer 合并去重：key 全量 + 普通全量，按 seq（采集顺序）排序
    final seen = <int>{};
    final merged = <_LogEntry>[];
    for (final e in [..._keyEntries, ..._entries]) {
      if (seen.add(e.seq)) merged.add(e);
    }
    merged.sort((a, b) => a.seq.compareTo(b.seq));

    final buffer = StringBuffer();
    buffer.writeln('=== 阿B听书 日志导出 ===');
    buffer.writeln('App 版本: 请见关于页面');
    buffer.writeln('导出时间: ${_fmtStamp(DateTime.now())}');
    buffer.writeln('条目数: ${merged.length}（关键 ${_keyEntries.length} + 普通 ${_entries.length} 去重）');
    buffer.writeln();
    for (final e in merged) {
      buffer.writeln('${e.stamp} [${e._levelLabel}] [${e.source}] ${e.msg}');
    }

    final fname = 'abts-log-${_fileStamp()}.txt';
    try {
      // 优先 Download 目录
      final path = '/storage/emulated/0/Download/$fname';
      final f = File(path);
      await f.writeAsString(buffer.toString());
      _savedFiles.insert(0, fname);
      if (_savedFiles.length > 5) _savedFiles.removeLast();
      return (path, null);
    } catch (_) {
      // 回落：应用外部存储
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final path = '${dir.path}/$fname';
          final f = File(path);
          await f.writeAsString(buffer.toString());
          _savedFiles.insert(0, fname);
          if (_savedFiles.length > 5) _savedFiles.removeLast();
          return (path, null);
        }
      } catch (_) {}
      // 最后兜底：应用私有目录
      try {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$fname';
        final f = File(path);
        await f.writeAsString(buffer.toString());
        _savedFiles.insert(0, fname);
        if (_savedFiles.length > 5) _savedFiles.removeLast();
        return (path, null);
      } catch (e) {
        return (null, '保存失败: $e');
      }
    }
  }

  // ---------- 记录 ----------

  void v(String source, String msg) => _add('V', source, msg);
  void i(String source, String msg) => _add('I', source, msg);
  void w(String source, String msg) => _add('W', source, msg);
  void e(String source, String msg) => _add('E', source, msg);

  void _add(String level, String source, String msg) {
    if (!_enabled) return;
    final entry = _LogEntry(
      seq: _seq++,
      stamp: _fmtStamp(DateTime.now()),
      level: level,
      source: source,
      msg: msg,
    );
    // 普通 buffer：全部日志，100 条 FIFO
    if (_entries.length >= _kMaxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    // 关键 buffer：W/E 级 + 高价值来源，独立 100 条——
    // 熄火排查的决策链不会被播放期高频普通日志挤掉
    final isKey = level == 'W' || level == 'E' || _keySources.contains(source);
    if (isKey) {
      if (_keyEntries.length >= _kMaxKeyEntries) {
        _keyEntries.removeAt(0);
      }
      _keyEntries.add(entry);
    }
  }

  // ---------- 工具 ----------

  static String _fmtStamp(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$mm-$dd $hh:$mi:$ss.$ms';
  }

  static String _fileStamp() {
    final dt = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}-${p(dt.hour)}${p(dt.minute)}${p(dt.second)}';
  }
}

class _LogEntry {
  _LogEntry({
    required this.seq,
    required this.stamp,
    required this.level,
    required this.source,
    required this.msg,
  });
  final int seq; // 采集顺序，双 buffer 合并导出时排序去重用
  final String stamp;
  final String level;
  final String source;
  final String msg;

  String get _levelLabel => switch (level) {
        'V' => 'VERBOSE',
        'I' => 'INFO',
        'W' => 'WARN',
        'E' => 'ERROR',
        _ => level,
      };
}
