import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';

/// 새 비밀번호 정하기 창.
///
/// 임시 비밀번호(메일로 받은 숫자)로 로그인한 뒤 바로 뜨고, 설정 화면에서도 연다.
/// 바꾸기 전까지는 원래 비밀번호와 임시 비밀번호 둘 다 쓸 수 있다.
/// 바꾸면 true.
Future<bool> showChangePasswordDialog(
  BuildContext context,
  AppState state, {
  bool afterTempLogin = false,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    barrierDismissible: !afterTempLogin,
    builder: (_) =>
        _ChangePasswordDialog(state: state, afterTempLogin: afterTempLogin),
  );
  return ok ?? false;
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.state,
    required this.afterTempLogin,
  });

  final AppState state;
  final bool afterTempLogin;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _p1 = TextEditingController();
  final TextEditingController _p2 = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_p1.text.length < 6) {
      setState(() => _error = '6자 이상 입력해 주세요.');
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() => _error = '두 비밀번호가 달라요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final AuthResult r = await widget.state.changePassword(_p1.text);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('새 비밀번호 정하기'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.afterTempLogin
                  ? '임시 비밀번호로 로그인했어요. 앞으로 쓸 비밀번호를 정해 주세요. '
                        '정하기 전까지는 원래 비밀번호도 그대로 쓸 수 있어요.'
                  : '앞으로 쓸 비밀번호를 정해 주세요. 다른 기기에서도 새 비밀번호로 로그인해요.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _p1,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '새 비밀번호 (6자 이상)',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 19,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _p2,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(hintText: '한 번 더'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFD45A6E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.afterTempLogin ? '나중에' : '취소'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('바꾸기'),
        ),
      ],
    );
  }
}
