import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().changePassword(_old.text, _new.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lozinka je uspješno promijenjena.')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promijeni lozinku')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'Trenutna lozinka', border: OutlineInputBorder()), validator: (v) => Validators.required(v, 'Trenutna lozinka')),
            const SizedBox(height: 12),
            TextFormField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nova lozinka', border: OutlineInputBorder()), validator: (v) => Validators.password(v)),
            const SizedBox(height: 12),
            TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Potvrdi novu lozinku', border: OutlineInputBorder()), validator: (v) => Validators.confirm(v, _new.text)),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? 'Spremanje...' : 'Promijeni lozinku'))),
          ]),
        ),
      ),
    );
  }
}
