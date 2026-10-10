import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ui.dart';

/// Two steps: request a 6-digit code by email, then enter the code with a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final message = await context.read<AuthProvider>().forgotPassword(_email.text);
      setState(() { _codeSent = true; _info = message; });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_resetForm.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().resetPassword(email: _email.text, code: _code.text, newPassword: _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lozinka je uspješno promijenjena. Prijavite se novom lozinkom.')));
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaboravljena lozinka')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            _codeSent
                ? 'Unesite 6-cifreni kod koji smo poslali na ${_email.text.trim()} i odaberite novu lozinku. Kod vrijedi 15 minuta.'
                : 'Unesite email adresu vašeg računa. Poslat ćemo vam kod za postavljanje nove lozinke.',
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          Form(
            key: _emailForm,
            child: TextFormField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => Validators.email(v),
            ),
          ),
          if (_codeSent) ...[
            const SizedBox(height: 14),
            Form(
              key: _resetForm,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Kod iz emaila', prefixIcon: Icon(Icons.pin_outlined), counterText: ''),
                  validator: (v) => RegExp(r'^\d{6}$').hasMatch(v?.trim() ?? '') ? null : 'Kod mora imati tačno 6 cifara (npr. 482913).',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova lozinka', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => Validators.password(v),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Potvrdi novu lozinku', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => Validators.confirm(v, _password.text),
                ),
              ]),
            ),
          ],
          if (_info != null && _error == null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(12)),
              child: Text(_info!, style: const TextStyle(color: AppColors.deep, fontSize: 13)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
            ),
          ],
          const SizedBox(height: 22),
          GradientButton(
            label: _codeSent ? 'Postavi novu lozinku' : 'Pošalji kod',
            icon: _codeSent ? Icons.check : Icons.send_outlined,
            busy: _busy,
            onPressed: _codeSent ? _reset : _sendCode,
          ),
          if (_codeSent) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => setState(() { _codeSent = false; _info = null; _error = null; _code.clear(); }),
              child: const Text('Niste dobili kod? Pošalji ponovo'),
            ),
          ],
        ]),
      ),
    );
  }
}
