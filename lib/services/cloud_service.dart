import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Supabase 주소/공개키. 공개키(anon)는 원래 브라우저에 공개되는 값이다
/// (타워 크래시 랭킹과 같은 프로젝트). 데이터 보호는 DB 의 RLS 가 한다 → docs/supabase-accounts.sql
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nvpvdkxovknhqglfbhmv.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52cHZka3hvdmtuaHFnbGZiaG12Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4ODA1NDgsImV4cCI6MjEwODQ1NjU0OH0.sbayovYN3rAJIoqGXcBLzaEMlZ4CCIn7I_PO6pFRHUs',
);

/// 로그인 세션 (토큰)
@immutable
class CloudSession {
  const CloudSession({
    required this.uid,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.nickname = '',
  });

  final String uid;
  final String email;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String nickname;

  bool get expiringSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 90)));

  Map<String, dynamic> toMap() => <String, dynamic>{
    'uid': uid,
    'email': email,
    'access': accessToken,
    'refresh': refreshToken,
    'exp': expiresAt.toIso8601String(),
    'nickname': nickname,
  };

  static CloudSession? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final String uid = (raw['uid'] ?? '').toString();
    final String access = (raw['access'] ?? '').toString();
    if (uid.isEmpty || access.isEmpty) return null;
    return CloudSession(
      uid: uid,
      email: (raw['email'] ?? '').toString(),
      accessToken: access,
      refreshToken: (raw['refresh'] ?? '').toString(),
      expiresAt:
          DateTime.tryParse((raw['exp'] ?? '').toString()) ?? DateTime(2000),
      nickname: (raw['nickname'] ?? '').toString(),
    );
  }

  static CloudSession? fromAuthResponse(Map<String, dynamic> j) {
    final Object? user = j['user'];
    final String access = (j['access_token'] ?? '').toString();
    if (user is! Map || access.isEmpty) return null;
    final Object? meta = user['user_metadata'];
    final int expiresIn = (j['expires_in'] as num?)?.toInt() ?? 3600;
    return CloudSession(
      uid: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      accessToken: access,
      refreshToken: (j['refresh_token'] ?? '').toString(),
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      nickname: meta is Map ? (meta['nickname'] ?? '').toString() : '',
    );
  }
}

enum CloudError {
  none,
  network, // 인터넷 연결/서버 문제
  invalidCredentials, // 이메일 또는 비밀번호 틀림 (또는 계정 없음)
  emailTaken,
  emailNotConfirmed,
  needsConfirmation, // 가입은 됐고 메일 인증이 필요
  weakPassword,
  rateLimited,
  notSetUp, // DB 테이블이 아직 없음 (SQL 미실행)
  unknown,
}

@immutable
class CloudResult<T> {
  const CloudResult(this.value, [this.error = CloudError.none]);
  const CloudResult.fail(this.error) : value = null;

  final T? value;
  final CloudError error;
  bool get ok => error == CloudError.none;
}

/// 클라우드에 올라가는 한 계정의 기록 묶음
@immutable
class CloudSave {
  const CloudSave({required this.data, required this.updatedAt});

  final Map<String, dynamic> data;
  final DateTime updatedAt;
}

/// Supabase REST 클라이언트 (Auth + 기록 테이블 mud_saves).
class CloudService {
  CloudService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const Duration _timeout = Duration(seconds: 12);

  Map<String, String> _headers([String? token]) => <String, String>{
    'apikey': kSupabaseAnonKey,
    'Authorization': 'Bearer ${token ?? kSupabaseAnonKey}',
    'Content-Type': 'application/json',
  };

  Uri _u(String path) => Uri.parse('$kSupabaseUrl$path');

  static String _errText(http.Response r) {
    try {
      final Object? j = jsonDecode(r.body);
      if (j is Map) {
        return '${j['error_code'] ?? j['code'] ?? ''} ${j['msg'] ?? j['message'] ?? j['error_description'] ?? j['error'] ?? ''}'
            .toLowerCase();
      }
    } catch (_) {}
    return r.body.toLowerCase();
  }

  static CloudError _authError(http.Response r) {
    final String t = _errText(r);
    if (r.statusCode == 429 || t.contains('rate')) {
      return CloudError.rateLimited;
    }
    if (t.contains('not confirmed') || t.contains('email_not_confirmed')) {
      return CloudError.emailNotConfirmed;
    }
    if (t.contains('already') || t.contains('user_already_exists')) {
      return CloudError.emailTaken;
    }
    if (t.contains('weak') || t.contains('password should')) {
      return CloudError.weakPassword;
    }
    if (t.contains('invalid') || r.statusCode == 400) {
      return CloudError.invalidCredentials;
    }
    if (r.statusCode >= 500) return CloudError.network;
    return CloudError.unknown;
  }

  Future<http.Response?> _send(Future<http.Response> Function() f) async {
    try {
      return await f().timeout(_timeout);
    } catch (e) {
      debugPrint('[cloud] 요청 실패: $e');
      return null;
    }
  }

  // ── Auth ────────────────────────────────────────────────────
  Future<CloudResult<CloudSession>> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final http.Response? r = await _send(
      () => _http.post(
        _u('/auth/v1/signup'),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
          'data': <String, dynamic>{'nickname': nickname},
        }),
      ),
    );
    if (r == null) {
      return const CloudResult<CloudSession>.fail(CloudError.network);
    }
    if (r.statusCode >= 300) {
      return CloudResult<CloudSession>.fail(_authError(r));
    }
    final Map<String, dynamic> j = jsonDecode(r.body) as Map<String, dynamic>;
    final CloudSession? s = CloudSession.fromAuthResponse(j);
    if (s != null) return CloudResult<CloudSession>(s);
    // '메일 인증' 이 켜진 프로젝트: 세션 없이 user 만 온다.
    // 이미 가입된 이메일이면 identities 가 빈 배열로 온다.
    final Object? ids =
        j['identities'] ??
        (j['user'] is Map ? (j['user'] as Map)['identities'] : null);
    if (ids is List && ids.isEmpty) {
      return const CloudResult<CloudSession>.fail(CloudError.emailTaken);
    }
    return const CloudResult<CloudSession>.fail(CloudError.needsConfirmation);
  }

  Future<CloudResult<CloudSession>> signIn({
    required String email,
    required String password,
  }) async {
    final http.Response? r = await _send(
      () => _http.post(
        _u('/auth/v1/token?grant_type=password'),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{
          'email': email,
          'password': password,
        }),
      ),
    );
    if (r == null) {
      return const CloudResult<CloudSession>.fail(CloudError.network);
    }
    if (r.statusCode >= 300) {
      return CloudResult<CloudSession>.fail(_authError(r));
    }
    final CloudSession? s = CloudSession.fromAuthResponse(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
    return s == null
        ? const CloudResult<CloudSession>.fail(CloudError.unknown)
        : CloudResult<CloudSession>(s);
  }

  Future<CloudResult<CloudSession>> refresh(CloudSession s) async {
    final http.Response? r = await _send(
      () => _http.post(
        _u('/auth/v1/token?grant_type=refresh_token'),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{'refresh_token': s.refreshToken}),
      ),
    );
    if (r == null) {
      return const CloudResult<CloudSession>.fail(CloudError.network);
    }
    if (r.statusCode >= 300) {
      return CloudResult<CloudSession>.fail(_authError(r));
    }
    final CloudSession? n = CloudSession.fromAuthResponse(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
    return n == null
        ? const CloudResult<CloudSession>.fail(CloudError.unknown)
        : CloudResult<CloudSession>(n);
  }

  /// 비밀번호 재설정 메일 (메일 속 링크 → 사이트의 index.html 이 새 비밀번호 입력창을 띄움)
  Future<CloudError> sendPasswordReset(String email, String redirectTo) async {
    final http.Response? r = await _send(
      () => _http.post(
        _u(
          '/auth/v1/recover?redirect_to=${Uri.encodeQueryComponent(redirectTo)}',
        ),
        headers: _headers(),
        body: jsonEncode(<String, dynamic>{'email': email}),
      ),
    );
    if (r == null) return CloudError.network;
    if (r.statusCode >= 300) return _authError(r);
    return CloudError.none;
  }

  Future<CloudError> updateNickname(CloudSession s, String nickname) async {
    final http.Response? r = await _send(
      () => _http.put(
        _u('/auth/v1/user'),
        headers: _headers(s.accessToken),
        body: jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'nickname': nickname},
        }),
      ),
    );
    if (r == null) return CloudError.network;
    return r.statusCode >= 300 ? _authError(r) : CloudError.none;
  }

  // ── 기록 (mud_saves: 계정당 한 줄) ───────────────────────────
  static CloudError _dbError(http.Response r) {
    final String t = _errText(r);
    if (r.statusCode == 404 ||
        t.contains('42p01') ||
        t.contains('does not exist') ||
        t.contains('pgrst205')) {
      return CloudError.notSetUp;
    }
    if (r.statusCode == 401) return CloudError.invalidCredentials;
    if (r.statusCode >= 500) return CloudError.network;
    return CloudError.unknown;
  }

  /// 없으면 value == null (ok)
  Future<CloudResult<CloudSave>> fetchSave(CloudSession s) async {
    final http.Response? r = await _send(
      () => _http.get(
        _u('/rest/v1/mud_saves?user_id=eq.${s.uid}&select=data,updated_at'),
        headers: _headers(s.accessToken),
      ),
    );
    if (r == null) return const CloudResult<CloudSave>.fail(CloudError.network);
    if (r.statusCode >= 300) return CloudResult<CloudSave>.fail(_dbError(r));
    final Object? j = jsonDecode(r.body);
    if (j is! List || j.isEmpty) return const CloudResult<CloudSave>(null);
    final Map<dynamic, dynamic> row = j.first as Map<dynamic, dynamic>;
    final Object? data = row['data'];
    return CloudResult<CloudSave>(
      CloudSave(
        data: data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{},
        updatedAt:
            DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
            DateTime(2000),
      ),
    );
  }

  Future<CloudError> pushSave(CloudSession s, Map<String, dynamic> data) async {
    final http.Response? r = await _send(
      () => _http.post(
        _u('/rest/v1/mud_saves?on_conflict=user_id'),
        headers: <String, String>{
          ..._headers(s.accessToken),
          'Prefer': 'resolution=merge-duplicates,return=minimal',
        },
        body: jsonEncode(<String, dynamic>{
          'user_id': s.uid,
          'data': data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      ),
    );
    if (r == null) return CloudError.network;
    return r.statusCode >= 300 ? _dbError(r) : CloudError.none;
  }

  Future<CloudError> deleteSave(CloudSession s) async {
    final http.Response? r = await _send(
      () => _http.delete(
        _u('/rest/v1/mud_saves?user_id=eq.${s.uid}'),
        headers: _headers(s.accessToken),
      ),
    );
    if (r == null) return CloudError.network;
    return r.statusCode >= 300 ? _dbError(r) : CloudError.none;
  }
}
