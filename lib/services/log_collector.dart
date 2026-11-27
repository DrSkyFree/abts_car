import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 轻量日志抓取单例（默认关闭；主驾遇到播放异常时手动开启）。
///
/// 设计要点：
/// - **默认关**：`enabled` 持久化到 SharedPreferences，App 重启后恢复用户选择
/// - **内存 ring buffer**：上限 5000 条（约 500KB），FIFO 防 OOM；
///   关闭时停止采集但不清空，可反复导出同一批
/// - **不阻塞主线程**：内部只做 List.add + StringBuffer，无 async
/// - **导出走 Download 目录**：Android 9+ 车机无分区存储限制，
///   `WRITE_EXTERNAL_STORAGE` 即可；失败时回落到应用私有目录
/// - **埋点风格**：`LogCollector.i('player', 'play start');` 三参
class LogCollector {
  LogCollector._();
  static final LogCollector instance = LogCollector._();

  static const _kEnabled = 'log_capture_enabled';
  static const _kMaxEntries = 5000;

  final List<_LogEntry> _entries = [];
  final List<String> _savedFiles = []; // 最近已导出文件列表

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

    if (_entries.isEmpty) {
      return (null, '还没有日志可以保存');
    }

    final buffer = StringBuffer();
    buffer.writeln('=== 阿B听书 日志导出 ===');
    buffer.writeln('App 版本: 请见关于页面');
    buffer.writeln('导出时间: ${_fmtStamp(DateTime.now())}');
    buffer.writeln('条目数: ${_entries.length}');
    buffer.writeln();
    for (final e in _entries) {
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
      stamp: _fmtStamp(DateTime.now()),
      level: level,
      source: source,
      msg: msg,
    );
    if (_entries.length >= _kMaxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
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
  _LogEntry({required this.stamp, required this.level, required this.source, required this.msg});
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
