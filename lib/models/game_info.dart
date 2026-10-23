import 'package:flutter/material.dart';

/// 게임 카탈로그 항목.
///
/// [entry] 는 웹 루트 기준 상대 경로입니다. (예: `games/haniljeon/index.html`)
/// build/web 에 그대로 복사되는 `web/games/` 아래에 게임을 두면
/// 별도 변환 없이 iframe 으로 로드할 수 있습니다.
@immutable
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.entry,
    required this.accent,
    this.tags = const <String>[],
    this.version = '1.0.0',
    this.supportsState = true,
    this.bestScoreLabel = '최고 점수',
    this.builtIn = true,
    this.aspect = '16/9',
  });

  final String id;
  final String title;
  final String tagline;
  final String entry;

  /// 카드 강조색 (0xAARRGGBB)
  final int accent;
  final List<String> tags;
  final String version;

  /// 게임이 진행상황(state) 저장을 지원하는지
  final bool supportsState;
  final String bestScoreLabel;
  final bool builtIn;

  /// 게임이 요구하는 화면 비율 (예: `16/9`, `9/16`, `3/4`).
  ///
  /// 앱은 이 비율대로 무대(stage)를 만들고 그 안에만 게임을 그립니다.
  /// 비율을 벗어나는 여백은 배경색으로 채워 레터박스 처리합니다.
  final String aspect;

  Color get accentColor => Color(accent);

  /// `aspect` 문자열을 실제 나눗셈 값으로 변환합니다. (가로 / 세로)
  double get aspectRatio {
    final List<String> parts = aspect.split('/');
    if (parts.length == 2) {
      final double? w = double.tryParse(parts[0].trim());
      final double? h = double.tryParse(parts[1].trim());
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    }
    final double? flat = double.tryParse(aspect.trim());
    if (flat != null && flat > 0) return flat;
    return 16 / 9;
  }

  /// 세로로 긴 게임인지 (모바일 무대 배치에 사용)
  bool get isPortrait => aspectRatio < 1.0;

  static GameInfo fromJson(Map<String, dynamic> json) {
    return GameInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '이름 없는 게임').toString(),
      tagline: (json['tagline'] ?? '').toString(),
      entry: (json['entry'] ?? '').toString(),
      accent: _parseColor(json['accent']),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      version: (json['version'] ?? '1.0.0').toString(),
      supportsState: json['supportsState'] as bool? ?? true,
      bestScoreLabel: (json['bestScoreLabel'] ?? '최고 점수').toString(),
      builtIn: json['builtIn'] as bool? ?? true,
      aspect: (json['aspect'] ?? '16/9').toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'tagline': tagline,
    'entry': entry,
    'accent': '#${accent.toRadixString(16).padLeft(8, '0')}',
    'tags': tags,
    'version': version,
    'supportsState': supportsState,
    'bestScoreLabel': bestScoreLabel,
    'builtIn': builtIn,
    'aspect': aspect,
  };

  static int _parseColor(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) {
      String hex = raw.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      final int? parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return parsed;
    }
    return 0xFF2FCC8B;
  }
}

/// 카탈로그 파일 형식 (`assets/games/catalog.json`)
@immutable
class GameCatalog {
  const GameCatalog({
    required this.schemaVersion,
    required this.updatedAt,
    required this.games,
  });

  final int schemaVersion;
  final String updatedAt;
  final List<GameInfo> games;

  static GameCatalog fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['games'] as List<dynamic>?) ?? const <dynamic>[];
    return GameCatalog(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      updatedAt: (json['updatedAt'] ?? '').toString(),
      games: raw
          .whereType<Map<String, dynamic>>()
          .map(GameInfo.fromJson)
          .toList(growable: false),
    );
  }

  static const GameCatalog empty = GameCatalog(
    schemaVersion: 1,
    updatedAt: '',
    games: <GameInfo>[],
  );
}
