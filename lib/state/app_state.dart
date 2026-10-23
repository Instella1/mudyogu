import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/local_store.dart';
import '../services/progress_service.dart';
import '../services/settings_service.dart';

/// 앱 전역 상태.
class AppState extends ChangeNotifier {
  AppState({
    required LocalStore store,
    required AuthService auth,
    required ProgressService progress,
    required CatalogService catalog,
    required SettingsService settings,
  }) : _store = store,
       _auth = auth,
       _progress = progress,
       _catalog = catalog,
       _settings = settings;

  final LocalStore _store;
  final AuthService _auth;
  final ProgressService _progress;
  final CatalogService _catalog;
  final SettingsService _settings;

  bool _booting = true;
  String? _lastMergeNotice;

  // ── 게터 ───────────────────────────────────────────────────
  bool get isBooting => _booting;
  AuthService get auth => _auth;
  ProgressService get progress => _progress;
  CatalogService get catalogService => _catalog;
  SettingsService get settings => _settings;

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
    _booting = false;
    notifyListeners();
  }

  // ── 인증 ───────────────────────────────────────────────────
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final AuthResult result = await _auth.signUp(
      email: email,
      password: password,
      nickname: nickname,
    );
    if (result.ok) {
      final int merged = await _progress.mergeGuestInto(
        AuthService.normalizeEmail(email),
      );
      if (merged > 0) {
        _lastMergeNotice = '게스트 기록 $merged개를 계정으로 옮겼어요.';
      }
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResult result = await _auth.signIn(
      email: email,
      password: password,
    );
    if (result.ok) {
      final int merged = await _progress.mergeGuestInto(
        AuthService.normalizeEmail(email),
      );
      if (merged > 0) {
        _lastMergeNotice = '게스트 기록 $merged개를 계정에 합쳤어요.';
      }
      notifyListeners();
    }
    return result;
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) => _auth.resetPassword(
    email: email,
    recoveryCode: recoveryCode,
    newPassword: newPassword,
  );

  Future<void> continueAsGuest() async {
    await _auth.continueAsGuest();
    await _progress.rebind(null);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _progress.rebind(null);
    notifyListeners();
  }

  Future<AuthResult> updateNickname(String nickname) async {
    final AuthResult r = await _auth.updateNickname(nickname);
    if (r.ok) notifyListeners();
    return r;
  }

  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    await _progress.rebind(null);
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
    notifyListeners();
    return p;
  }

  Future<void> resetProgress(String gameId) async {
    await _progress.reset(gameId);
    notifyListeners();
  }

  // ── 게임 저장 코드 (다른 기기로 옮길 때 쓰는 문자열) ──────────
  Future<void> storeGameCode({
    required String gameId,
    required String code,
  }) async {
    await _progress.storeCode(gameId, code);
    notifyListeners();
  }

  String gameCodeFor(String gameId) => _progress.codeFor(gameId);

  bool hasGameCode(String gameId) => _progress.codeFor(gameId).isNotEmpty;

  Future<void> resetAllProgress() async {
    await _progress.resetAll();
    notifyListeners();
  }

  /// 테마 변경을 UI 에 반영
  void notifyThemeChanged() => notifyListeners();

}
