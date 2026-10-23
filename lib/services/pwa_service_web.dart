export 'build_info.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'build_info.dart';

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

  String get platformLabel {
    if (isIos) return 'iOS';
    if (isAndroid) return 'Android';
    if (isDesktop) return '데스크톱';
    return '웹';
  }
}

/// PWA 설치 / 새 버전 감지 (웹 전용)
class PwaService {
  PwaService._();
  static final PwaService instance = PwaService._();

  JSFunction? _installHandler;
  JSObject? _deferredPrompt;
  bool _updateAvailable = false;
  String? _remoteVersion;
  Timer? _pollTimer;
  void Function()? _onUpdateFound;

  bool get updateAvailable => _updateAvailable;
  String? get remoteVersion => _remoteVersion;

  String get _ua => web.window.navigator.userAgent;

  bool get isIos =>
      _ua.contains('iPhone') || _ua.contains('iPad') || _ua.contains('iPod');
  bool get isAndroid => _ua.contains('Android');
  bool get isDesktop => !isIos && !isAndroid;

  bool get isInstalled {
    try {
      return web.window.matchMedia('(display-mode: standalone)').matches ||
          web.window.matchMedia('(display-mode: fullscreen)').matches ||
          web.window.matchMedia('(display-mode: minimal-ui)').matches;
    } catch (_) {
      return false;
    }
  }

  Future<InstallInfo> inspect() async => InstallInfo(
    canInstall: _deferredPrompt != null,
    isInstalled: isInstalled,
    isIos: isIos,
    isAndroid: isAndroid,
    isDesktop: isDesktop,
  );

  /// beforeinstallprompt 이벤트 캡처 (main 에서 1회)
  void attachInstallPrompt({void Function()? onAvailable}) {
    final JSFunction handler = ((web.Event event) {
      event.preventDefault();
      _deferredPrompt = event as JSObject;
      onAvailable?.call();
    }).toJS;

    _installHandler = handler;
    web.window.addEventListener('beforeinstallprompt', handler);
  }

  Future<void> promptInstall() async {
    final JSObject? prompt = _deferredPrompt;
    if (prompt == null) return;
    try {
      (prompt as JSObject?)?.callMethod<JSAny?>('prompt'.toJS);
    } catch (error) {
      debugPrint('[PWA] 설치 프롬프트 실패: $error');
    }
    _deferredPrompt = null;
  }

  /// 서비스워커 등록
  Future<void> registerServiceWorker() async {
    try {
      // 상대 경로로 등록합니다. 절대 경로('/...')로 두면 하위 폴더에 배포했을 때
      // (예: https://example.com/mudyogu/) 404 가 나고 오프라인이 깨집니다.
      await web.window.navigator.serviceWorker
          .register('service_worker.js'.toJS)
          .toDart;
      debugPrint('[PWA] 서비스워커 등록 완료');
    } catch (error) {
      debugPrint('[PWA] 서비스워커 등록 실패: $error');
    }
  }

  /// 새 버전 감지 폴링 시작
  void startUpdatePolling({
    Duration interval = const Duration(minutes: 3),
    void Function()? onUpdateFound,
  }) {
    _onUpdateFound = onUpdateFound;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => checkForUpdate());
    checkForUpdate();
  }

  /// version.json 을 읽어 현재 빌드와 비교
  Future<bool> checkForUpdate() async {
    try {
      final String url =
          'version.json?t=${DateTime.now().millisecondsSinceEpoch}';
      final web.Response response =
          await web.window.fetch(url.toJS).toDart;
      if (response.status != 200) return false;

      final JSString body = await response.text().toDart;
      final Map<String, dynamic> meta =
          jsonDecode(body.toDart) as Map<String, dynamic>;

      final String? remote = meta['buildId']?.toString();
      if (remote == null || remote.isEmpty) return false;

      final String current = BuildInfo.buildId;
      if (current.isNotEmpty && remote != current) {
        if (!_updateAvailable) {
          _updateAvailable = true;
          _remoteVersion = remote;
          _onUpdateFound?.call();
        }
        return true;
      }
    } catch (error) {
      debugPrint('[PWA] 업데이트 확인 실패: $error');
    }
    return false;
  }

  /// 새 버전 적용: 캐시 비우고 새로고침
  Future<void> applyUpdate() async {
    try {
      final web.CacheStorage caches = web.window.caches;
      final JSArray<JSString> keys = await caches.keys().toDart;
      for (final JSString key in keys.toDart) {
        await caches.delete(key.toDart).toDart;
      }
    } catch (error) {
      debugPrint('[PWA] 캐시 정리 실패: $error');
    }
    web.window.location.reload();
  }

  void dispose() {
    _pollTimer?.cancel();
    final JSFunction? handler = _installHandler;
    if (handler != null) {
      web.window.removeEventListener('beforeinstallprompt', handler);
    }
  }
}
