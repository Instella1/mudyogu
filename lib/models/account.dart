import 'package:flutter/foundation.dart';

/// 로컬 계정 (이메일 기반).
@immutable
class Account {
  const Account({
    required this.email,
    required this.nickname,
    required this.passwordHash,
    required this.salt,
    required this.recoveryCodeHash,
    required this.createdAt,
  });

  final String email;
  final String nickname;
  final String passwordHash;
  final String salt;
  final String recoveryCodeHash;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'email': email,
    'nickname': nickname,
    'passwordHash': passwordHash,
    'salt': salt,
    'recoveryCodeHash': recoveryCodeHash,
    'createdAt': createdAt.toIso8601String(),
  };

  static Account fromMap(Map<dynamic, dynamic> map) => Account(
    email: (map['email'] ?? '').toString(),
    nickname: (map['nickname'] ?? '').toString(),
    passwordHash: (map['passwordHash'] ?? '').toString(),
    salt: (map['salt'] ?? '').toString(),
    recoveryCodeHash: (map['recoveryCodeHash'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
        DateTime.now(),
  );

  Account copyWith({String? nickname}) => Account(
    email: email,
    nickname: nickname ?? this.nickname,
    passwordHash: passwordHash,
    salt: salt,
    recoveryCodeHash: recoveryCodeHash,
    createdAt: createdAt,
  );
}

/// 한 게임의 진행상황.
///
/// [state] 는 게임이 자유롭게 쓰는 JSON 입니다.
/// [updatedAt] 이 병합 기준(최신 우선)이 됩니다.
@immutable
class GameProgress {
  const GameProgress({
    required this.gameId,
    required this.bestScore,
    required this.playCount,
    required this.playSeconds,
    required this.updatedAt,
    this.state = const <String, dynamic>{},
    this.saveCode = '',
    this.saveCodeAt,
  });

  final String gameId;
  final int bestScore;
  final int playCount;
  final int playSeconds;
  final DateTime updatedAt;
  final Map<String, dynamic> state;

  /// 게임이 직접 만든 "저장 코드" (다른 기기로 옮길 때 쓰는 문자열).
  /// 한일남 LIFE 의 '리포트 코드', 한일전의 '진행 코드' 등.
  final String saveCode;
  final DateTime? saveCodeAt;

  bool get hasSaveCode => saveCode.isNotEmpty;

  static GameProgress initial(String gameId) => GameProgress(
    gameId: gameId,
    bestScore: 0,
    playCount: 0,
    playSeconds: 0,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  GameProgress copyWith({
    int? bestScore,
    int? playCount,
    int? playSeconds,
    DateTime? updatedAt,
    Map<String, dynamic>? state,
    String? saveCode,
    DateTime? saveCodeAt,
  }) => GameProgress(
    gameId: gameId,
    bestScore: bestScore ?? this.bestScore,
    playCount: playCount ?? this.playCount,
    playSeconds: playSeconds ?? this.playSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
    state: state ?? this.state,
    saveCode: saveCode ?? this.saveCode,
    saveCodeAt: saveCodeAt ?? this.saveCodeAt,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'gameId': gameId,
    'bestScore': bestScore,
    'playCount': playCount,
    'playSeconds': playSeconds,
    'updatedAt': updatedAt.toIso8601String(),
    'state': state,
    'saveCode': saveCode,
    'saveCodeAt': saveCodeAt?.toIso8601String(),
  };

  static GameProgress fromMap(Map<dynamic, dynamic> map) => GameProgress(
    gameId: (map['gameId'] ?? '').toString(),
    bestScore: (map['bestScore'] as num?)?.toInt() ?? 0,
    playCount: (map['playCount'] as num?)?.toInt() ?? 0,
    playSeconds: (map['playSeconds'] as num?)?.toInt() ?? 0,
    updatedAt:
        DateTime.tryParse((map['updatedAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    state: (map['state'] as Map<dynamic, dynamic>?)
            ?.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)) ??
        const <String, dynamic>{},
    saveCode: (map['saveCode'] ?? '').toString(),
    saveCodeAt: DateTime.tryParse((map['saveCodeAt'] ?? '').toString()),
  );
}

/// 게임에서 올라오는 진행 이벤트 (postMessage 또는 저장 시점)
@immutable
class ProgressEvent {
  const ProgressEvent({
    this.score,
    this.state,
    this.playSeconds,
    this.isGameOver = false,
  });

  final int? score;
  final Map<String, dynamic>? state;
  final int? playSeconds;
  final bool isGameOver;

  static ProgressEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final Object? score = raw['score'];
    final Object? state = raw['state'];
    final Object? secs = raw['playSeconds'];
    return ProgressEvent(
      score: score is num ? score.toInt() : int.tryParse('${score ?? ''}'),
      state: state is Map
          ? state.map((dynamic k, dynamic v) => MapEntry(k.toString(), v))
          : null,
      playSeconds: secs is num ? secs.toInt() : int.tryParse('${secs ?? ''}'),
      isGameOver: raw['isGameOver'] == true,
    );
  }
}
