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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: true,
          minExtendedWidth: 220,
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          backgroundColor: const Color(0xFF0D47A1),
          selectedIconTheme: const IconThemeData(color: Colors.white),
          unselectedIconTheme: const IconThemeData(color: Colors.white70),
          selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              const Text('eDoktor', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Admin Panel', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
              TextButton.icon(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
                icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                label: const Text('Odjava', style: TextStyle(color: Colors.white70)),
              ),
            ]),
          ),
          destinations: _items.map((e) => NavigationRailDestination(icon: Icon(e.$2), label: Text(e.$1))).toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: Container(color: const Color(0xFFF5F5F5), child: _page(_idx))),
      ]),
    );
  }
}
