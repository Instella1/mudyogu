import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/local_store.dart';
import 'services/progress_service.dart';
import 'services/pwa_service.dart';
import 'services/settings_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final LocalStore store = LocalStore.instance;

  // Hive 를 runApp 이전에 초기화합니다.
  //
  // 첫 프레임에서 설정(테마 등)을 읽기 때문에, 초기화가 늦으면
  // `Box not found` 가 나고 테마가 한 번 깜빡입니다.
  try {
    await store.init();
  } catch (e) {
    debugPrint('[boot] 저장소 초기화 실패: $e');
  }

  final AppState appState = AppState(
    store: store,
    auth: AuthService(store),
    progress: ProgressService(store),
    catalog: CatalogService(store),
    settings: SettingsService(store),
  );

  // 웹: 서비스워커 등록 + 설치 프롬프트 캡처
  if (kIsWeb) {
    PwaService.instance.registerServiceWorker();
  }

  runApp(MudyoguApp(appState: appState));
}

class MudyoguApp extends StatefulWidget {
  const MudyoguApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<MudyoguApp> createState() => _MudyoguAppState();
}

class _MudyoguAppState extends State<MudyoguApp> {
  @override
  void initState() {
    super.initState();
    widget.appState.bootstrap();

    // 앱 시작 후 새 버전 폴링 (3분)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PwaService.instance.startUpdatePolling(
          interval: const Duration(minutes: 3),
          onUpdateFound: () => debugPrint('[PWA] 새 버전 발견'),
        );
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) PwaService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.appState,
      child: Consumer<AppState>(
        builder: (BuildContext context, AppState state, _) {
          final ThemeMode mode = state.settings.themeMode.themeMode;
          return MaterialApp(
            title: '뮤됴구',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: state.isBooting
                ? const _Splash()
                : state.isSignedIn || state.auth.isGuest
                ? const HomeScreen()
                : const WelcomeScreen(),
            builder: (BuildContext context, Widget? child) {
              return MediaQuery.withClampedTextScaling(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.25,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF63E6B0),
                    AppColors.brand,
                    Color(0xFF14AC76),
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  '뮤',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF06301F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
