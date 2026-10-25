import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// 게임들이 쓰는 브라우저 localStorage 를 통째로 읽고 쓴다.
///
/// 게임(iframe)은 앱과 같은 주소라 localStorage 를 같이 쓴다. 게임마다 키가 제각각이라
/// 하나하나 알 필요 없이 'flutter.' 로 시작하지 않는 키 = 게임 기록으로 본다.
/// (앱 자신의 기록은 Hive(IndexedDB) 와 shared_preferences('flutter.' 접두사) 에 있다)
class GameStorage {
  const GameStorage();

  static bool _isGameKey(String k) => !k.startsWith('flutter.');

  Map<String, String> readAll() {
    final Map<String, String> out = <String, String>{};
    try {
      final web.Storage s = web.window.localStorage;
      for (int i = 0; i < s.length; i++) {
        final String? k = s.key(i);
        if (k == null || !_isGameKey(k)) continue;
        final String? v = s.getItem(k);
        if (v != null) out[k] = v;
      }
    } catch (_) {}
    return out;
  }

  /// 게임 키를 모두 지우고 [data] 로 채운다 (계정 전환).
  void replaceAll(Map<String, String> data) {
    try {
      final web.Storage s = web.window.localStorage;
      final List<String> old = <String>[];
      for (int i = 0; i < s.length; i++) {
        final String? k = s.key(i);
        if (k != null && _isGameKey(k)) old.add(k);
      }
      for (final String k in old) {
        s.removeItem(k);
      }
      data.forEach((String k, String v) {
        if (_isGameKey(k)) s.setItem(k, v);
      });
    } catch (_) {}
  }

  void onHidden(void Function() callback) {
    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'hidden') callback();
      }).toJS,
    );
  }
}
