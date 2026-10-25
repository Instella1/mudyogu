import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/local_store.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';
import '../services/sync_service.dart';

/// 앱 전역 상태.
class AppState extends ChangeNotifier {
  AppState({
    required LocalStore store,
    required AuthService auth,
    required ProgressService progress,
    required CatalogService catalog,
    required SettingsService settings,
    required SyncService sync,
  }) : _store = store,
       _auth = auth,
       _progress = progress,
       _catalog = catalog,
       _settings = settings,
       _sync = sync;

  final LocalStore _store;
  final AuthService _auth;
  final ProgressService _progress;
  final CatalogService _catalog;
  final SettingsService _settings;
  final SyncService _sync;

  bool _booting = true;
  String? _lastMergeNotice;

  // ── 게터 ───────────────────────────────────────────────────
  bool get isBooting => _booting;
  AuthService get auth => _auth;
  ProgressService get progress => _progress;
  CatalogService get catalogService => _catalog;
  SettingsService get settings => _settings;
  SyncService get sync => _sync;

  /// 로그인은 됐지만 온라인 계정과 연결이 안 된 상태 (이 기기에만 저장 중)
  bool get isLocalOnly => _auth.isSignedIn && !_auth.isCloudLinked;

  List<GameInfo> get games => _catalog.games;
  Account? get account => _auth.currentAccount;
  bool get isSignedIn => _auth.isSignedIn;

  String get displayName {
    final Account? a = account;
    if (a != null) return a.nickname;
    return '게스트';
  }

  String get initialLetter {
    final String name = displayName;
    return name.isEmpty ? '?' : name.substring(0, 1);
  }

  String? get lastMergeNotice => _lastMergeNotice;
  void clearMergeNotice() {
    _lastMergeNotice = null;
  }

  // ── 부트스트랩 ─────────────────────────────────────────────
  Future<void> bootstrap() async {
    await _store.init();
    await _catalog.load();
    await _progress.load();
    await _sync.migrateOnce();
    // 다른 기기에서 더 새로 저장한 기록이 있으면 받아온다 (너무 오래 걸리면 화면부터 띄움)
    try {
      await _sync.pullOnBoot().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[sync] 시작 동기화 건너뜀: $e');
    }
    _booting = false;
    notifyListeners();
  }

  // ── 인증 ───────────────────────────────────────────────────
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final bool fromGuest = _progress.owner == null;
    await _sync.beforeSwitch();
    final AuthResult result = await _auth.signUp(
      email: email,
      password: password,
      nickname: nickname,
    );
    if (result.ok) {
      final String mail = AuthService.normalizeEmail(email);
      if (fromGuest) {
        // 게스트로 하던 기록을 새 계정이 그대로 가져간다
        final int merged = await _progress.mergeGuestInto(mail);
        await _sync.afterSwitch(mail, carry: true);
        if (merged > 0) {
          _lastMergeNotice = '게스트 기록을 새 계정으로 옮겼어요.';
        }
      } else {
        await _sync.afterSwitch(mail);
      }
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await _sync.beforeSwitch();
    final AuthResult result = await _auth.signIn(
      email: email,
      password: password,
    );
    if (result.ok) {
      await _sync.afterSwitch(
        AuthService.normalizeEmail(email),
        migrated: result.migrated,
      );
      if (result.migrated) {
        _lastMergeNotice = '이 기기에만 있던 계정을 온라인 계정으로 옮겼어요. 이제 다른 기기에서도 로그인돼요.';
      }
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> continueAsGuest() async {
    await _sync.beforeSwitch();
    await _auth.continueAsGuest();
    await _sync.afterSwitch(null);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _sync.beforeSwitch();
    await _auth.signOut();
    await _sync.afterSwitch(null);
    notifyListeners();
  }

  Future<AuthResult> updateNickname(String nickname) async {
    final AuthResult r = await _auth.updateNickname(nickname);
    if (r.ok) notifyListeners();
    return r;
  }

  Future<void> deleteAccount() async {
    final String? mail = _auth.currentEmail;
    await _auth.deleteAccount();
    if (mail != null) await _store.vault.delete(mail);
    await _sync.afterSwitch(null);
    notifyListeners();
  }

  // ── 진행상황 ───────────────────────────────────────────────
  GameProgress progressFor(String gameId) => _progress.progressFor(gameId);

  Future<GameProgress> applyProgress({
    required String gameId,
    ProgressEvent? event,
    bool countAsPlay = false,
  }) async {
    final GameProgress p = await _progress.apply(
      gameId: gameId,
      event: event,
      countAsPlay: countAsPlay,
    );
    await _settings.setLastPlayedGameId(gameId);
    _sync.schedulePush();
    notifyListeners();
    return p;
  }

  Future<void> resetBestScore(String gameId) async {
    await _progress.resetBest(gameId);
    _sync.schedulePush();
    notifyListeners();
  }

  Future<void> resetProgress(String gameId) async {
    await _progress.reset(gameId);
    _sync.schedulePush();
    notifyListeners();
  }

  // ── 게임 저장 코드 (다른 기기로 옮길 때 쓰는 문자열) ──────────
  Future<void> storeGameCode({
    required String gameId,
    required String code,
  }) async {
    await _progress.storeCode(gameId, code);
    _sync.schedulePush();
    notifyListeners();
  }

  String gameCodeFor(String gameId) => _progress.codeFor(gameId);

  bool hasGameCode(String gameId) => _progress.codeFor(gameId).isNotEmpty;

  Future<void> resetAllProgress() async {
    await _progress.resetAll();
    _sync.schedulePush();
    notifyListeners();
  }

  /// 테마 변경을 UI 에 반영
  void notifyThemeChanged() => notifyListeners();
}
