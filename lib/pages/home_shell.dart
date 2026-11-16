import 'package:flutter/material.dart';

import '../core/nav/home_tabs.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tv_mode.dart';
import '../services/umeng_analytics.dart';
import '../widgets/focus_ring.dart';
import '../widgets/mini_player.dart';
import '../widgets/shelf_resume_button.dart';
import 'bookshelf_page.dart';
import 'discover_page.dart';
import 'my_page.dart';
import 'search_page.dart';

/// 主框架：书架 / 发现 / 我的 + 底部迷你播放条
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = HomeTabs.index.value;

  static const _pageNames = ['书架', '发现', '我的'];

  @override
  void initState() {
    super.initState();
    HomeTabs.index.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppAnalytics.onPageStart(_pageNames[_tab]);
      }
    });
  }

  @override
  void dispose() {
    HomeTabs.index.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    AppAnalytics.onPageEnd(_pageNames[_tab]);
    setState(() => _tab = HomeTabs.index.value);
    AppAnalytics.onPageStart(_pageNames[_tab]);
  }

  @override
  Widget build(BuildContext context) {
    // 宽屏形态（电视/平板/手机横屏）用左侧导航栏，手机竖屏保持底部导航。
    // 侧栏固定紧凑图标+文字宽度（约 72dp），不做扩展态，避免占掉过多横向空间
    final wide = TvMode.useWideLayout(context);

    final content = Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [BookshelfPage(), DiscoverPage(), MyPage()],
          ),
        ),
        const MiniPlayer(),
      ],
    );

    if (wide) {
      // 车机/电视的左侧导航：加宽到 118dp，图标与文字同步加大（车机上手指、
      // 手套都更难精细点击）；搜索入口放在「发现」和「我的」之间，符合主驾
      // 伸手距离，也不必再滑到底部去找。
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              SizedBox(
                width: 118,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // 续播入口：有在听/上次在听时显示旋转封面
                    const SizedBox(
                      height: 56,
                      child: Center(child: ShelfResumeButton(size: 46)),
                    ),
                    const SizedBox(height: 6),
                    _RailItem(
                      icon: Icons.collections_bookmark_outlined,
                      selectedIcon: Icons.collections_bookmark_rounded,
                      label: '书架',
                      selected: _tab == 0,
                      onTap: () => HomeTabs.switchTo(0),
                    ),
                    _RailItem(
                      icon: Icons.explore_outlined,
                      selectedIcon: Icons.explore_rounded,
                      label: '发现',
                      selected: _tab == 1,
                      onTap: () => HomeTabs.switchTo(1),
                    ),
                    _RailItem(
                      icon: Icons.search_rounded,
                      selectedIcon: Icons.search_rounded,
                      label: '搜索',
                      selected: false,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SearchPage()),
                        );
                      },
                    ),
                    _RailItem(
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      label: '我的',
                      selected: _tab == 2,
                      onTap: () => HomeTabs.switchTo(2),
                    ),
                    const Spacer(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 0.6,
                color: AppTheme.divider,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        selectedIndex: _tab,
        onDestinationSelected: (i) => HomeTabs.switchTo(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            selectedIcon: Icon(Icons.collections_bookmark_rounded),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

/// 侧栏底部的搜索入口：图标 + 文字，聚焦时描边（遥控器可达）
/// 左侧导航项：118dp 宽的侧栏里给足点击面积（车机上手指操作），
/// 选中态用品牌色底 + 品牌色图标文字，聚焦时再描一圈品牌色边。
class _RailItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (v) {
          if (mounted && v != _focused) setState(() => _focused = v);
        },
        borderRadius: radius,
        child: FocusRing(
          focused: _focused,
          borderRadius: radius,
          width: 2.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: 82,
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? widget.selectedIcon : widget.icon,
                  size: 30,
                  color: selected ? AppTheme.accent : AppTheme.textSub,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppTheme.accent : AppTheme.textSub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
