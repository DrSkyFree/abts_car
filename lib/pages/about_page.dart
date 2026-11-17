import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_meta.dart';
import '../core/theme/app_theme.dart';
import '../services/browser.dart';
import '../widgets/page_scaffold.dart';

/// 关于我们：应用介绍 + 开源/官网快捷入口 + 免责声明
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
          _buildDisclaimer(context),
          const SizedBox(height: 18),
          Center(
            child: Text(
              '感谢每一位反馈问题的你',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textHint),
            ),
          ),
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

  /// 一句话讲清它是干什么的
  Widget _buildIntro(BuildContext context) {
    const points = [
      '把 B 站当作有声书库：有声小说、评书、相声、广播剧，搜到就能听',
      '不登录也能用，没有广告、没有会员、没有弹窗',
      '为长时间收听优化：倍速、断点续播、离线缓存、后台与锁屏控制',
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

  /// 快捷跳转：开源仓库 / 官网 / 问题反馈 / 协议
  Widget _buildLinks(BuildContext context) {
    // 用 Material 承载卡片底色：卡内各链接行的聚焦高亮/水波才能
    // 画在卡片之上（普通 Container 白底会盖住 ink 层）
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
            subtitle: '源码、构建说明与版本发布',
            url: AppMeta.repoUrl,
          ),
          _divider(),
          _linkTile(
            context,
            icon: Icons.language_rounded,
            title: '官方网站',
            subtitle: '功能介绍与下载入口',
            url: AppMeta.siteUrl,
          ),
          _divider(),
          _linkTile(
            context,
            icon: Icons.bug_report_outlined,
            title: '问题反馈',
            subtitle: '遇到问题或想要新功能，欢迎提 Issue',
            url: AppMeta.issuesUrl,
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

  /// 免责声明：与仓库 README 的「开源申明与免责声明」保持一致，
  /// 这里做精简版，内容口径（不提供内容服务 / 禁止牟利 / 通知处理）必须一致
  static const _disclaimerSections = <(String, String)>[
    (
      '项目性质',
      '本应用是个人开发的开源技术学习与车机适配测试项目，不提供任何音视频内容服务：'
          '不内置、不托管、不分发、不转码任何作品资源。应用内看到、听到的内容，均由使用者'
          '通过第三方平台的公开接口自行获取，并仅在本机临时播放。',
    ),
    (
      '权利归属',
      '内容著作权及邻接权归原作者及相关权利人所有。本应用不存储、不修改、不二次分发'
          '任何作品；离线缓存仅保存在本机私有目录，供个人离线收听。本应用与哔哩哔哩及其'
          '关联主体不存在任何隶属、合作、授权或认可关系。',
    ),
    (
      '使用限制',
      '仅限个人学习、测试与试听交流。不得用于售卖、付费下载、预装捆绑、广告分成等任何'
          '牟利行为；不得批量抓取、录制、转存、传播他人作品，不得绕过权利人的付费机制与'
          '访问限制；不得以本应用名义暗示官方授权。请在试听后支持正版。',
    ),
    (
      '免责与责任限制',
      '本应用按「现状」提供，不附带任何明示或默示担保。在法律允许的最大范围内，作者与'
          '贡献者不对因下载、安装、使用或二次开发本应用造成的任何直接或间接损失，以及'
          '第三方提出的权利主张承担责任；因使用者违反法律法规或本节约定产生的责任，'
          '由使用者自行承担。依法不得排除或限制的责任不受本节影响。',
    ),
    (
      '侵权处理',
      '如权利人认为本应用侵犯其合法权益，请通过「问题反馈」提交权属证明、具体位置与说明，'
          '核实后将及时删除、屏蔽相关入口或内容，并对同类问题做整体排查。',
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