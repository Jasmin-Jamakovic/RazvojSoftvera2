import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pwd = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().login(_user.text, _pwd.text);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: IntrinsicHeight(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                height: size.height * 0.42,
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 52),
                decoration: const BoxDecoration(gradient: AppColors.gradient),
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    top: -60,
                    right: -90,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mint.withValues(alpha: 0.14)),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.local_hospital, color: AppColors.primary, size: 30),
                      ),
                      const SizedBox(height: 18),
                      const Text.rich(TextSpan(
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                        children: [TextSpan(text: 'e'), TextSpan(text: 'Doktor', style: TextStyle(color: AppColors.mint))],
                      )),
                      const SizedBox(height: 4),
                      Text('Vaš doktor na dohvat ruke', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -28),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text('Prijava', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                        const SizedBox(height: 4),
                        const Text('Prijavite se da zakažete pregled.', style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _user,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Korisničko ime', prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => Validators.required(v, 'Korisničko ime'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _pwd,
                          obscureText: true,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onFieldSubmitted: (_) => _busy ? null : _login(),
                          decoration: const InputDecoration(labelText: 'Lozinka', prefixIcon: Icon(Icons.lock_outline)),
                          validator: (v) => Validators.required(v, 'Lozinka'),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            child: const Text('Zaboravili ste lozinku?'),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                            child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        GradientButton(label: 'Prijavi se', busy: _busy, onPressed: _login),
                        const Spacer(),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: const Text.rich(TextSpan(
                              style: TextStyle(color: AppColors.muted),
                              children: [
                                TextSpan(text: 'Nemate račun? '),
                                TextSpan(text: 'Registrujte se', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            )),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
