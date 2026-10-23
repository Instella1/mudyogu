import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_info.dart';
import 'local_store.dart';

/// 게임 카탈로그 로더.
///
/// 우선순위
/// 1) 사용자가 마지막으로 받아둔 원격 카탈로그(settings 캐시)
/// 2) 앱에 번들된 `assets/games/catalog.json`
///
/// 나중에 서버를 붙일 때는 `remoteCatalogUrl` 을 설정하고
/// [refreshFromRemote] 만 호출하면 됩니다.
class CatalogService {
  CatalogService(this._store);

  static const String assetPath = 'assets/games/catalog.json';
  static const String _cacheKey = 'catalog_cache';

  /// 원격 카탈로그 주소 (비어 있으면 번들 카탈로그만 사용)
  static String remoteCatalogUrl = '';

  final LocalStore _store;

  GameCatalog? _catalog;

  GameCatalog get catalog => _catalog ?? GameCatalog.empty;

  List<GameInfo> get games => catalog.games;

  GameInfo? byId(String id) {
    for (final GameInfo g in games) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<GameCatalog> load() async {
    // 1) 캐시된 원격 카탈로그
    final Object? cached = _store.settings.get(_cacheKey);
    if (cached is String && cached.isNotEmpty) {
      try {
        final GameCatalog remote =
            GameCatalog.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        if (remote.games.isNotEmpty) {
          _catalog = remote;
          return remote;
        }
      } catch (_) {
        // 캐시 손상 시 번들로 폴백
      }
    }

    // 2) 번들 카탈로그
    final String raw = await rootBundle.loadString(assetPath);
    _catalog = GameCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _catalog!;
  }

  /// 원격 카탈로그 갱신 시도. 성공 시 새 카탈로그 반환.
  Future<GameCatalog?> refreshFromRemote() async {
    if (remoteCatalogUrl.isEmpty) return null;
    // 실제 구현 시 http 패키지로 remoteCatalogUrl 을 GET 하여
    // 스키마 검증 후 _store.settings 에 캐시합니다.
    return null;
  }
}
