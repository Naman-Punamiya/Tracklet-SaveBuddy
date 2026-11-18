import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CustomCard extends StatefulWidget {
  final IconData leadingIcon;
  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final Function()? onTap;
  const CustomCard({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
    this.onTap,
  });

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDark
                ? Border.all(color: AppColors.borderDark)
                : null,
            boxShadow: isDark
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0C000000), // ~5% opacity soft shadow
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primaryAccent.withValues(alpha: 0.16)
                    : const Color(0xFFE8F6F3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.leadingIcon,
                color: isDark ? AppColors.primaryAccent : const Color(0xFF3EAD91),
                size: 24,
              ),
            ),
            title: Text(
              widget.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.textPrimaryDark : Colors.grey.shade900,
              ),
            ),
            subtitle: Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
              ),
            ),
            trailing: Icon(
              widget.trailingIcon,
              color: isDark ? AppColors.textMuted : Colors.grey.shade400,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
