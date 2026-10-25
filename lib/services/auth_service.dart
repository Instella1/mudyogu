import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/account.dart';
import 'cloud_service.dart';
import 'local_store.dart';

/// 계정 인증 결과
enum AuthFailure {
  none,
  emailInvalid,
  emailTaken,
  weakPassword,
  notFound,
  wrongPassword,
  wrongRecoveryCode,
  nicknameEmpty,
  network,
  emailNotConfirmed,
  needsConfirmation,
  rateLimited,
  unknown,
}

extension AuthFailureMessage on AuthFailure {
  String get message {
    switch (this) {
      case AuthFailure.none:
        return '';
      case AuthFailure.emailInvalid:
        return '이메일 형식을 확인해 주세요.';
      case AuthFailure.emailTaken:
        return '이미 가입된 이메일이에요. 로그인해 주세요.';
      case AuthFailure.weakPassword:
        return '비밀번호는 6자 이상이어야 해요.';
      case AuthFailure.notFound:
        return '등록되지 않은 이메일이에요.';
      case AuthFailure.wrongPassword:
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case AuthFailure.wrongRecoveryCode:
        return '복구 코드가 일치하지 않아요.';
      case AuthFailure.nicknameEmpty:
        return '닉네임을 입력해 주세요.';
      case AuthFailure.network:
        return '인터넷에 연결되어 있어야 해요. 연결을 확인하고 다시 해 주세요.';
      case AuthFailure.emailNotConfirmed:
        return '메일함에서 인증 링크를 먼저 눌러 주세요.';
      case AuthFailure.needsConfirmation:
        return '인증 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.';
      case AuthFailure.rateLimited:
        return '요청이 너무 많아요. 잠시 뒤에 다시 해 주세요.';
      case AuthFailure.unknown:
        return '알 수 없는 문제가 발생했어요.';
    }
  }
}

@immutable
class AuthResult {
  const AuthResult({
    required this.ok,
    this.failure = AuthFailure.none,
    this.recoveryCode,
    this.migrated = false,
  });

  final bool ok;
  final AuthFailure failure;

  /// (옛 로컬 계정용, 지금은 쓰지 않음)
  final String? recoveryCode;

  /// 이 기기에만 있던 옛 계정을 온라인 계정으로 옮겨 만들었음
  final bool migrated;

  String get message => failure.message;

  static const AuthResult success = AuthResult(ok: true);

  factory AuthResult.fail(AuthFailure f) => AuthResult(ok: false, failure: f);
}

AuthFailure _fromCloud(CloudError e) {
  switch (e) {
    case CloudError.none:
      return AuthFailure.none;
    case CloudError.network:
    case CloudError.notSetUp:
      return AuthFailure.network;
    case CloudError.invalidCredentials:
      return AuthFailure.wrongPassword;
    case CloudError.emailTaken:
      return AuthFailure.emailTaken;
    case CloudError.emailNotConfirmed:
      return AuthFailure.emailNotConfirmed;
    case CloudError.needsConfirmation:
      return AuthFailure.needsConfirmation;
    case CloudError.weakPassword:
      return AuthFailure.weakPassword;
    case CloudError.rateLimited:
      return AuthFailure.rateLimited;
    case CloudError.unknown:
      return AuthFailure.unknown;
  }
}

/// 이메일 계정 서비스.
///
/// 계정의 '진짜' 주인은 Supabase(온라인)다 → 어느 기기에서든 같은 이메일/비밀번호로 로그인.
/// 이 기기에도 계정 정보(비밀번호 해시)를 캐시해 두어 인터넷이 없을 때도 로그인된다.
/// 예전처럼 이 기기에만 있던 계정은, 로그인할 때 같은 이메일/비밀번호로 온라인 계정을 자동으로 만든다.
class AuthService {
  AuthService(this._store, this._cloud);

  final LocalStore _store;
  final CloudService _cloud;

  static final RegExp _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$');

  Box<dynamic> get _accounts => _store.accounts;
  Box<dynamic> get _session => _store.session;

  String? get currentEmail => _session.get('email') as String?;
  bool get isGuest => _session.get('isGuest') as bool? ?? false;
  bool get isSignedIn => currentEmail != null;

  /// 온라인 세션 (없으면 이 기기에서만 로그인된 상태 → 기록이 온라인에 올라가지 않음)
  CloudSession? get cloudSession {
    final CloudSession? s = CloudSession.fromMap(_session.get('cloud'));
    if (s == null || s.email != currentEmail) return null;
    return s;
  }

  bool get isCloudLinked => cloudSession != null;

  Account? get currentAccount {
    final String? email = currentEmail;
    if (email == null) return null;
    final Object? raw = _accounts.get(email);
    if (raw is! Map) return null;
    return Account.fromMap(raw);
  }

  /// 이 기기에 저장된 계정들 (가장 먼저 만든 순)
  List<Account> get localAccounts {
    final List<Account> out = <Account>[];
    for (final dynamic k in _accounts.keys) {
      final Object? raw = _accounts.get(k);
      if (raw is Map) out.add(Account.fromMap(raw));
    }
    out.sort((Account a, Account b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  // ── 해시 유틸 ────────────────────────────────────────────────
  static String _newSalt() {
    final Random rnd = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  bool _localPasswordOk(String mail, String password) {
    final Object? raw = _accounts.get(mail);
    if (raw is! Map) return false;
    final Account a = Account.fromMap(raw);
    return _hash(password, a.salt) == a.passwordHash;
  }

  /// 이 기기에 계정 캐시 저장 (오프라인 로그인용)
  Future<void> _cacheAccount(
    String mail,
    String password,
    String nickname,
  ) async {
    final Object? raw = _accounts.get(mail);
    final Account? old = raw is Map ? Account.fromMap(raw) : null;
    final String salt = _newSalt();
    await _accounts.put(
      mail,
      Account(
        email: mail,
        nickname: nickname.isNotEmpty
            ? nickname
            : (old?.nickname ?? mail.split('@').first),
        passwordHash: _hash(password, salt),
        salt: salt,
        recoveryCodeHash: '',
        createdAt: old?.createdAt ?? DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> _startSession(String mail, CloudSession? cloud) async {
    await _session.put('email', mail);
    await _session.put('isGuest', false);
    if (cloud != null) {
      await _session.put('cloud', cloud.toMap());
    } else {
      await _session.delete('cloud');
    }
  }

  // ── 회원가입 (온라인 필수) ─────────────────────────────────────
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final String mail = normalizeEmail(email);
    if (!_emailRe.hasMatch(mail)) {
      return AuthResult.fail(AuthFailure.emailInvalid);
    }
    if (password.length < 6) return AuthResult.fail(AuthFailure.weakPassword);
    if (nickname.trim().isEmpty) {
      return AuthResult.fail(AuthFailure.nicknameEmpty);
    }

    final CloudResult<CloudSession> r = await _cloud.signUp(
      email: mail,
      password: password,
      nickname: nickname.trim(),
    );
    if (r.error == CloudError.needsConfirmation) {
      await _cacheAccount(mail, password, nickname.trim());
    }
    if (!r.ok) return AuthResult.fail(_fromCloud(r.error));

    await _cacheAccount(mail, password, nickname.trim());
    await _startSession(mail, r.value);
    return AuthResult.success;
  }

  // ── 로그인 ──────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final String mail = normalizeEmail(email);
    if (!_emailRe.hasMatch(mail)) {
      return AuthResult.fail(AuthFailure.emailInvalid);
    }

    final CloudResult<CloudSession> r = await _cloud.signIn(
      email: mail,
      password: password,
    );
    if (r.ok) {
      await _cacheAccount(mail, password, r.value!.nickname);
      await _startSession(mail, r.value);
      return AuthResult.success;
    }

    final bool localOk = _localPasswordOk(mail, password);

    // 인터넷이 없으면: 이 기기에 저장된 계정으로 로그인 (기록은 나중에 온라인과 맞춤)
    if (r.error == CloudError.network) {
      if (!localOk) return AuthResult.fail(AuthFailure.network);
      await _startSession(mail, null);
      return AuthResult.success;
    }

    // 온라인엔 없는데 이 기기에 있던 옛 계정 → 같은 이메일/비밀번호로 온라인 계정을 만든다
    if (r.error == CloudError.invalidCredentials && localOk) {
      final CloudResult<CloudSession> up = await _cloud.signUp(
        email: mail,
        password: password,
        nickname: currentNicknameOf(mail),
      );
      if (up.ok) {
        await _startSession(mail, up.value);
        return const AuthResult(ok: true, migrated: true);
      }
      if (up.error == CloudError.network) {
        await _startSession(mail, null);
        return AuthResult.success;
      }
      // 온라인에 같은 이메일이 이미 있는데 비밀번호가 다름
      return AuthResult.fail(
        _fromCloud(
          up.error == CloudError.emailTaken
              ? CloudError.invalidCredentials
              : up.error,
        ),
      );
    }

    return AuthResult.fail(_fromCloud(r.error));
  }

  String currentNicknameOf(String mail) {
    final Object? raw = _accounts.get(mail);
    if (raw is Map) return Account.fromMap(raw).nickname;
    return mail.split('@').first;
  }

  /// 토큰이 곧 만료되면 새로 받는다. 실패하면 null (이 기기 로그인은 유지).
  Future<CloudSession?> freshCloudSession() async {
    final CloudSession? s = cloudSession;
    if (s == null) return null;
    if (!s.expiringSoon) return s;
    final CloudResult<CloudSession> r = await _cloud.refresh(s);
    if (r.ok) {
      await _session.put('cloud', r.value!.toMap());
      return r.value;
    }
    if (r.error != CloudError.network) {
      // 토큰이 무효 (비밀번호 변경 등) → 다시 로그인해야 온라인 동기화가 켜짐
      await _session.delete('cloud');
    }
    return null;
  }

  // ── 비밀번호 재설정 (메일로 링크) ─────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    final String mail = normalizeEmail(email);
    if (!_emailRe.hasMatch(mail)) {
      return AuthResult.fail(AuthFailure.emailInvalid);
    }
    final Uri u = Uri.base;
    final String back = '${u.scheme}://${u.authority}${u.path}';
    final CloudError e = await _cloud.sendPasswordReset(mail, back);
    return e == CloudError.none
        ? AuthResult.success
        : AuthResult.fail(_fromCloud(e));
  }

  Future<AuthResult> updateNickname(String nickname) async {
    final Account? account = currentAccount;
    if (account == null) return AuthResult.fail(AuthFailure.notFound);
    if (nickname.trim().isEmpty) {
      return AuthResult.fail(AuthFailure.nicknameEmpty);
    }
    await _accounts.put(
      account.email,
      account.copyWith(nickname: nickname.trim()).toMap(),
    );
    final CloudSession? s = await freshCloudSession();
    if (s != null) await _cloud.updateNickname(s, nickname.trim());
    return AuthResult.success;
  }

  // ── 세션 ────────────────────────────────────────────────────
  Future<void> continueAsGuest() async {
    await _session.put('isGuest', true);
    await _session.delete('email');
    await _session.delete('cloud');
  }

  Future<void> signOut() async {
    await _session.delete('email');
    await _session.delete('cloud');
    await _session.put('isGuest', false);
  }

  /// 계정 삭제: 온라인 기록 + 이 기기의 계정/기록
  Future<void> deleteAccount() async {
    final String? mail = currentEmail;
    if (mail == null) return;
    final CloudSession? s = await freshCloudSession();
    if (s != null) await _cloud.deleteSave(s);
    await _accounts.delete(mail);
    await _store.deleteProgress(mail);
    await _session.delete('email');
    await _session.delete('cloud');
    await _session.put('isGuest', false);
  }
}
