import 'package:flutter/material.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// 게임 카드
class GameCard extends StatefulWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.state,
    required this.onTap,
    this.index = 0,
  });

  final GameInfo game;
  final AppState state;
  final VoidCallback onTap;
  final int index;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final GameProgress progress = widget.state.progressFor(widget.game.id);
    final bool played = progress.playCount > 0;
    final Color accent = widget.game.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.55)
                  : theme.dividerColor,
              width: _hover ? 1.4 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isDark ? Colors.black : accent).withValues(
                  alpha: _hover ? (isDark ? 0.45 : 0.16) : (isDark ? 0.25 : 0.06),
                ),
                blurRadius: _hover ? 22 : 12,
                offset: Offset(0, _hover ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 썸네일 영역
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(21),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              accent.withValues(alpha: isDark ? 0.32 : 0.30),
                              accent.withValues(alpha: isDark ? 0.10 : 0.08),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: _GameGlyph(
                          game: widget.game,
                          size: 46,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.92)
                              : const Color(0xFF0E2419),
                        ),
                      ),
                      if (played)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.42)
                                  : Colors.white.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 11,
                                  color: AppColors.brandDeep,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${progress.bestScore}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 텍스트 영역
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.game.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameGlyph extends StatelessWidget {
  const _GameGlyph({required this.game, required this.size, required this.color});

  final GameInfo game;
  final double size;
  final Color color;

  static const Map<String, IconData> _icons = <String, IconData>{
    'hanilnam-life': Icons.sports_soccer_rounded,
    'haniljeon': Icons.sports_martial_arts_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final IconData icon = _icons[game.id] ?? Icons.sports_esports_rounded;
    return Icon(icon, size: size, color: color);
  }
}
