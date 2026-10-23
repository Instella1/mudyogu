import 'package:hive_flutter/hive_flutter.dart';

/// Hive 기반 로컬 저장소.
///
/// 박스 구성
/// - `accounts`     : 이메일 → 계정 레코드(해시)
/// - `session`      : 현재 로그인 세션 / 게스트 여부
/// - `progress_u_*` : 사용자별 게임 진행상황 (계정별 분리)
/// - `progress_guest`: 게스트 진행상황
/// - `settings`     : 앱 설정
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String accountsBox = 'accounts';
  static const String sessionBox = 'session';
  static const String settingsBox = 'settings';
  static const String guestBox = 'progress_guest';

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Future.wait(<Future<void>>[
      Hive.openBox<dynamic>(accountsBox),
      Hive.openBox<dynamic>(sessionBox),
      Hive.openBox<dynamic>(settingsBox),
      Hive.openBox<dynamic>(guestBox),
    ]);
    _ready = true;
  }

  Box<dynamic> get accounts => Hive.box<dynamic>(accountsBox);
  Box<dynamic> get session => Hive.box<dynamic>(sessionBox);
  Box<dynamic> get settings => Hive.box<dynamic>(settingsBox);
  Box<dynamic> get guest => Hive.box<dynamic>(guestBox);

  /// 사용자별 진행상황 박스 이름
  static String progressBoxName(String? email) {
    if (email == null || email.isEmpty) return guestBox;
    final String safe = email
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'progress_u_$safe';
  }

  Future<Box<dynamic>> openProgress(String? email) async {
    final String name = progressBoxName(email);
    if (Hive.isBoxOpen(name)) return Hive.box<dynamic>(name);
    return Hive.openBox<dynamic>(name);
  }

  /// 계정 삭제 시 진행 박스 제거
  Future<void> deleteProgress(String email) async {
    final String name = progressBoxName(email);
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).deleteFromDisk();
    } else {
      await Hive.deleteBoxFromDisk(name);
    }
  }
}
