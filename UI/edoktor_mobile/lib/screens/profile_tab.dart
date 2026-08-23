import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatar = _avatar(user?.image);
    return SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: CircleAvatar(
        radius: 44,
        backgroundColor: const Color(0xFFE3F2FD),
        backgroundImage: avatar,
        child: avatar == null ? Text(user?.firstName.isNotEmpty == true ? user!.firstName[0] : 'U', style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 32, fontWeight: FontWeight.bold)) : null,
      )),
      const SizedBox(height: 12),
      Center(child: Text(user?.fullName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      Center(child: Text(user?.email ?? '', style: const TextStyle(color: Colors.grey))),
      const SizedBox(height: 24),
      _row('Korisničko ime', user?.username ?? ''),
      _row('Telefon', user?.phoneNumber ?? '-'),
      _row('Grad', user?.cityName ?? '-'),
      _row('Krvna grupa', user?.bloodType ?? '-'),
      _row('Alergije', user?.allergies ?? '-'),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
        icon: const Icon(Icons.edit),
        label: const Text('Uredi profil'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
        icon: const Icon(Icons.lock),
        label: const Text('Promijeni lozinku'),
      ),
      const Spacer(),
      OutlinedButton.icon(onPressed: () => _logout(context), icon: const Icon(Icons.logout), label: const Text('Odjava')),
    ])));
  }

  ImageProvider? _avatar(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
    Expanded(child: Text(label, style: const TextStyle(color: Colors.grey))),
    Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
  ]));
}
