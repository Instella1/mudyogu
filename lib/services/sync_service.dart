import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/account.dart';
import 'auth_service.dart';
import 'cloud_service.dart';
import 'game_storage.dart';
import 'local_store.dart';
import 'progress_service.dart';

/// 계정별 게임 기록 보관 + 온라인 동기화.
///
/// 게임들은 기록을 브라우저 localStorage 에 직접 쓴다 (원본 게임 코드). localStorage 는 기기에
/// 하나뿐이라, 예전엔 계정을 바꿔도 게임 기록이 그대로 남았다 (새 계정에 원래 계정 기록이 보이던 버그).
/// → 계정을 바꿀 때 지금 기록을 그 계정 보관함(vault)에 넣고, 새 계정의 기록으로 바꿔 끼운다.
/// → 로그인된 계정은 기록 묶음을 Supabase(mud_saves)에도 올려, 다른 기기에서 로그인하면 이어진다.
///
/// 기록 묶음: { v, at, ls: {localStorage 키: 값}, progress: {gameId: GameProgress} }
class SyncService {
  SyncService(
    this._store,
    this._auth,
    this._progress,
    this._cloud,
    this._games,
  );

  final LocalStore _store;
  final AuthService _auth;
  final ProgressService _progress;
  final CloudService _cloud;
  final GameStorage _games;

  Timer? _pushTimer;
  bool _pushing = false;

  /// 마지막 동기화 문제 (설정 화면 안내용). null 이면 정상
  CloudError? lastError;
  DateTime? lastSyncedAt;

  Box<dynamic> get _vault => _store.vault;
  Box<dynamic> get _settings => _store.settings;

  static String _key(String? owner) => ProgressService.ownerKey(owner);

  // ── 기록 묶음 ───────────────────────────────────────────────
  Map<String, dynamic> capture() => <String, dynamic>{
    'v': 1,
    'at': DateTime.now().toUtc().toIso8601String(),
    'ls': _games.readAll(),
    'progress': _progress.exportAll(),
  };

  /// 지금 기록을 [owner] 보관함에 넣는다
  Future<void> stash(String? owner) async {
    try {
      await _vault.put(_key(owner), capture());
    } catch (e) {
      debugPrint('[sync] 보관 실패: $e');
    }
  }

  Map<String, dynamic>? _local(String? owner) {
    final Object? raw = _vault.get(_key(owner));
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  /// 기록 묶음을 화면에 적용 (localStorage 교체 + 진행상황 교체).
  /// progress 가 없는 묶음(옛 기록 이전용)은 진행상황 박스를 건드리지 않는다.
  Future<void> _apply(Map<String, dynamic>? blob) async {
    final Map<String, String> ls = <String, String>{};
    final Object? rawLs = blob?['ls'];
    if (rawLs is Map) {
      rawLs.forEach((dynamic k, dynamic v) {
        if (k is String && v != null) ls[k] = v.toString();
      });
    }
    _games.replaceAll(ls);
    final Object? prog = blob?['progress'];
    if (prog is Map) {
      await _progress.replaceAll(Map<String, dynamic>.from(prog));
    }
  }

  static DateTime _at(Map<String, dynamic>? blob) =>
      DateTime.tryParse((blob?['at'] ?? '').toString()) ?? DateTime(2000);

  // ── 계정 전환 ───────────────────────────────────────────────
  /// 로그인/가입/로그아웃 '직전'에 호출: 지금 계정 기록을 보관하고 온라인에도 올린다.
  Future<void> beforeSwitch() async {
    _pushTimer?.cancel();
    await stash(_progress.owner);
    await pushNow();
  }

  /// 로그인/가입/로그아웃 '직후'에 호출: 새 계정의 기록으로 바꿔 끼운다.
  /// [carry] 가 true 면 지금 화면의 기록(게스트로 하던 것)을 새 계정이 그대로 가져간다 (새로 가입할 때).
  Future<void> afterSwitch(
    String? owner, {
    bool carry = false,
    bool migrated = false,
  }) async {
    await _progress.rebind(owner);
    if (carry) {
      // 게스트 → 새 계정: 화면의 기록을 그대로 새 계정 것으로
      await _vault.delete(_key(null));
      await stash(owner);
      await pushNow();
      return;
    }
    Map<String, dynamic>? blob = _local(owner);
    final CloudSession? s = await _auth.freshCloudSession();
    if (s != null) {
      final CloudResult<CloudSave> r = await _cloud.fetchSave(s);
      lastError = r.ok ? null : r.error;
      final CloudSave? c = r.value;
      if (r.ok &&
          c != null &&
          (blob == null || c.updatedAt.isAfter(_at(blob)))) {
        blob = c.data;
      }
      await _apply(blob);
      _markSynced(owner);
      // 온라인에 아직 없거나(옛 계정 첫 로그인) 이 기기 기록이 더 새로우면 올린다
      if (r.ok &&
          (c == null ||
              migrated ||
              (blob != null && _at(blob).isAfter(c.updatedAt)))) {
        await pushNow();
      }
      return;
    }
    await _apply(blob);
  }

  // ── 온라인 올리기 ────────────────────────────────────────────
  /// 기록이 바뀔 때마다 호출 → 몇 초 모아서 한 번 올린다
  void schedulePush() {
    try {
      _settings.put(
        'dirtyAt::${_key(_progress.owner)}',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 4), pushNow);
  }

  Future<void> pushNow() async {
    _pushTimer?.cancel();
    final String? owner = _progress.owner;
    if (owner == null || _pushing) return;
    final CloudSession? s = await _auth.freshCloudSession();
    if (s == null || s.email != owner) return;
    _pushing = true;
    try {
      final Map<String, dynamic> blob = capture();
      await _vault.put(_key(owner), blob);
      final CloudError e = await _cloud.pushSave(s, blob);
      lastError = e == CloudError.none ? null : e;
      if (e == CloudError.none) _markSynced(owner);
      debugPrint('[sync] 온라인 저장 ${e == CloudError.none ? '성공' : '실패($e)'}');
    } finally {
      _pushing = false;
    }
  }

  void _markSynced(String? owner) {
    lastSyncedAt = DateTime.now();
    try {
      _settings.put(
        'syncedAt::${_key(owner)}',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  DateTime _settingAt(String k) =>
      DateTime.tryParse((_settings.get(k) ?? '').toString()) ?? DateTime(2000);

  /// 앱을 켤 때: 다른 기기에서 더 새로 저장한 기록이 있으면 받아온다.
  Future<void> pullOnBoot() async {
    final String? owner = _progress.owner;
    if (owner == null) return;
    final CloudSession? s = await _auth.freshCloudSession();
    if (s == null) return;
    final CloudResult<CloudSave> r = await _cloud.fetchSave(s);
    lastError = r.ok ? null : r.error;
    if (!r.ok) return;
    final CloudSave? c = r.value;
    final DateTime synced = _settingAt('syncedAt::${_key(owner)}');
    final DateTime dirty = _settingAt('dirtyAt::${_key(owner)}');
    final bool localChanged = dirty.isAfter(synced);
    if (c == null) {
      await pushNow();
      return;
    }
    final bool cloudChanged = c.updatedAt.isAfter(
      synced.add(const Duration(seconds: 2)),
    );
    if (cloudChanged && (!localChanged || c.updatedAt.isAfter(dirty))) {
      await _apply(c.data);
      await _vault.put(_key(owner), c.data);
      _markSynced(owner);
      debugPrint('[sync] 다른 기기의 새 기록을 받아왔어요');
    } else if (localChanged) {
      await pushNow();
    } else {
      lastSyncedAt = synced;
    }
  }

  // ── 처음 한 번: 예전(계정 구분 없던 시절) 기록 정리 ───────────────
  /// 지금 localStorage 의 게임 기록과 옛 공용 저장 코드는 '이 기기에서 가장 먼저 만든 계정'
  /// (없으면 게스트) 것으로 본다. 지금 로그인된 계정이 다른 계정이면 그 계정은 빈 기록에서 시작.
  Future<void> migrateOnce() async {
    if (_settings.get('vaultV1') == true) return;
    try {
      final List<Account> accounts = _auth.localAccounts;
      final String? original = accounts.isEmpty ? null : accounts.first.email;
      final String? current = _progress.owner;
      await _progress.migrateLegacyMirrors(original);

      // 원래 계정이 아닌 계정들의 진행 박스에 섞여 들어간 남의 저장 코드는 지운다
      for (final Account a in accounts) {
        if (a.email == original) continue;
        final Box<dynamic> box = await _store.openProgress(a.email);
        for (final dynamic k in box.keys.toList()) {
          final Object? raw = box.get(k);
          if (raw is Map && (raw['saveCode'] ?? '').toString().isNotEmpty) {
            final Map<dynamic, dynamic> m = Map<dynamic, dynamic>.from(raw);
            m['saveCode'] = '';
            m['saveCodeAt'] = null;
            await box.put(k, m);
          }
        }
      }

      if (current != original) {
        await _vault.put(_key(original), <String, dynamic>{
          'v': 1,
          'at': DateTime.now().toUtc().toIso8601String(),
          'ls': _games.readAll(),
        });
        _games.replaceAll(const <String, String>{});
      }
      await _progress.rebind(current);
      await _settings.put('vaultV1', true);
      debugPrint(
        '[sync] 옛 기록 정리: 원래 계정=${original ?? '게스트'}, 지금=${current ?? '게스트'}',
      );
    } catch (e) {
      debugPrint('[sync] 옛 기록 정리 실패: $e');
    }
  }
}
