import 'package:dio/dio.dart';

import '../core/app_meta.dart';

/// 检查更新：只在用户手动点击时请求 GitHub Releases，不做后台自动检查。
///
/// 应用内不下载、不安装，只展示版本号与发布日期，引导用户到仓库手动下载。
class UpdateResult {
  const UpdateResult({
    required this.configured,
    this.error,
    this.latestVersion,
    this.publishedAt,
  });

  /// 是否已配置 GitHub 仓库（未配置时不会发起请求）
  final bool configured;
  final String? error;
  final String? latestVersion;
  final DateTime? publishedAt;

  bool get hasNewer {
    if (!configured) return false;
    final v = latestVersion;
    if (v == null) return false;
    return _compareVersion(AppMeta.version, v) < 0;
  }
}

/// GitHub 语义化版本比较：等价返回 0，a 大返回 1，a 小返回 -1
int _compareVersion(String a, String b) {
  int toInt(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0;
  final pa = a.split('.');
  final pb = b.split('.');
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? toInt(pa[i]) : 0;
    final y = i < pb.length ? toInt(pb[i]) : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

class AppUpdate {
  AppUpdate._();

  /// GitHub 仓库（检查更新数据源）
  static const String githubOwner = 'DrSkyFree';
  static const String githubRepo = 'abts_car';

  static bool get configured => githubOwner.isNotEmpty && githubRepo.isNotEmpty;

  /// 仓库 Releases 页面：用户手动下载安装包
  static String get releasesUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases';

  static String get _apiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  /// 检查最新版本。
  ///
  /// 未配置仓库时直接返回 [configured=false]，不发起网络请求。
  static Future<UpdateResult> check() async {
    if (!configured) {
      return const UpdateResult(configured: false);
    }
    try {
      final resp = await Dio().get(
        _apiUrl,
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data as Map? ?? {};
      final tag = '${data['tag_name'] ?? ''}';
      final published = DateTime.tryParse('${data['published_at'] ?? ''}');
      return UpdateResult(
        configured: true,
        latestVersion: tag.isEmpty ? null : tag.replaceFirst(RegExp(r'^v'), ''),
        publishedAt: published?.toLocal(),
      );
    } catch (e) {
      return const UpdateResult(configured: true, error: '检查更新失败，请稍后重试');
    }
  }
}
