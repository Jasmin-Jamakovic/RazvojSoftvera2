import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
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

  static const _items = [
    ('Početna', Icons.home_outlined, Icons.home_rounded),
    ('Pretraga', Icons.search, Icons.search),
    ('Termini', Icons.event_outlined, Icons.event),
    ('Karton', Icons.medical_information_outlined, Icons.medical_information),
    ('Profil', Icons.person_outline, Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = context.read<NotificationProvider>();
      n.load();
      n.connectSignalR();
    });
  }

  void _open(int i) => setState(() => _idx = i);

  Widget _tab(int i) => switch (i) {
        0 => HomeTab(onOpenTab: _open),
        1 => const SearchTab(),
        2 => const MyAppointmentsTab(),
        3 => const MedicalRecordTab(),
        _ => const ProfileTab(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab(_idx),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _FloatingNavBar(items: _items, selected: _idx, onSelect: _open),
      ),
    );
  }
}

/// Mobile counterpart of the admin "floating card" sidebar: a green gradient bar
/// where the active tab turns into a white pill with its label.
class _FloatingNavBar extends StatelessWidget {
  final List<(String, IconData, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;

  const _FloatingNavBar({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.glowShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavItem(
              label: items[i].$1,
              icon: i == selected ? items[i].$3 : items[i].$2,
              active: i == selected,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.label, required this.icon, required this.active, required this.onTap});

  static const _duration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: active ? 14 : 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22, color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.8)),
              AnimatedSize(
                duration: _duration,
                curve: Curves.easeOut,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(label,
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      )
                    : const SizedBox.shrink(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
