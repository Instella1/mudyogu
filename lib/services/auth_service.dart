import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/account.dart';
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
        return '이미 등록된 이메일이에요.';
      case AuthFailure.weakPassword:
        return '비밀번호는 6자 이상이어야 해요.';
      case AuthFailure.notFound:
        return '등록되지 않은 이메일이에요.';
      case AuthFailure.wrongPassword:
        return '비밀번호가 일치하지 않아요.';
      case AuthFailure.wrongRecoveryCode:
        return '복구 코드가 일치하지 않아요.';
      case AuthFailure.nicknameEmpty:
        return '닉네임을 입력해 주세요.';
      case AuthFailure.unknown:
        return '알 수 없는 문제가 발생했어요.';
    }
  }
}

@immutable
class AuthResult {
  const AuthResult({required this.ok, this.failure = AuthFailure.none, this.recoveryCode});

  final bool ok;
  final AuthFailure failure;

  /// 회원가입 시 1회 노출되는 복구 코드
  final String? recoveryCode;

  String get message => failure.message;

  static const AuthResult success = AuthResult(ok: true);

  factory AuthResult.fail(AuthFailure f) => AuthResult(ok: false, failure: f);
}

/// 이메일 계정 서비스 (오프라인 로컬 구현).
///
/// 실제 클라우드 인증으로 바꿀 때는 이 클래스만 교체하면 됩니다.
class AuthService {
  AuthService(this._store);

  final LocalStore _store;

  static final RegExp _emailRe = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$',
  );

  Box<dynamic> get _accounts => _store.accounts;
  Box<dynamic> get _session => _store.session;

  String? get currentEmail => _session.get('email') as String?;
  bool get isGuest => _session.get('isGuest') as bool? ?? false;
  bool get isSignedIn => currentEmail != null;

  Account? get currentAccount {
    final String? email = currentEmail;
    if (email == null) return null;
    final Object? raw = _accounts.get(email);
    if (raw is! Map) return null;
    return Account.fromMap(raw);
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

  /// 사용자에게 보여줄 복구 코드: ABCD-EFGH-IJKL 형태
  static String generateRecoveryCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random rnd = Random.secure();
    String block() => List<String>.generate(
      4,
      (_) => alphabet[rnd.nextInt(alphabet.length)],
    ).join();
    return '${block()}-${block()}-${block()}';
  }

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  // ── 회원가입 ────────────────────────────────────────────────
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final String mail = normalizeEmail(email);
    if (!_emailRe.hasMatch(mail)) return AuthResult.fail(AuthFailure.emailInvalid);
    if (_accounts.containsKey(mail)) return AuthResult.fail(AuthFailure.emailTaken);
    if (password.length < 6) return AuthResult.fail(AuthFailure.weakPassword);
    if (nickname.trim().isEmpty) return AuthResult.fail(AuthFailure.nicknameEmpty);

    final String salt = _newSalt();
    final String recoveryCode = generateRecoveryCode();

    final Account account = Account(
      email: mail,
      nickname: nickname.trim(),
      passwordHash: _hash(password, salt),
      salt: salt,
      recoveryCodeHash: _hash(recoveryCode, salt),
      createdAt: DateTime.now(),
    );

    await _accounts.put(mail, account.toMap());
    await _session.put('email', mail);
    await _session.put('isGuest', false);

    return AuthResult(ok: true, recoveryCode: recoveryCode);
  }

  // ── 로그인 ──────────────────────────────────────────────────
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final String mail = normalizeEmail(email);
    if (!_emailRe.hasMatch(mail)) return AuthResult.fail(AuthFailure.emailInvalid);

    final Object? raw = _accounts.get(mail);
    if (raw is! Map) return AuthResult.fail(AuthFailure.notFound);

    final Account account = Account.fromMap(raw);
    if (_hash(password, account.salt) != account.passwordHash) {
      return AuthResult.fail(AuthFailure.wrongPassword);
    }

    await _session.put('email', mail);
    await _session.put('isGuest', false);
    return AuthResult.success;
  }

  // ── 복구 코드로 비밀번호 재설정 ──────────────────────────────
  Future<AuthResult> resetPassword({
    required String email,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final String mail = normalizeEmail(email);
    if (newPassword.length < 6) return AuthResult.fail(AuthFailure.weakPassword);

    final Object? raw = _accounts.get(mail);
    if (raw is! Map) return AuthResult.fail(AuthFailure.notFound);

    final Account account = Account.fromMap(raw);
    final String normalizedCode = recoveryCode.trim().toUpperCase();
    if (_hash(normalizedCode, account.salt) != account.recoveryCodeHash) {
      return AuthResult.fail(AuthFailure.wrongRecoveryCode);
    }

    final String newSalt = _newSalt();
    final String newRecovery = generateRecoveryCode();
    final Account updated = Account(
      email: account.email,
      nickname: account.nickname,
      passwordHash: _hash(newPassword, newSalt),
      salt: newSalt,
      recoveryCodeHash: _hash(newRecovery, newSalt),
      createdAt: account.createdAt,
    );

    await _accounts.put(mail, updated.toMap());
    return AuthResult(ok: true, recoveryCode: newRecovery);
  }

  Future<AuthResult> updateNickname(String nickname) async {
    final Account? account = currentAccount;
    if (account == null) return AuthResult.fail(AuthFailure.notFound);
    if (nickname.trim().isEmpty) return AuthResult.fail(AuthFailure.nicknameEmpty);
    await _accounts.put(
      account.email,
      account.copyWith(nickname: nickname.trim()).toMap(),
    );
    return AuthResult.success;
  }

  // ── 세션 ────────────────────────────────────────────────────
  Future<void> continueAsGuest() async {
    await _session.put('isGuest', true);
    await _session.delete('email');
  }

  Future<void> signOut() async {
    await _session.delete('email');
    await _session.put('isGuest', false);
  }

  /// 계정 완전 삭제
  Future<void> deleteAccount() async {
    final String? mail = currentEmail;
    if (mail == null) return;
    await _accounts.delete(mail);
    await _store.deleteProgress(mail);
    await _session.delete('email');
    await _session.put('isGuest', false);
  }
}
