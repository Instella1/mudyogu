export 'build_info.dart';
import 'package:flutter/foundation.dart';

/// 설치 안내 정보
@immutable
class InstallInfo {
  const InstallInfo({
    required this.canInstall,
    required this.isInstalled,
    required this.isIos,
    required this.isAndroid,
    required this.isDesktop,
  });

  final bool canInstall;
  final bool isInstalled;
  final bool isIos;
  final bool isAndroid;
  final bool isDesktop;

  static const InstallInfo none = InstallInfo(
    canInstall: false,
    isInstalled: false,
    isIos: false,
    isAndroid: false,
    isDesktop: false,
  );
}

/// 웹이 아닌 플랫폼용 스텁
class PwaService {
  PwaService._();
  static final PwaService instance = PwaService._();

  bool get updateAvailable => false;
  String? get remoteVersion => null;

  Future<void> registerServiceWorker() async {}
  Future<bool> checkForUpdate() async => false;

  Future<InstallInfo> inspect() async => InstallInfo.none;

  Future<void> promptInstall() async {}

  Future<void> applyUpdate() async {}

  void startUpdatePolling({
    Duration interval = const Duration(minutes: 5),
    void Function()? onUpdateFound,
  }) {}

  void dispose() {}
}
