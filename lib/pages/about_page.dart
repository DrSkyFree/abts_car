import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_meta.dart';
import '../core/theme/app_theme.dart';
import '../services/browser.dart';
import '../services/log_collector.dart';
import '../widgets/page_scaffold.dart';

/// 关于我们：应用介绍 + 开源仓库/协议入口 + 日志抓取 + 免责声明
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 抓取中每秒刷新计数 & savedFiles
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (LogCollector.instance.enabled && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: const Text('关于我们'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildLogo(context),
          const SizedBox(height: 14),
          Text(
            AppMeta.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppMeta.tagline,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSub),
          ),
          const SizedBox(height: 4),
          Text(
            '版本 ${AppMeta.version}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textHint),
          ),
          const SizedBox(height: 22),
          _buildIntro(context),
          const SizedBox(height: 14),
          _buildLinks(context),
          const SizedBox(height: 14),
          _buildLogCapture(context),
          const SizedBox(height: 14),
          _buildDisclaimer(context),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '开源项目 · 感谢每一位使用与支持的用户',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 80), // 底部避让系统导航栏（宽屏车机 40px）
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Center(
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              color: AppTheme.surfaceHigh,
              child: Icon(Icons.headset_rounded, size: 40, color: AppTheme.accent),
            ),
          ),
        ),
      ),
    );
  }

  /// 应用介绍：与仓库 README 的「这个仓库是什么」「车机版特性」口径一致
  Widget _buildIntro(BuildContext context) {
    const points = [
      '把 B 站当作有声书库：搜索、分类浏览有声小说、评书、相声、广播剧，点开即听',
      '免登录、无广告、无会员，永久免费、开源（MIT）',
      '车机专用适配：宽屏侧栏、主驾视角播放页、大按钮大字号，倍速、断点续播、离线缓存',
      '熄火后不自动播放：必须先实际操作应用才允许播放，车机自动下发的指令不会自己响',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      p,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSub,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 快捷跳转：开源仓库 / 开源协议
  Widget _buildLinks(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            _linkTile(
              context,
              icon: Icons.code_rounded,
              title: '开源仓库',
              subtitle: '源码、构建说明、更新日志与版本发布',
              url: AppMeta.repoUrl,
            ),
            _divider(),
            _linkTile(
              context,
              icon: Icons.balance_rounded,
              title: '开源协议',
              subtitle: 'MIT License',
              url: AppMeta.licenseUrl,
            ),
          ],
        ),
      ),
    );
  }

  /// 日志抓取：主驾遇到播放异常（被打断、自动恢复等）时手动开启，
  /// 结束后保存为 txt 到车机 Download 目录，供排查问题。
  Widget _buildLogCapture(BuildContext context) {
    final lc = LogCollector.instance;
    final enabled = lc.enabled;
    final count = lc.count;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_outlined, size: 16, color: enabled ? AppTheme.accent : AppTheme.textSub),
              const SizedBox(width: 6),
              Text(
                '日志抓取',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const Spacer(),
              if (enabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '已记录 $count 条',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            enabled
                ? '正在抓取播放状态、音频焦点、断流重连、熄屏/生命周期等事件。遇到问题后及时关闭并保存，文件将写入车机 Download 目录。'
                : '关闭状态。遇到播放异常（被打断后自动恢复/无法恢复、熄屏/熄火后行为不对等）时再手动开启。',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textHint,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          // 开关行
          SwitchListTile.adaptive(
            value: enabled,
            onChanged: _onToggle,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            title: Text(
              '开启日志抓取',
              style: TextStyle(fontSize: 13, color: AppTheme.textMain),
            ),
            subtitle: enabled
                ? Text('点击下方按钮保存后再关闭',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint))
                : null,
          ),
          const SizedBox(height: 6),
          // 停止并保存按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: enabled ? () => _stopAndSave(context) : null,
              icon: const Icon(Icons.save_alt_rounded, size: 20),
              label: const Text('停止并保存到 Download'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: enabled ? AppTheme.accent : AppTheme.textHint,
                side: BorderSide(
                  color: enabled ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.divider,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 已保存列表
          if (lc.savedFiles.isNotEmpty) ...[
            Text(
              '最近保存',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSub,
              ),
            ),
            const SizedBox(height: 4),
            for (final f in lc.savedFiles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, size: 13, color: AppTheme.textHint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            '仅存储到本机 Download 目录，不上传任何内容。关闭后可随时再次开启。',
            style: TextStyle(fontSize: 10.5, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Future<void> _onToggle(bool v) async {
    if (v) {
      // 开启前请求存储写入权限
      final ok = await _ensureStoragePermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有存储写入权限，无法保存日志')),
          );
        }
        if (mounted) setState(() {}); // 刷新 UI（开关未变但可能有延迟）
        return;
      }
    }
    await LogCollector.instance.setEnabled(v);
    if (mounted) setState(() {});
  }

  Future<bool> _ensureStoragePermission() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[LogCollector] permission request failed: $e');
      return true;
    }
  }

  Future<void> _stopAndSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final (path, error) = await LogCollector.instance.export();
    // 停止抓取，避免保存过程中还在写
    await LogCollector.instance.setEnabled(false);
    if (!context.mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } else {
      final fname = path!.split('/').last;
      messenger.showSnackBar(SnackBar(
        content: Text('已保存: $fname\n路径: $path'),
        duration: const Duration(seconds: 4),
      ));
    }
    setState(() {});
  }

  Widget _divider() => const Divider(height: 1, indent: 56);

  Widget _linkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return InkWell(
      onTap: () => _open(context, url, title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textSub),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  /// 打开链接；打不开时复制到剪贴板兜底
  Future<void> _open(BuildContext context, String url, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await Browser.open(url);
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      SnackBar(content: Text('$title 链接已复制\n$url')),
    );
  }

  /// 免责声明：与仓库 README 的「开源申明与免责声明」（一~六节）保持一致，
  /// 这里做精简版，内容口径（不提供内容服务 / 禁止牟利 / 通知处理）必须一致，
  /// 完整条款以仓库 README 为准
  static const _disclaimerSections = <(String, String)>[
    (
      '项目性质与适用范围',
      '本应用是个人开发者发起的开源技术学习与车机适配测试项目，不提供任何音视频'
          '内容服务：不内置、不缓存、不托管、不分发、不转码任何作品资源。应用内看到、'
          '听到的内容，均由使用者通过第三方平台的公开接口自行获取，并仅在本机临时播放。'
          '本应用与哔哩哔哩及其关联主体不存在任何隶属、代理、合作、授权或认可关系。',
    ),
    (
      '权利归属与内容责任',
      '内容著作权及邻接权归原作者及相关权利人所有。本应用不存储、不修改、不二次分发'
          '任何作品；离线缓存仅把使用者本人请求的数据保存在其设备私有目录，仅可在应用内'
          '播放、有效期 7 天并自动清理、不提供导出/分享/转存。收听内容的合法性由使用者'
          '自行判断并承担，请在试听后支持正版。',
    ),
    (
      '使用者的合规义务',
      '仅限个人学习、测试与试听交流；不得用于售卖、付费下载、预装捆绑、广告分成、'
          '会员收费等任何牟利行为；不得批量抓取、镜像、录制、转存、传播他人作品，不得'
          '绕过权利人的付费机制与访问限制；不得删除或修改本声明与开源许可，不得以本应用'
          '名义暗示官方授权或官方背书。',
    ),
    (
      '免责与责任限制',
      '本应用按「现状」提供，不附带任何明示或默示担保。在法律允许的最大范围内，作者与'
          '贡献者不对因下载、安装、运行、升级、卸载本应用造成的任何直接或间接损失，以及'
          '借助本应用获取、播放、缓存内容引发的任何权利主张与投诉承担责任；使用者违反'
          '法律法规或本节约定产生的责任由使用者独立承担。依法不得排除或限制的责任'
          '不受本节影响。',
    ),
    (
      '侵权通知与处理',
      '权利人如认为本应用侵犯其合法权益，请通过开源仓库 Issues 提交权属证明、侵权内容'
          '的具体位置与说明，核实后将及时删除、屏蔽相关入口或内容，并对同类问题做'
          '整体排查。',
    ),
    (
      '其他',
      '本节内容可能随项目迭代更新，更新后自发布之时生效，继续使用即视为接受更新后的'
          '说明；若任何条款被有权机关认定为无效，不影响其余条款效力。完整条款以开源'
          '仓库 README 为准。',
    ),
  ];

  Widget _buildDisclaimer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 16, color: AppTheme.textSub),
              const SizedBox(width: 6),
              Text(
                '免责声明',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '下载、安装、运行本应用或对其进行二次开发，即视为已阅读并同意以下内容；'
            '完整条款见开源仓库 README。',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSub,
              height: 1.7,
            ),
          ),
          for (final (i, s) in _disclaimerSections.indexed) ...[
            const SizedBox(height: 10),
            Text(
              '${i + 1}. ${s.$1}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.$2,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSub,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
