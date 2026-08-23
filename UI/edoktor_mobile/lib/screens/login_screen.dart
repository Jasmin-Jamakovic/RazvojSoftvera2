import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import 'register_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController(text: 'patient1');
  final _pwd = TextEditingController(text: 'stringst');
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(key: _formKey, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              const Center(child: Text('eDoktor', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)))),
              const SizedBox(height: 8),
              const Center(child: Text('Vaš doktor na dohvat ruke', style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 60),
              TextFormField(controller: _user, autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: 'Korisničko ime', border: OutlineInputBorder()),
                validator: (v) => Validators.required(v, 'Korisničko ime')),
              const SizedBox(height: 16),
              TextFormField(controller: _pwd, obscureText: true, autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: 'Lozinka', border: OutlineInputBorder()),
                validator: (v) => Validators.required(v, 'Lozinka')),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: _busy ? null : _login, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? '...' : 'Prijava'))),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text('Nemate račun? Registrujte se')),
            ],
          )),
        ),
      ),
    );
  }
}
