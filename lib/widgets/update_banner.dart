import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 새 버전이 있을 때 상단에 표시하는 배너
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({
    super.key,
    required this.onUpdate,
    this.onDismiss,
    this.version,
  });

  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;
  final String? version;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.brand.withValues(alpha: 0.16)
            : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Color(0xFF06301F),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '새 버전이 준비됐어요',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (version != null)
                  Text(
                    'v$version · 지금 새로고침하면 적용돼요',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUpdate,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('새로고침'),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded),
              tooltip: '나중에',
            ),
        ],
      ),
    );
  }
}

/// 오프라인 준비 완료 배지
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: ready
            ? AppColors.brand.withValues(alpha: 0.14)
            : theme.dividerColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            ready ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 12,
            color: ready ? AppColors.brandDeep : null,
          ),
          const SizedBox(width: 5),
          Text(
            ready ? '오프라인 준비됨' : '오프라인 준비 중',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ready
                  ? AppColors.brandDeep
                  : theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
