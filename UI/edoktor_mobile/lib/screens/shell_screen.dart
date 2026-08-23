import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'my_appointments_tab.dart';
import 'medical_record_tab.dart';
import 'profile_tab.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _idx = 0;
  final _tabs = const [HomeTab(), SearchTab(), MyAppointmentsTab(), MedicalRecordTab(), ProfileTab()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = context.read<NotificationProvider>();
      n.load();
      n.connectSignalR();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Početna'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Pretraga'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Moji termini'),
          NavigationDestination(icon: Icon(Icons.medical_information_outlined), selectedIcon: Icon(Icons.medical_information), label: 'Karton'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
