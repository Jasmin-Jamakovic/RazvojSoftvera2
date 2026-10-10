import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _push(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final avatar = _avatar(user?.image);
    String orDash(String? v) => (v == null || v.trim().isEmpty) ? '-' : v;
    final chips = [user?.bloodType, user?.cityName, user?.username].whereType<String>().where((s) => s.isNotEmpty);

    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 20, 18, 24),
        decoration: const BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.mint,
              backgroundImage: avatar,
              child: avatar == null
                  ? Text(user == null ? 'U' : initialsOf(user.fullName),
                      style: const TextStyle(color: AppColors.deep, fontSize: 30, fontWeight: FontWeight.bold))
                  : null,
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), boxShadow: AppColors.softShadow),
                child: IconSquare(Icons.edit, size: 30, iconSize: 15, background: Colors.white, onTap: () => _push(context, const ProfileEditScreen())),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user?.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
              for (final c in chips) Pill(c, fg: Colors.white, bg: Colors.white.withValues(alpha: 0.16)),
            ]),
          ],
        ]),
      ),
      const GroupLabel('Lični podaci'),
      _Menu(children: [
        _MenuItem(icon: Icons.person_outline, label: 'Uredi profil', onTap: () => _push(context, const ProfileEditScreen())),
        _MenuItem(icon: Icons.phone_outlined, label: 'Telefon', value: orDash(user?.phoneNumber)),
        _MenuItem(icon: Icons.location_city_outlined, label: 'Grad', value: orDash(user?.cityName)),
        _MenuItem(icon: Icons.bloodtype_outlined, label: 'Krvna grupa', value: orDash(user?.bloodType)),
        _MenuItem(icon: Icons.warning_amber_rounded, label: 'Alergije', value: orDash(user?.allergies)),
      ]),
      const GroupLabel('Sigurnost i obavještenja'),
      _Menu(children: [
        _MenuItem(icon: Icons.lock_outline, label: 'Promijeni lozinku', onTap: () => _push(context, const ChangePasswordScreen())),
        _MenuItem(icon: Icons.notifications_outlined, label: 'Obavještenja', onTap: () => _push(context, const NotificationsScreen())),
      ]),
      const SizedBox(height: 16),
      _Menu(children: [
        _MenuItem(icon: Icons.logout, label: 'Odjava', danger: true, onTap: () => _logout(context)),
      ]),
      const SizedBox(height: 20),
    ]);
  }

  ImageProvider? _avatar(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }
}

class _Menu extends StatelessWidget {
  final List<Widget> children;
  const _Menu({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60, color: Color(0xFFF0F2F6)),
            children[i],
          ],
        ]),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  const _MenuItem({required this.icon, required this.label, this.value, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconSquare(icon, size: 34, iconSize: 18, color: danger ? red : AppColors.primary, background: danger ? const Color(0xFFFDECEA) : AppColors.tint),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: danger ? red : AppColors.ink, fontWeight: danger ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 12),
          Expanded(
            child: value != null
                ? Text(value!, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted))
                : const SizedBox.shrink(),
          ),
          if (onTap != null && !danger) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ]),
      ),
    );
  }
}
