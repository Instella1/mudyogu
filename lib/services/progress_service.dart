import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/account.dart';
import 'local_store.dart';

/// 진행상황 저장/병합 서비스 (순수 로직, 알림은 상위 컨트롤러가 담당).
///
/// - 게스트 진행은 `progress_guest` 에 저장
/// - 로그인 시 계정 박스로 **병합**(최신 우선, 최고점은 max)
class ProgressService {
  ProgressService(this._store);

  final LocalStore _store;
  Box<dynamic>? _box;
  String? _owner;
  final Map<String, GameProgress> _cache = <String, GameProgress>{};

  String? get owner => _owner;
  Map<String, GameProgress> get all =>
      Map<String, GameProgress>.unmodifiable(_cache);

  GameProgress progressFor(String gameId) =>
      _cache[gameId] ?? GameProgress.initial(gameId);

  // ── 저장 코드 미러 ───────────────────────────────────────────
  // 진행 박스(progress_*) 는 웹에서 간혐 열리지 않아 `Box not found` 가 난다.
  // 저장 코드는 사용자가 직접 만든 기록이라 절대 잃으면 안 되므로,
  // 항상 열려 있는 `settings` 박스에도 같이 보관한다.
  static const String _mirrorPrefix = 'saveCode::';

  String _mirrorKey(String gameId) => '$_mirrorPrefix$gameId';

  void _mirrorWrite(String gameId, String code, DateTime at) {
    try {
      _store.settings.put(_mirrorKey(gameId), <String, dynamic>{
        'code': code,
        'at': at.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[progress] 코드 미러 저장 실패: $e');
    }
  }

  void _mirrorClear(String gameId) {
    try {
      _store.settings.delete(_mirrorKey(gameId));
    } catch (e) {
      debugPrint('[progress] 코드 미러 삭제 실패: $e');
    }
  }

  /// 진행 박스에 코드가 없을 때 미러 값을 되살린다.
  void _applyMirrors(Map<String, GameProgress> out) {
    try {
      for (final dynamic key in _store.settings.keys) {
        if (key is! String || !key.startsWith(_mirrorPrefix)) continue;
        final String gameId = key.substring(_mirrorPrefix.length);
        final Object? raw = _store.settings.get(key);
        if (raw is! Map) continue;
        final String code = (raw['code'] ?? '').toString();
        if (code.isEmpty) continue;
        final GameProgress current =
            out[gameId] ?? GameProgress.initial(gameId);
        if (current.saveCode.isNotEmpty) continue;
        out[gameId] = current.copyWith(
          saveCode: code,
          saveCodeAt: DateTime.tryParse((raw['at'] ?? '').toString()),
        );
      }
    } catch (e) {
      debugPrint('[progress] 코드 미러 복구 실패: $e');
    }
  }

  Future<void> load() async {
    _owner = _store.session.get('email') as String?;
    _box = await _store.openProgress(_owner);
    _cache
      ..clear()
      ..addAll(_readAll());
  }

  Map<String, GameProgress> _readAll() {
    final Map<String, GameProgress> out = <String, GameProgress>{};
    final Box<dynamic>? box = _box;
    if (box != null) {
      try {
        for (final dynamic key in box.keys) {
          final Object? raw = box.get(key);
          if (raw is Map) {
            final GameProgress p = GameProgress.fromMap(raw);
            if (p.gameId.isNotEmpty) out[p.gameId] = p;
          }
        }
      } catch (e) {
        debugPrint('[progress] 진행 박스 읽기 실패: $e');
      }
    }
    _applyMirrors(out);
    return out;
  }

  /// 로그인/로그아웃 시 호출: 진행 박스를 소유자에 맞춰 교체
  Future<void> rebind(String? email) async {
    _box = await _store.openProgress(email);
    _owner = email;
    _cache
      ..clear()
      ..addAll(_readAll());
  }

  /// 게스트 → 계정 병합: 최신 우선, 최고점은 max, 플레이수는 합산
  Future<int> mergeGuestInto(String email) async {
    final Box<dynamic> guestBox = _store.guest;
    if (guestBox.isEmpty) return 0;

    final Box<dynamic> target = await _store.openProgress(email);
    final Map<String, GameProgress> merged = <String, GameProgress>{};

    for (final dynamic key in target.keys) {
      final Object? raw = target.get(key);
      if (raw is Map) {
        final GameProgress p = GameProgress.fromMap(raw);
        if (p.gameId.isNotEmpty) merged[p.gameId] = p;
      }
    }

    int count = 0;
    for (final dynamic key in guestBox.keys) {
      final Object? raw = guestBox.get(key);
      if (raw is! Map) continue;
      final GameProgress guest = GameProgress.fromMap(raw);
      if (guest.gameId.isEmpty) continue;

      final GameProgress? local = merged[guest.gameId];
      if (local == null) {
        merged[guest.gameId] = guest;
      } else {
        final bool guestNewer = guest.updatedAt.isAfter(local.updatedAt);
        merged[guest.gameId] = GameProgress(
          gameId: guest.gameId,
          bestScore: guest.bestScore > local.bestScore
              ? guest.bestScore
              : local.bestScore,
          playCount: local.playCount + guest.playCount,
          playSeconds: local.playSeconds + guest.playSeconds,
          updatedAt: guestNewer ? guest.updatedAt : local.updatedAt,
          state: guestNewer ? guest.state : local.state,
          saveCode: guest.saveCode.isNotEmpty ? guest.saveCode : local.saveCode,
          saveCodeAt: guest.saveCodeAt ?? local.saveCodeAt,
        );
      }
      count++;
    }

    for (final GameProgress p in merged.values) {
      await target.put(p.gameId, p.toMap());
    }
    await guestBox.clear();

    _box = target;
    _owner = email;
    _cache
      ..clear()
      ..addAll(merged);
    return count;
  }

  /// 게임에서 올라온 진행 이벤트 반영
  Future<GameProgress> apply({
    required String gameId,
    ProgressEvent? event,
    bool countAsPlay = false,
  }) async {
    final GameProgress current = progressFor(gameId);
    final DateTime now = DateTime.now();

    GameProgress next = current.copyWith(updatedAt: now);

    if (countAsPlay) {
      next = next.copyWith(playCount: current.playCount + 1);
    }
    if (event != null) {
      final int? score = event.score;
      if (score != null && score > current.bestScore) {
        next = next.copyWith(bestScore: score);
      }
      final Map<String, dynamic>? state = event.state;
      if (state != null) {
        next = next.copyWith(state: state);
      }
      final int? secs = event.playSeconds;
      if (secs != null && secs > 0) {
        next = next.copyWith(playSeconds: current.playSeconds + secs);
      }
    }

    _cache[gameId] = next;
    await _put(gameId, next.toMap());
    return next;
  }

  /// 최고 기록만 0 으로 (게임 안 '최고 기록 초기화' 요청). 나머지 진행은 그대로.
  Future<GameProgress> resetBest(String gameId) async {
    final GameProgress next = progressFor(
      gameId,
    ).copyWith(bestScore: 0, updatedAt: DateTime.now());
    _cache[gameId] = next;
    await _put(gameId, next.toMap());
    return next;
  }

  Future<void> reset(String gameId) async {
    _cache.remove(gameId);
    _mirrorClear(gameId);
    final Box<dynamic>? box = await _ensureBox();
    try {
      await box?.delete(gameId);
    } catch (e) {
      debugPrint('[progress] 진행 삭제 실패: $e');
    }
  }

  /// 세션에서 소유자를 다시 읽는다.
  ///
  /// 로그인/로그아웃이 진행 중이면 `_owner` 캐시가 실제 세션과 어긋날 수 있어서
  /// 저장 직전에는 세션 값을 신뢰한다.
  String? _sessionOwner() {
    try {
      final Object? email = _store.session.get('email');
      return (email is String && email.isNotEmpty) ? email : null;
    } catch (e) {
      debugPrint('[progress] 세션 읽기 실패: $e');
      return _owner;
    }
  }

  /// 박스가 닫혔거나 없으면 다시 연다.
  ///
  /// 웹에서 Hive 박스가 어떤 이유로 닫히면 `Box not found` 예외가 나면서
  /// 저장이 조용히 실패한다. 저장 직전에 항상 새로 확인해 준다.
  Future<Box<dynamic>?> _ensureBox() async {
    // Hive 초기화 전에 호출되면 모든게 실패한다. init() 은 idempotent.
    try {
      await _store.init();
    } catch (e) {
      debugPrint('[progress] 스토어 초기화 실패: $e');
    }
    final String? owner = _sessionOwner();
    final String name = LocalStore.progressBoxName(owner);
    try {
      final Box<dynamic> box = await _store.openProgress(owner);
      _box = box;
      _owner = owner;
      return box;
    } catch (e) {
      debugPrint('[progress] 박스 열기 실패($name): $e');
    }
    // 2차 시도: 이름으로 직접 연다.
    try {
      final Box<dynamic> box = Hive.isBoxOpen(name)
          ? Hive.box<dynamic>(name)
          : await Hive.openBox<dynamic>(name);
      _box = box;
      _owner = owner;
      return box;
    } catch (e) {
      debugPrint('[progress] 박스 직접 열기 실패($name): $e');
      return null;
    }
  }

  /// 어떤 이유로 실패해도 재시도하는 쓰기.
  ///
  /// 웹에서 첫 시도가 `Box not found` 로 튕기는 사례가 있어 3회까지 재시도한다.
  Future<bool> _put(String gameId, Map<String, dynamic> data) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final Box<dynamic>? box = await _ensureBox();
      if (box != null) {
        try {
          await box.put(gameId, data);
          return true;
        } catch (e) {
          debugPrint('[progress] 저장 실패(${attempt + 1}/3): $e');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return false;
  }

  /// 게임이 만든 저장 코드를 보관합니다.
  Future<GameProgress> storeCode(String gameId, String code) async {
    final GameProgress current = progressFor(gameId);
    final GameProgress next = current.copyWith(
      saveCode: code,
      saveCodeAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _cache[gameId] = next;
    _mirrorWrite(gameId, code, next.saveCodeAt ?? DateTime.now());
    final bool ok = await _put(gameId, next.toMap());
    debugPrint('[progress] 저장 코드 기록 ${ok ? '성공' : '실패(미러만)'} '
        '($gameId, ${code.length}자)');
    return next;
  }

  /// 보관 중인 저장 코드 조회 (없으면 빈 문자열)
  String codeFor(String gameId) => progressFor(gameId).saveCode;

  Future<void> resetAll() async {
    _cache.clear();
    final Box<dynamic>? box = await _ensureBox();
    try {
      await box?.clear();
    } catch (e) {
      debugPrint('[progress] 전체 삭제 실패: $e');
    }
    try {
      for (final dynamic key in _store.settings.keys.toList()) {
        if (key is String && key.startsWith(_mirrorPrefix)) {
          await _store.settings.delete(key);
        }
      }
    } catch (e) {
      debugPrint('[progress] 코드 미러 전체 삭제 실패: $e');
    }
  }

  String get boxName => _box?.name ?? '-';

  @visibleForTesting
  int get cachedCount => _cache.length;
}
