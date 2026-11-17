import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

/// Password reset with an emailed 6-digit code (same API as the mobile app). Lets a doctor whose
/// temporary-password email never arrived set their own password.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});
  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().forgotPassword(_email.text);
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().resetPassword(email: _email.text, code: _code.text, newPassword: _password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zaboravljena lozinka'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_codeSent
            ? 'Ako račun sa adresom ${_email.text.trim()} postoji, na nju je poslan 6-cifreni kod. Kod vrijedi 15 minuta.'
            : 'Unesite email adresu vašeg računa. Poslat ćemo vam kod za postavljanje nove lozinke.',
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Form(key: _emailForm, child: TextFormField(
          controller: _email, enabled: !_codeSent, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          validator: (v) => Validators.email(v))),
        if (_codeSent) Form(key: _resetForm, autovalidateMode: AutovalidateMode.onUserInteraction, child: Column(children: [
          const SizedBox(height: 12),
          TextFormField(controller: _code, maxLength: 6,
            decoration: const InputDecoration(labelText: 'Kod iz emaila', border: OutlineInputBorder(), counterText: ''),
            validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Kod mora imati tačno 6 cifara.'),
          const SizedBox(height: 12),
          TextFormField(controller: _password, obscureText: true,
            decoration: const InputDecoration(labelText: 'Nova lozinka', border: OutlineInputBorder()),
            validator: (v) => (v ?? '').length < 6 ? 'Lozinka mora imati najmanje 6 znakova.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _confirm, obscureText: true,
            decoration: const InputDecoration(labelText: 'Potvrdi novu lozinku', border: OutlineInputBorder()),
            validator: (v) => v != _password.text ? 'Lozinke se ne podudaraju.' : null),
        ])),
        if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
      ]))),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Odustani')),
        FilledButton(
          onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
          child: Text(_busy ? '...' : (_codeSent ? 'Postavi novu lozinku' : 'Pošalji kod'))),
      ],
    );
  }
}
