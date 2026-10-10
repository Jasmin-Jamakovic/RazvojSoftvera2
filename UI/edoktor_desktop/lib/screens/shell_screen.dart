import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import 'dashboard_screen.dart';
import 'doctors_screen.dart';
import 'specializations_screen.dart';
import 'clinics_screen.dart';
import 'cities_screen.dart';
import 'appointments_screen.dart';
import 'patients_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _idx = 0;

  static const _items = [
    ('Dashboard', Icons.dashboard),
    ('Ljekari', Icons.medical_services),
    ('Specijalizacije', Icons.category),
    ('Klinike', Icons.local_hospital),
    ('Gradovi', Icons.location_city),
    ('Termini', Icons.event),
    ('Pacijenti', Icons.people),
    ('Izvještaji', Icons.bar_chart),
  ];

  Widget _page(int i) => switch (i) {
        0 => const DashboardScreen(),
        1 => const DoctorsScreen(),
        2 => const SpecializationsScreen(),
        3 => const ClinicsScreen(),
        4 => const CitiesScreen(),
        5 => const AppointmentsScreen(),
        6 => const PatientsScreen(),
        7 => const ReportsScreen(),
        _ => const SizedBox(),
      };

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Sidebar(
            items: _items,
            selected: _idx,
            onSelect: (i) => setState(() => _idx = i),
            userName: user?.fullName ?? '',
            onLogout: _logout,
          ),
          const SizedBox(width: 14),
          Expanded(child: _page(_idx)),
        ]),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final String userName;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.userName,
    required this.onLogout,
  });

  String get _initials {
    final parts = userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D47A1), Color(0xFF123C86), Color(0xFF0B2C63)],
          stops: [0, 0.6, 1],
        ),
        boxShadow: const [BoxShadow(color: Color(0x590D47A1), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.3),
              children: [TextSpan(text: 'e'), TextSpan(text: 'Doktor', style: TextStyle(color: Color(0xFF8EC5FF)))],
            )),
            SizedBox(height: 2),
            Text('Admin Panel', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, i) => _NavItem(
              label: items[i].$1,
              icon: items[i].$2,
              active: i == selected,
              onTap: () => onSelect(i),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF8EC5FF),
                child: Text(_initials, style: const TextStyle(color: Color(0xFF0B2C63), fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(userName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const Text('Administrator', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Odjava'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  static const _duration = Duration(milliseconds: 120);
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final rowColor = active
        ? Colors.white.withValues(alpha: 0.14)
        : _hover
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: rowColor, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            AnimatedContainer(
              duration: _duration,
              curve: Curves.easeOut,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(widget.icon, size: 18, color: active ? const Color(0xFF0D47A1) : Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: _duration,
                curve: Curves.easeOut,
                style: TextStyle(
                  color: active || _hover ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(widget.label, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
