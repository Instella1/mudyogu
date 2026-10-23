import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'local_store.dart';
/// 테마 모드: 시스템 / 라이트 / 다크
enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  String get label {
    switch (this) {
      case AppThemeMode.system:
        return '시스템 설정';
      case AppThemeMode.light:
        return '라이트';
      case AppThemeMode.dark:
        return '다크';
    }
  }
}

/// 앱 설정 (테마, 마지막 플레이 게임 등)
class SettingsService {
  SettingsService(this._store);

  final LocalStore _store;

  static const String kThemeMode = 'theme_mode';
  static const String kLastPlayed = 'last_played_game';
  static const String kSeenInstallHint = 'seen_install_hint';
  static const String kOfflineReady = 'offline_ready';

  /// Hive 초기화 전(첫 프레임) 에 getter 가 호출될 수 있습니다.
  /// 그때 `Box not found` 로 앱이 죽지 않도록 안전하게 읽습니다.
  T? _read<T>(String key) {
    try {
      return _store.settings.get(key) as T?;
    } catch (e) {
      debugPrint('[settings] 읽기 보류($key): $e');
      return null;
    }
  }

  Future<bool> _write(String key, Object? value) async {
    try {
      await _store.settings.put(key, value);
      return true;
    } catch (e) {
      debugPrint('[settings] 쓰기 보류($key): $e');
      return false;
    }
  }

  AppThemeMode get themeMode {
    final String? raw = _read<String>(kThemeMode);
    return AppThemeMode.values.firstWhere(
      (AppThemeMode m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _write(kThemeMode, mode.name);
  }

  String? get lastPlayedGameId => _read<String>(kLastPlayed);

  Future<void> setLastPlayedGameId(String id) async {
    await _write(kLastPlayed, id);
  }

  bool get seenInstallHint => _read<bool>(kSeenInstallHint) ?? false;

  Future<void> markInstallHintSeen() async {
    await _write(kSeenInstallHint, true);
  }
}
