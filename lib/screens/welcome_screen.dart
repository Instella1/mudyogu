import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/pwa_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';

/// 첫 진입 화면: 시작하기 / 게스트 / 로그인
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppState state = context.watch<AppState>();

    return Scaffold(
      body: PastelBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const _Logo(),
                    const SizedBox(height: 26),
                    Text(
                      '뮤됴구',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 40,
                        letterSpacing: -1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '작은 게임들을 한 곳에서',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _FeatureRow(
                      icon: Icons.offline_bolt_rounded,
                      title: '인터넷 없이도',
                      body: '한 번 열어두면 오프라인에서도 그대로 플레이',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.sync_rounded,
                      title: '기록은 자동 저장',
                      body: '게스트로 시작하고, 로그인하면 계정으로 합쳐져요',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.devices_rounded,
                      title: '어디서든 같은 화면',
                      body: '크롬북·태블릿·휴대폰 모두 같은 UI',
                    ),
                    const SizedBox(height: 36),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(mode: AuthMode.signUp),
                        ),
                      ),
                      child: const Text('시작하기'),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () async {
                          await state.continueAsGuest();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          side: BorderSide(color: theme.dividerColor),
                          foregroundColor: theme.textTheme.bodyMedium?.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        child: const Text('게스트로 둘러보기'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(mode: AuthMode.signIn),
                        ),
                      ),
                      child: const Text('이미 계정이 있어요'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '같은 계정으로 어느 기기에서든 이어져요',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF5FE3AE), AppColors.brand, Color(0xFF17B47C)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '뮤',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: Color(0xFF06301F),
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.brandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 설치 안내 시트 (홈에서 호출)
Future<void> showInstallSheet(BuildContext context) async {
  final PwaService pwa = PwaService.instance;
  final InstallInfo info = await pwa.inspect();
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      final ThemeData theme = Theme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('홈 화면에 추가', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '설치하면 주소창 없이 앱처럼 열리고, 오프라인에서도 실행돼요.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            if (info.isInstalled)
              const _InstallDone()
            else if (info.canInstall)
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await pwa.promptInstall();
                },
                child: const Text('지금 설치'),
              )
            else
              _ManualInstallSteps(info: info),
          ],
        ),
      );
    },
  );
}

class _InstallDone extends StatelessWidget {
  const _InstallDone();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.check_circle_rounded, color: AppColors.brand),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '이미 설치되어 있어요. 앱처럼 실행 중입니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ManualInstallSteps extends StatelessWidget {
  const _ManualInstallSteps({required this.info});

  final InstallInfo info;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> steps;
    if (info.isIos) {
      steps = <String>[
        'Safari 하단의 공유 버튼을 누릅니다',
        '“홈 화면에 추가”를 선택합니다',
        '우측 상단 “추가”를 누르면 완료',
      ];
    } else if (info.isAndroid) {
      steps = <String>[
        'Chrome 우측 상단 ⋮ 메뉴를 엽니다',
        '“앱 설치” 또는 “홈 화면에 추가”를 선택합니다',
        '설치를 확인하면 완료',
      ];
    } else {
      steps = <String>[
        '주소창 오른쪽의 설치 아이콘(⊕)을 클릭합니다',
        '또는 브라우저 메뉴 → “앱 설치”를 선택합니다',
        'Chromebook은 런처에 앱으로 등록됩니다',
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(steps[i], style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
