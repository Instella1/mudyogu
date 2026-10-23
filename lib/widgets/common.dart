import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 파스텔 톤의 부드러운 배경 (앱 전체 톤앤매너)
class PastelBackdrop extends StatelessWidget {
  const PastelBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const <Color>[
                        Color(0xFF0E1311),
                        Color(0xFF101A16),
                        Color(0xFF0C1210),
                      ]
                    : const <Color>[
                        Color(0xFFF7FCF9),
                        Color(0xFFF2FAF6),
                        Color(0xFFFAF8FF),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -90,
          child: _Blob(
            color: AppColors.brand.withValues(alpha: isDark ? 0.14 : 0.22),
            size: 300,
          ),
        ),
        Positioned(
          top: 120,
          left: -130,
          child: _Blob(
            color: AppColors.lavender.withValues(alpha: isDark ? 0.10 : 0.20),
            size: 260,
          ),
        ),
        Positioned(
          bottom: -140,
          right: -60,
          child: _Blob(
            color: AppColors.sky.withValues(alpha: isDark ? 0.08 : 0.18),
            size: 280,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// 섹션 제목
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 얇은 구분선
class SoftDivider extends StatelessWidget {
  const SoftDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: Theme.of(context).dividerColor,
    );
  }
}
