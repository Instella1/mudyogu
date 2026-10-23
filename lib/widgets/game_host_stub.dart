import 'package:flutter/material.dart';

/// 웹이 아닌 플랫폼용 더미 컨트롤러
class GameHostController {
  void send(Map<String, dynamic> message) {}
  void pause() {}
  void resume() {}
  void requestState(Map<String, dynamic> state) {}
  bool get isReady => false;
  // ignore: unused_element
  void _attach(void Function(Map<String, dynamic>) sender, bool ready) {}
}

/// 웹이 아닌 플랫폼(모바일 APK 등)에서의 폴백.
/// HTML5 게임은 웹뷰/애셋 서버가 필요하므로 웹 빌드에서 사용합니다.
class GameHost extends StatelessWidget {
  const GameHost({
    super.key,
    required this.gameId,
    required this.entry,
    required this.onEvent,
    required this.initialState,
    this.initialScore = 0,
    this.savedCode = '',
    this.controller,
    this.reloadToken = 0,
  });

  final String gameId;
  final String entry;
  final void Function(String gameId, Object? event) onEvent;
  final Map<String, dynamic> initialState;
  final int initialScore;
  final String savedCode;
  final GameHostController? controller;
  final int reloadToken;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '이 게임은 웹 버전에서 플레이할 수 있어요.\n(브라우저에서 열어 주세요)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
