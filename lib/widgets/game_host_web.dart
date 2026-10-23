import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 게임 iframe 과 메시지를 주고받기 위한 컨트롤러.
class GameHostController {
  void Function(Map<String, dynamic> message)? _sender;
  bool _ready = false;

  bool get isReady => _ready;

  /// 호스트 → 게임 메시지 전송
  void send(Map<String, dynamic> message) {
    _sender?.call(message);
  }

  void pause() => send(<String, dynamic>{'type': 'pause'});
  void resume() => send(<String, dynamic>{'type': 'resume'});
  void requestState(Map<String, dynamic> state) =>
      send(<String, dynamic>{'type': 'state', 'state': state});

  void _attach(void Function(Map<String, dynamic>) sender, bool ready) {
    _sender = sender;
    _ready = ready;
  }
}

/// HTML5 게임을 iframe 으로 탑재하고, postMessage 로 진행상황을 주고받습니다.
///
/// 게임 쪽 규약 (아주 단순):
/// ```js
/// // 1) 준비 완료 알림
/// parent.postMessage({ mudyogu: TOKEN, type: 'ready' }, '*');
///
/// // 2) 진행상황 전송
/// parent.postMessage({
///   mudyogu: TOKEN, type: 'progress',
///   score: 120, state: { level: 3 }, playSeconds: 12, isGameOver: true
/// }, '*');
///
/// // 3) 호스트 → 게임 메시지 수신
/// window.addEventListener('message', (e) => {
///   if (e.data?.type === 'init') { /* e.data.state 로 복원 */ }
/// });
/// ```
class GameHost extends StatefulWidget {
  const GameHost({
    super.key,
    required this.gameId,
    required this.entry,
    required this.onEvent,
    required this.initialState,
    this.controller,
    this.initialScore = 0,
    this.savedCode = '',
    this.reloadToken = 0,
  });

  final String gameId;
  final String entry;
  final void Function(String gameId, Object? event) onEvent;
  final Map<String, dynamic> initialState;
  final GameHostController? controller;
  final int initialScore;

  /// 앱이 보관 중인 저장 코드(있으면 게임에 자동으로 넘겨 복원시킵니다).
  final String savedCode;
  final int reloadToken;

  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost> {
  static int _seq = 0;

  late final String _viewType = 'mud-game-${_seq++}';
  late final String _token = _makeToken();

  web.HTMLIFrameElement? _iframe;
  JSFunction? _listener;
  bool _gameReady = false;

  static String _makeToken() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    return 'mud$stamp${(_seq * 7919) % 9973}';
  }

  String get _src {
    final Uri base = Uri.base;
    final String path = widget.entry.startsWith('/')
        ? widget.entry.substring(1)
        : widget.entry;
    final Uri resolved = base.resolve(path);
    return resolved
        .replace(
          queryParameters: <String, String>{
            ...resolved.queryParameters,
            'mudToken': _token,
            'mudEmbed': '1',
          },
        )
        .toString();
  }

  @override
  void initState() {
    super.initState();
    _createIframe();
    _listenWindow();
    widget.controller?._attach(_sendToGame, false);
  }

  void _createIframe() {
    final web.HTMLIFrameElement iframe = web.HTMLIFrameElement()
      ..src = _src
      ..title = widget.gameId;

    iframe.style
      ..border = 'none'
      ..width = '100%'
      ..height = '100%'
      ..display = 'block'
      ..backgroundColor = 'transparent';
    iframe.setAttribute('allowfullscreen', 'true');
    iframe.setAttribute('allow', 'fullscreen; autoplay; clipboard-write');
    // ⚠️ scrolling="no" 를 넣지 말 것. 한(일)남 LIFE 처럼 아래로 내려가며 보는 게임이
    //    스크롤이 안 돼서 아래가 통째로 잘린다. 스크롤을 막아야 하는 게임은
    //    게임 쪽 CSS(body { overflow: hidden })로 막는다 (한일전이 그렇게 함).

    _iframe = iframe;
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => iframe,
    );
  }

  void _listenWindow() {
    final JSFunction fn = ((JSAny? rawEvent) {
      if (rawEvent == null || !rawEvent.isA<web.MessageEvent>()) return;
      final web.MessageEvent event = rawEvent as web.MessageEvent;

      // 같은 출처(같은 빌드 결과물)에서 온 메시지만 처리
      final String origin = event.origin;
      if (origin.isNotEmpty && !origin.contains(Uri.base.host)) return;

      final Object? data = event.data.dartify();
      if (data is! Map) return;
      final Map<Object?, Object?> map = data;
      if (map['mudyogu'] != _token) return;

      final Object? type = map['type'];
      if (type == 'ready') {
        _gameReady = true;
        widget.controller?._attach(_sendToGame, true);
        _sendToGame(<String, dynamic>{
          'type': 'init',
          'state': widget.initialState,
          'bestScore': widget.initialScore,
          'savedCode': widget.savedCode,
        });
        // 보관 중인 저장 코드가 있으면 init 직후에 한 번 더 밀어 넣는다.
        // (게임이 init 만 듣고 코드는 별도로 기다리는 경우를 대비)
        if (widget.savedCode.isNotEmpty) {
          _sendToGame(<String, dynamic>{
            'type': 'saveCode',
            'code': widget.savedCode,
            'label': '보관된 기록',
          });
          // 게임 스크립트 초기화가 늦는 경우를 위해 한 번 더 재전송
          Future<void>.delayed(const Duration(milliseconds: 700), () {
            if (!mounted) return;
            _sendToGame(<String, dynamic>{
              'type': 'saveCode',
              'code': widget.savedCode,
              'label': '보관된 기록',
            });
          });
        }
        setState(() {});
        return;
      }

      widget.onEvent(widget.gameId, map);
    }).toJS;

    _listener = fn;
    web.window.addEventListener('message', fn);
  }

  void _sendToGame(Map<String, dynamic> message) {
    final web.Window? child = _iframe?.contentWindow;
    if (child == null) return;

    try {
      child.postMessage(
        message.jsify(),
        web.window.location.origin.toJS,
      );
    } catch (_) {
      // origin 불일치(개발용 프리뷰 등) 시 와일드카드 재시도
      try {
        child.postMessage(message.jsify(), '*'.toJS);
      } catch (_) {
        // 무시
      }
    }
  }

  @override
  void didUpdateWidget(covariant GameHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken && _iframe != null) {
      _gameReady = false;
      widget.controller?._attach(_sendToGame, false);
      _iframe!.src = _src;
    }
  }

  @override
  void dispose() {
    final JSFunction? fn = _listener;
    if (fn != null) {
      web.window.removeEventListener('message', fn);
    }
    _iframe?.remove();
    _iframe = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),
        if (!_gameReady)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(height: 14),
                    Text('게임을 불러오는 중이에요'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
