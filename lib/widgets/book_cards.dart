import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/display_settings.dart';
import '../models/book.dart';
import '../utils/format.dart';
import 'book_cover.dart';

/// 网格列数：手机 3 列；横屏平板/车机随宽度增加（遥控器更好定位）
///
/// 车机大屏的问题正好相反：字太小、封面太大。这里用「物理宽度」判断列数
/// （乘回界面缩放系数），放大整体界面时封面不会跟着暴涨；再叠加用户的
/// 封面尺寸系数，系数越大列数越少、封面越大。
///
/// 另外按可用高度反推一次：字号放大后卡片会被撑高，一屏只剩一行显得很空，
/// 所以保证一屏至少露出约 1.5 行卡片（列数只增不减，有上下限兜底）。
int bookGridColumns(BuildContext context, {double? availableHeight}) {
  final ds = DisplaySettings.instance;
  final size = MediaQuery.sizeOf(context);
  final w = size.width * ds.scale / ds.coverScale;

  int cols;
  if (w >= 2400) {
    cols = 10;
  } else if (w >= 2100) {
    cols = 9;
  } else if (w >= 1800) {
    cols = 8;
  } else if (w >= 1400) {
    cols = 7;
  } else if (w >= 1100) {
    cols = 6;
  } else if (w >= 900) {
    cols = 5;
  } else if (w >= 640) {
    cols = 4;
  } else {
    cols = 3;
  }

  // 高度兜底：gridHeight 为网格可见高度（不含页面其他元素时的保守估计）
  const spacing = 12.0;
  const aspect = 0.55; // 与 GridView 的 childAspectRatio 保持一致
  final gridH = availableHeight ?? (size.height - 190);
  if (gridH > 160) {
    final usable = w - 32;
    final targetCardH = gridH / 1.55;
    final targetCardW = targetCardH * aspect;
    final byHeight = ((usable + spacing) / (targetCardW + spacing)).floor();
    cols = math.max(cols, byHeight);
  }
  return cols.clamp(3, 10);
}

/// 网格卡片：封面 + 书名 + 作者（书架/发现页通用）
///
/// 旋钮/方向键聚焦时描一圈品牌色外框，车机上能看清当前选中项。
class BookGridItem extends StatefulWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? badge;

  const BookGridItem({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.badge,
  });

  @override
  State<BookGridItem> createState() => _BookGridItemState();
}

class _BookGridItemState extends State<BookGridItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? AppTheme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (v) {
          if (mounted && v != _focused) setState(() => _focused = v);
        },
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover(url: book.pic),
                  if (widget.badge != null)
                    Positioned(bottom: 6, right: 6, child: widget.badge!),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.cleanTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMain,
                // 深色/浅色主题下都压一层极淡的阴影，保证在壁纸、渐变底上也能看清
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(
                      alpha: AppTheme.isDark ? 0.5 : 0.14,
                    ),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMain.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表行：横向封面 + 信息（搜索/书架详情列表）
///
/// 同样带焦点描边，遥控器上下移动时高亮可见。
class BookListTile extends StatefulWidget {
  final Book book;
  final VoidCallback onTap;
  final String? subtitle;
  final String? trailing;

  const BookListTile({
    super.key,
    required this.book,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  State<BookListTile> createState() => _BookListTileState();
}

class _BookListTileState extends State<BookListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? AppTheme.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (v) {
          if (mounted && v != _focused) setState(() => _focused = v);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              BookCover(url: book.pic, width: 96, height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          book.pages > 1
                              ? Icons.library_books_outlined
                              : Icons.menu_book_outlined,
                          size: 14,
                          color: AppTheme.textSub,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.subtitle ??
                              '${book.pages} 章 · ${book.durationText}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    widget.trailing!,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSub),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放量标签（放在封面角落）
class PlayBadge extends StatelessWidget {
  final int play;
  const PlayBadge({super.key, required this.play});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
          Text(
            Fmt.count(play),
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
