import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookListSkeleton extends StatefulWidget {
  final int itemCount;
  final bool animate;

  const BookListSkeleton({
    super.key,
    this.itemCount = 4,
    this.animate = true,
  });

  @override
  State<BookListSkeleton> createState() => _BookListSkeletonState();
}

class _BookListSkeletonState extends State<BookListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSkeletonCard(bool isDark) {
    final baseColor = isDark ? AppColors.darkCard : Colors.white;
    final placeholderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final subtlePlaceholder = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(
                color: AppColors.borderDark.withValues(alpha: 0.7),
              )
            : null,
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Monogram avatar placeholder (52x52 rounded square)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: subtlePlaceholder,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 16),
          // Book Title and Subtitle placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 18,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 75,
                  height: 12,
                  decoration: BoxDecoration(
                    color: subtlePlaceholder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          // Balance amount placeholder
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final list = ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: widget.itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSkeletonCard(isDark),
    );

    if (!widget.animate) {
      return Opacity(opacity: 0.6, child: list);
    }

    return FadeTransition(
      opacity: _animation,
      child: list,
    );
  }
}
