import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController(text: 'admin');
  final _pwd = TextEditingController(text: 'stringst');
  bool _busy = false; String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().login(_user.text, _pwd.text);
      if (!mounted) return;
      if (context.read<AuthProvider>().user?.role != 'admin') {
        await context.read<AuthProvider>().logout();
        setState(() => _error = 'Samo admin nalozi mogu pristupiti desktop aplikaciji.');
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    } catch (e) { setState(() => _error = '$e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Card(
        elevation: 4,
        child: Padding(padding: const EdgeInsets.all(32), child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('eDoktor Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text('Prijava administratora', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          TextFormField(controller: _user, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Korisničko ime', border: OutlineInputBorder()),
            validator: (v) => Validators.required(v, 'Korisničko ime')),
          const SizedBox(height: 12),
          TextFormField(controller: _pwd, obscureText: true, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Lozinka', border: OutlineInputBorder()),
            validator: (v) => Validators.required(v, 'Lozinka')),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _login, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? '...' : 'Prijava'))),
        ]))),
      ))),
    );
  }
}
