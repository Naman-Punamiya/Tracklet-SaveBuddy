import 'package:flutter/material.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';

class PendingDeletionBanner extends StatelessWidget {
  final int count;
  final bool isRetrying;
  final VoidCallback onRetry;

  const PendingDeletionBanner({
    super.key,
    required this.count,
    required this.isRetrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String label = count == 1
        ? "Deletion waiting to sync"
        : "$count deletions waiting to sync";

    final bgColor = isDark
        ? const Color(0xFF292524)
        : const Color(0xFFFFFBEB);
    final borderColor = isDark
        ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
        : const Color(0xFFFDE68A);
    final iconColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final textColor = isDark ? AppColors.textWhite : const Color(0xFF92400E);
    final actionColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: isRetrying ? null : onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isRetrying
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: actionColor,
                    ),
                  )
                : Text(
                    "Retry sync",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: actionColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
