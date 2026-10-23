import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/game_host.dart';

/// 게임 플레이 화면.
///
/// 크롬북(넓은 가로 화면)을 1순위로 고려합니다.
/// - [immersive] 가 true 이면 앱바/하단바 없이 게임만 꽉 채웁니다 (전체화면).
/// - 게임은 카탈로그의 비율(aspect)을 유지하며, 남는 공간은 배경으로 채웁니다.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.game, this.immersive = false});

  final GameInfo game;
  final bool immersive;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// 전체화면 상단 바 높이 (iframe 과 겹치지 않게 확보하는 영역)
const double _kImmersiveBarHeight = 44;

class _GameScreenState extends State<GameScreen> {
  final GameHostController _controller = GameHostController();
  int _reloadToken = 0;
  int _liveScore = 0;
  bool _saved = false;
  late bool _immersive = widget.immersive;

  @override
  void initState() {
    super.initState();
    _liveScore = context.read<AppState>().progressFor(widget.game.id).bestScore;
  }

  void _onGameEvent(String gameId, Object? event) {
    final AppState state = context.read<AppState>();

    if (event is Map && event['type'] == 'saveCode') {
      final Object? code = event['code'];
      if (code is String && code.isNotEmpty) {
        state.storeGameCode(gameId: gameId, code: code).then((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              const SnackBar(
                duration: Duration(seconds: 2),
                content: Text('기록 코드를 계정에 보관했어요'),
              ),
            );
        });
      }
      return;
    }

    if (event is Map && event['type'] == 'requestCode') {
      final String saved = state.gameCodeFor(gameId);
      if (saved.isNotEmpty) {
        _controller.send(<String, dynamic>{
          'type': 'saveCode',
          'code': saved,
          'label': '보관된 기록',
        });
      }
      return;
    }

    final ProgressEvent? parsed = ProgressEvent.tryParse(event);
    if (parsed == null) return;

    final int? score = parsed.score;
    if (score != null && score > _liveScore) {
      setState(() => _liveScore = score);
    }

    if (parsed.state != null || parsed.isGameOver || score != null) {
      state
          .applyProgress(gameId: gameId, event: parsed)
          .then((GameProgress p) {
            if (!mounted) return;
            if (parsed.isGameOver) {
              setState(() => _saved = true);
              _toastSaved(p.bestScore);
            }
          });
    }
  }

  void _toastSaved(int best) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: <Widget>[
            const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text('기록 저장됨 · ${widget.game.bestScoreLabel} $best'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndExit() async {
    final AppState state = context.read<AppState>();
    _controller.pause();
    await state.applyProgress(
      gameId: widget.game.id,
      event: ProgressEvent(
        score: _liveScore,
        state: state.progressFor(widget.game.id).state,
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GameProgress progress = context.watch<AppState>().progressFor(
      widget.game.id,
    );

    final Widget host = GameHost(
      gameId: widget.game.id,
      entry: widget.game.entry,
      controller: _controller,
      onEvent: _onGameEvent,
      initialScore: progress.bestScore,
      initialState: progress.state,
      savedCode: progress.saveCode,
      reloadToken: _reloadToken,
    );

    // ── 전체화면(몰입) 모드 ─────────────────────────────────────
    if (_immersive) {
      return PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          _saveAndExit();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0E1116),
          body: SafeArea(
            // ⚠️ 웹에서 iframe(HtmlElementView)은 Flutter 위젯보다 항상 위에 그려진다.
            //    Stack 으로 겹쳐 놓으면 버튼이 iframe 에 가려 클릭이 먹힌다
            //    (전체화면에서 나가지 못하던 버그).
            //    → iframe 을 컨트롤 높이만큼 아래로 밀어 '겹치지 않게' 만든다.
            child: Column(
              children: <Widget>[
                Container(
                  height: _kImmersiveBarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: const Color(0xFF12161C),
                  child: Row(
                    children: <Widget>[
                      _FloatingControls(
                        best: progress.bestScore,
                        label: widget.game.bestScoreLabel,
                        onReload: () => setState(() => _reloadToken++),
                        onExit: _saveAndExit,
                        onShrink: () => setState(() => _immersive = false),
                      ),
                      const Spacer(),
                      Text(
                        widget.game.title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _GameStage(game: widget.game, child: host)),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _saveAndExit();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: widget.game.accentColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sports_esports_rounded,
                  size: 15,
                  color: widget.game.accentColor,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  widget.game.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 13,
                      color: AppColors.brandDeep,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${progress.bestScore}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: '전체화면',
              iconSize: 20,
              onPressed: () => setState(() => _immersive = true),
              icon: const Icon(Icons.fullscreen_rounded),
            ),
            IconButton(
              tooltip: '다시 시작',
              iconSize: 19,
              onPressed: () => setState(() => _reloadToken++),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: '나가기',
              iconSize: 20,
              onPressed: _saveAndExit,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: _GameStage(game: widget.game, child: host),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 4, 12, 10),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _saved
                          ? Icons.check_circle_outline_rounded
                          : Icons.sync_rounded,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _saved ? '자동 저장됨' : '플레이 중 자동 저장돼요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saveAndExit,
                      icon: const Icon(Icons.logout_rounded, size: 15),
                      label: const Text('저장하고 나가기'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
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

/// 전체화면 모드에서 쓰는 떠 있는 컨트롤
class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.best,
    required this.label,
    required this.onReload,
    required this.onExit,
    required this.onShrink,
  });

  final int best;
  final String label;
  final VoidCallback onReload;
  final VoidCallback onExit;
  final VoidCallback onShrink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 13,
                  color: Color(0xFF6FE3AE),
                ),
                const SizedBox(width: 4),
                Text(
                  '$best',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _FloatingButton(
            icon: Icons.fullscreen_exit_rounded,
            tooltip: '창 모드',
            onTap: onShrink,
          ),
          _FloatingButton(
            icon: Icons.refresh_rounded,
            tooltip: '다시 시작',
            onTap: onReload,
          ),
          _FloatingButton(
            icon: Icons.close_rounded,
            tooltip: '나가기',
            onTap: onExit,
          ),
        ],
      ),
    );
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// 게임 비율을 유지하는 무대.
///
/// 부모가 줄 수 있는 최대 크기 안에서 [GameInfo.aspectRatio] 를 만족하는
/// 가장 큰 사각형을 계산합니다. 크롬북처럼 넓은 화면에서는 최대한 크게,
/// 모바일에서는 화면 폭에 맞춰 자동으로 줄어듭니다.
class _GameStage extends StatelessWidget {
  const _GameStage({required this.game, required this.child});

  final GameInfo game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = game.aspectRatio;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double width = constraints.maxWidth;
        double height = width / ratio;

        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }

        if (width.isNaN || width <= 0 || height.isNaN || height <= 0) {
          width = constraints.maxWidth;
          height = constraints.maxHeight;
        }

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
