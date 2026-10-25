import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

enum AuthMode { signUp, signIn, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.mode});

  final AuthMode mode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.mode;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _nickname = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  bool get _isReset => _mode == AuthMode.reset;
  bool get _isSignUp => _mode == AuthMode.signUp;

  String get _title {
    switch (_mode) {
      case AuthMode.signUp:
        return '계정 만들기';
      case AuthMode.signIn:
        return '로그인';
      case AuthMode.reset:
        return '비밀번호 재설정';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final AppState state = context.read<AppState>();
    AuthResult result;

    try {
      switch (_mode) {
        case AuthMode.signUp:
          result = await state.signUp(
            email: _email.text,
            password: _password.text,
            nickname: _nickname.text,
          );
          break;
        case AuthMode.signIn:
          result = await state.signIn(
            email: _email.text,
            password: _password.text,
          );
          break;
        case AuthMode.reset:
          result = await state.sendPasswordReset(_email.text);
          break;
      }
    } catch (error) {
      result = AuthResult.fail(AuthFailure.unknown);
      debugPrint('[인증] 예외: $error');
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      setState(() => _error = result.message);
      return;
    }

    if (result.recoveryCode != null) {
      await _showRecoveryCode(result.recoveryCode!);
      if (!mounted) return;
    }

    if (_mode == AuthMode.reset) {
      setState(() {
        _mode = AuthMode.signIn;
        _password.clear();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호 재설정 메일을 보냈어요. 메일의 링크를 눌러 새 비밀번호를 정해 주세요.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  Future<void> _showRecoveryCode(String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('복구 코드를 꼭 보관해 주세요'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '비밀번호를 잊었을 때 이 코드로 계정을 되찾을 수 있어요. 앱에는 다시 표시되지 않습니다.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '메모장이나 비밀번호 관리자에 저장해 두세요.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('복구 코드를 복사했어요')));
              },
              child: const Text('복사'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              child: const Text('저장했어요'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: PastelBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: 20),
                      Text(
                        _title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isReset
                            ? '가입한 이메일로 비밀번호 재설정 링크를 보내 드려요.'
                            : '이메일과 비밀번호만 있으면 어느 기기에서든 기록이 이어져요.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 26),

                      if (_isSignUp) ...<Widget>[
                        _Label('닉네임'),
                        TextFormField(
                          controller: _nickname,
                          textInputAction: TextInputAction.next,
                          maxLength: 12,
                          decoration: const InputDecoration(
                            hintText: '게임에서 보여질 이름',
                            counterText: '',
                          ),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty)
                              ? '닉네임을 입력해 주세요'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _Label('이메일'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: _isReset
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onFieldSubmitted: (_) {
                          if (_isReset) _submit();
                        },
                        decoration: const InputDecoration(
                          hintText: 'hello@mudyogu.app',
                        ),
                        validator: (String? v) {
                          final String value = (v ?? '').trim();
                          if (value.isEmpty) return '이메일을 입력해 주세요';
                          if (!RegExp(
                            r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$',
                          ).hasMatch(value)) {
                            return '이메일 형식을 확인해 주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      if (!_isReset) _Label('비밀번호'),
                      if (!_isReset)
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: '6자 이상',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 19,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (String? v) {
                            if (v == null || v.isEmpty) return '비밀번호를 입력해 주세요';
                            if (v.length < 6) return '6자 이상 입력해 주세요';
                            return null;
                          },
                        ),

                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8788A,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFE8788A,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: Color(0xFFD45A6E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFFD45A6E),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 26),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF06301F),
                                ),
                              )
                            : Text(
                                _isSignUp
                                    ? '계정 만들기'
                                    : _isReset
                                    ? '재설정 메일 보내기'
                                    : '로그인',
                              ),
                      ),
                      const SizedBox(height: 12),

                      if (!_isReset)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _mode = _isSignUp
                                      ? AuthMode.signIn
                                      : AuthMode.signUp;
                                  _error = null;
                                }),
                          child: Text(
                            _isSignUp ? '이미 계정이 있어요' : '계정이 없어요, 만들기',
                          ),
                        ),

                      if (_mode == AuthMode.signIn)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _mode = AuthMode.reset;
                                  _error = null;
                                }),
                          child: const Text('비밀번호를 잊었어요'),
                        ),

                      if (_isReset)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _mode = AuthMode.signIn;
                                  _error = null;
                                }),
                          child: const Text('로그인으로 돌아가기'),
                        ),

                      const SizedBox(height: 18),
                      Text(
                        '계정과 기록은 온라인에 안전하게 저장돼요. 비밀번호는 암호화되어 아무도 볼 수 없어요.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
