import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/game_info.dart';
import '../services/auth_service.dart';
import '../services/pwa_service.dart';
import '../services/settings_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = context.watch<AppState>();
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: PastelBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: <Widget>[
              // 계정
              _SectionLabel('계정'),
              _Card(
                children: <Widget>[
                  _AccountTile(state: state),
                ],
              ),
              const SizedBox(height: 20),

              // 테마
              _SectionLabel('화면'),
              _Card(
                children: <Widget>[
                  ...AppThemeMode.values.map(
                    (AppThemeMode mode) => _ChoiceTile(
                      label: mode.label,
                      icon: switch (mode) {
                        AppThemeMode.system => Icons.brightness_auto_rounded,
                        AppThemeMode.light => Icons.light_mode_rounded,
                        AppThemeMode.dark => Icons.dark_mode_rounded,
                      },
                      selected: state.settings.themeMode == mode,
                      onTap: () async {
                        await state.settings.setThemeMode(mode);
                        state.notifyThemeChanged();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 앱 / 설치
              _SectionLabel('앱'),
              _Card(
                children: <Widget>[
                  _InfoTile(
                    icon: Icons.install_desktop_rounded,
                    title: '홈 화면에 설치',
                    subtitle: '오프라인에서도 실행할 수 있어요',
                    onTap: () => showInstallSheet(context),
                  ),
                  _InfoTile(
                    icon: Icons.system_update_rounded,
                    title: '업데이트 확인',
                    subtitle: '새 버전이 있으면 알려드려요',
                    onTap: () async {
                      final bool has =
                          await PwaService.instance.checkForUpdate();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            has ? '새 버전이 있어요. 상단 배너에서 새로고침해 주세요.' : '최신 버전을 사용 중이에요.',
                          ),
                        ),
                      );
                    },
                  ),
                  _InfoTile(
                    icon: Icons.info_outline_rounded,
                    title: '버전',
                    subtitle:
                        'v${BuildInfo.version}${BuildInfo.buildId.isEmpty ? '' : ' · ${BuildInfo.buildId}'}',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 기록
              _SectionLabel('기록'),
              _Card(
                children: <Widget>[
                  ...state.games.map((GameInfo g) {
                    final GameProgress p = state.progressFor(g.id);
                    return _ProgressTile(
                      game: g,
                      progress: p,
                      onReset: () => _confirmReset(context, state, g),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _confirmResetAll(context, state),
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('모든 기록 초기화'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: const Color(0xFFD45A6E),
                  side: BorderSide(
                    color: const Color(0xFFD45A6E).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 계정 관리
              _SectionLabel('계정 관리'),
              _Card(
                children: <Widget>[
                  if (state.isSignedIn) ...<Widget>[
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      title: '닉네임 변경',
                      subtitle: state.displayName,
                      onTap: () => _editNickname(context, state),
                    ),
                    _InfoTile(
                      icon: Icons.logout_rounded,
                      title: '로그아웃',
                      subtitle: '게스트로 계속 플레이합니다',
                      onTap: () => _confirmSignOut(context, state),
                    ),
                    _InfoTile(
                      icon: Icons.person_remove_outlined,
                      title: '계정 삭제',
                      subtitle: '이 기기의 계정과 기록이 삭제됩니다',
                      danger: true,
                      onTap: () => _confirmDelete(context, state),
                    ),
                  ] else
                    _InfoTile(
                      icon: Icons.login_rounded,
                      title: '로그인 / 계정 만들기',
                      subtitle: '기록을 계정에 저장할 수 있어요',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AuthScreen(
                            mode: AuthMode.signIn,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  '뮤됴구 · Made for hobby',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    AppState state,
    GameInfo game,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('기록 초기화'),
        content: Text('${game.title}의 최고 점수와 진행 상황을 지울까요?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
              backgroundColor: const Color(0xFFD45A6E),
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (ok == true) await state.resetProgress(game.id);
  }

  Future<void> _confirmResetAll(BuildContext context, AppState state) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('모든 기록 초기화'),
        content: const Text('모든 게임의 기록이 사라져요. 되돌릴 수 없습니다.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
              backgroundColor: const Color(0xFFD45A6E),
            ),
            child: const Text('모두 삭제'),
          ),
        ],
      ),
    );
    if (ok == true) await state.resetAllProgress();
  }

  Future<void> _editNickname(BuildContext context, AppState state) async {
    final TextEditingController controller = TextEditingController(
      text: state.displayName,
    );
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(
            hintText: '새 닉네임',
            counterText: '',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(84, 44)),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null || next.isEmpty) return;

    final AuthResult result = await state.updateNickname(next);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.ok ? '닉네임을 변경했어요' : result.message)),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AppState state) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하면 게스트 기록으로 전환돼요. 계정 기록은 그대로 남아 있어요.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(84, 44)),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.signOut();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('계정 삭제'),
        content: const Text('이 기기에 저장된 계정과 모든 기록이 완전히 삭제됩니다. 계속할까요?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(84, 44),
              backgroundColor: const Color(0xFFD45A6E),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: theme.dividerColor, indent: 52),
          ],
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Account? account = state.account;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF63E6B0), AppColors.brand],
              ),
              borderRadius: BorderRadius.circular(14),
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account == null ? '게스트 모드' : account.email,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (account == null)
            const _Pill(text: '게스트')
          else
            const _Pill(text: '로그인됨'),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.brandDeep,
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.brandDeep : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 19,
                color: AppColors.brand,
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: danger ? const Color(0xFFD45A6E) : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: danger ? const Color(0xFFD45A6E) : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.textTheme.bodySmall?.color,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.game,
    required this.progress,
    required this.onReset,
  });

  final GameInfo game;
  final GameProgress progress;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: game.accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.sports_esports_rounded,
              size: 17,
              color: game.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  game.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${game.bestScoreLabel} ${progress.bestScore} · ${progress.playCount}회 플레이',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                if (progress.hasSaveCode) ...<Widget>[
                  const SizedBox(height: 5),
                  _SaveCodeChip(
                    game: game,
                    progress: progress,
                    onTap: () => _showSaveCode(context, game, progress),
                  ),
                ],
              ],
            ),
          ),
          if (progress.playCount > 0)
            IconButton(
              onPressed: onReset,
              iconSize: 17,
              visualDensity: VisualDensity.compact,
              tooltip: '초기화',
              icon: Icon(
                Icons.refresh_rounded,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
        ],
      ),
    );
  }
}

/// 게임이 보관해 둔 "저장 코드" 배지
class _SaveCodeChip extends StatelessWidget {
  const _SaveCodeChip({
    required this.game,
    required this.progress,
    required this.onTap,
  });

  final GameInfo game;
  final GameProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.qr_code_2_rounded,
              size: 12,
              color: AppColors.brandDeep,
            ),
            const SizedBox(width: 4),
            Text(
              '기록 코드 보관됨',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark
                    ? AppColors.brand
                    : AppColors.brandDeep,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right_rounded,
              size: 13,
              color: theme.brightness == Brightness.dark
                  ? AppColors.brand
                  : AppColors.brandDeep,
            ),
          ],
        ),
      ),
    );
  }
}

/// 보관된 저장 코드를 보여주고 복사할 수 있는 시트
void _showSaveCode(
  BuildContext context,
  GameInfo game,
  GameProgress progress,
) {
  final String code = progress.saveCode;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      final ThemeData theme = Theme.of(ctx);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: game.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 17,
                    color: game.accentColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${game.title} 기록 코드',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '이 코드를 다른 기기에서 게임의 "기록 코드로 불러오기"에 붙여넣으면 '
              '진행상황이 그대로 복원됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 14),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('기록 코드를 복사했어요')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('코드 복사'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppColors.brand,
              ),
            ),
          ],
        ),
      );
    },
  );
}
