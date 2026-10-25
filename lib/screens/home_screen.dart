import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../services/pwa_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/game_card.dart';
import '../widgets/update_banner.dart';
import 'auth_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _updateAvailable = false;
  bool _bannerDismissed = false;
  bool _offlineReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
      _checkOffline();
      final String? merge = context.read<AppState>().lastMergeNotice;
      if (merge != null) {
        _showMergeNotice(merge);
      }
    });
  }

  void _showMergeNotice(String message) {
    context.read<AppState>().clearMergeNotice();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    final PwaService pwa = PwaService.instance;
    final bool available = await pwa.checkForUpdate();
    if (!mounted) return;
    setState(() => _updateAvailable = available);
  }

  Future<void> _checkOffline() async {
    final PwaService pwa = PwaService.instance;
    final InstallInfo info = await pwa.inspect();
    if (!mounted) return;
    setState(() => _offlineReady = info.isInstalled);
  }

  Future<void> _openGame(GameInfo game) async {
    final AppState state = context.read<AppState>();
    await state.applyProgress(gameId: game.id, countAsPlay: true);
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => GameScreen(game: game)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PastelBackdrop(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await _checkUpdate();
              await _checkOffline();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    children: <Widget>[
                      if (_updateAvailable && !_bannerDismissed)
                        UpdateBanner(
                          version: PwaService.instance.remoteVersion,
                          onUpdate: () => PwaService.instance.applyUpdate(),
                          onDismiss: () =>
                              setState(() => _bannerDismissed = true),
                        ),
                      if (state.isSignedIn == false || state.isLocalOnly)
                        _GuestNotice(
                          text: state.isLocalOnly
                              ? '이 기기에만 저장된 계정이에요. 한 번 다시 로그인하면 다른 기기에서도 기록이 이어져요.'
                              : '게스트로 플레이 중이에요. 로그인하면 기록이 계정에 저장돼요.',
                          button: state.isLocalOnly ? '다시 로그인' : '로그인',
                          onSignIn: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const AuthScreen(mode: AuthMode.signIn),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: _Header(
                    state: state,
                    offlineReady: _offlineReady,
                    onSettings: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    onInstall: () => showInstallSheet(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: SectionTitle(
                      title: '게임',
                      subtitle: '${state.games.length}개의 게임이 준비되어 있어요',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                  sliver: SliverLayoutBuilder(
                    builder:
                        (BuildContext context, SliverConstraints constraints) {
                          final double width = constraints.crossAxisExtent;
                          final int columns = width > 900
                              ? 5
                              : width > 700
                              ? 4
                              : width > 480
                              ? 3
                              : 2;
                          // 게임이 2개뿐이라 넓은 화면(크롬북)에서 오른쪽이 비어 보인다.
                          // → 게임 수에 맞춰 열 수를 줄이고, 카드를 크게 + 가운데 정렬.
                          final int gameCount = state.games.length;
                          final int cols = gameCount < columns
                              ? gameCount
                              : columns;
                          final double cardExtent = width > 700 ? 240 : 196;

                          // 전체 그리드 폭을 카드 수에 맞춰 제한하고 좌우를 균등하게
                          final double maxGridWidth =
                              cols * 260.0 + (cols - 1) * 14.0;
                          final double sidePad = width > maxGridWidth + 40
                              ? (width - maxGridWidth) / 2
                              : 0;

                          // Sliver 를 일반 위젯(Padding)으로 감싸면 렌더링되지 않는다.
                          // 좌우 여백은 SliverPadding 으로 준다.
                          return SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: sidePad),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: cardExtent,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                BuildContext context,
                                int index,
                              ) {
                                final GameInfo game = state.games[index];
                                return GameCard(
                                  game: game,
                                  state: state,
                                  index: index,
                                  onTap: () => _openGame(game),
                                );
                              }, childCount: state.games.length),
                            ),
                          );
                        },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Center(
                      child: Text(
                        '뮤됴구 · v${BuildInfo.version}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그인 화면 래퍼

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.offlineReady,
    required this.onSettings,
    required this.onInstall,
  });

  final AppState state;
  final bool offlineReady;
  final VoidCallback onSettings;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Account? account = state.account;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
            child: Center(
              child: Text(
                account == null ? '뮤' : state.initialLetter,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF06301F),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account == null
                      ? '안녕하세요, 게스트님'
                      : '안녕하세요, ${state.displayName}님',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text(
                      account == null ? '로그인하면 기록이 안전해요' : '오늘도 한 판 어때요?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onInstall,
            tooltip: '설치',
            iconSize: 19,
            icon: Icon(
              offlineReady
                  ? Icons.install_desktop_rounded
                  : Icons.download_for_offline_outlined,
            ),
          ),
          IconButton(
            onPressed: onSettings,
            tooltip: '설정',
            iconSize: 21,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _GuestNotice extends StatelessWidget {
  const _GuestNotice({
    required this.onSignIn,
    required this.text,
    required this.button,
  });

  final VoidCallback onSignIn;
  final String text;
  final String button;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.lavender.withValues(alpha: 0.14)
            : AppColors.lavender.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.person_outline_rounded, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(button),
          ),
        ],
      ),
    );
  }
}
