import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/doctor_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/doctor_card.dart';
import '../widgets/ui.dart';
import 'doctor_details_screen.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  /// Switches the shell to another tab (1 = search, 2 = appointments, 3 = record).
  final ValueChanged<int> onOpenTab;
  const HomeTab({super.key, required this.onOpenTab});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Doctor>> _rec;
  late Future<Appointment?> _next;

  // Fixed heights so the "next appointment" card can overlap the gradient header precisely.
  static const _greetH = 44.0;
  static const _searchH = 48.0;
  static const _overlap = 56.0;

  @override
  void initState() {
    super.initState();
    _rec = context.read<DoctorProvider>().recommended();
    _next = _loadNext();
  }

  Future<Appointment?> _loadNext() async {
    final now = DateTime.now();
    final list = await context.read<AppointmentProvider>().mine();
    final upcoming = list
        .where((a) => (a.status == 'Pending' || a.status == 'Confirmed') && a.endUtc.isAfter(now))
        .toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 10) return 'Dobro jutro';
    if (h < 18) return 'Dobar dan';
    return 'Dobro veče';
  }

  void _openNotifications() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = context.watch<NotificationProvider>().unreadCount;
    final top = MediaQuery.of(context).padding.top + 14;
    final cardTop = top + _greetH + 16 + _searchH + 20;

    return ListView(padding: EdgeInsets.zero, children: [
      Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: cardTop + _overlap,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: _greetH,
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.mint,
                  child: Text(user == null ? 'U' : initialsOf(user.fullName),
                      style: const TextStyle(color: AppColors.deep, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_greeting(), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                    Text(user?.firstName ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  ]),
                ),
                Stack(clipBehavior: Clip.none, children: [
                  IconSquare.onGradient(Icons.notifications_outlined, onTap: _openNotifications),
                  if (unread > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.primaryMid, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text('$unread',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => widget.onOpenTab(1),
              child: Container(
                height: _searchH,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.search, color: Colors.white.withValues(alpha: 0.85), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Ljekar, specijalizacija…',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.tune, size: 16, color: AppColors.primary),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Appointment?>(
              future: _next,
              builder: (c, s) => _NextAppointmentCard(
                loading: s.connectionState != ConnectionState.done,
                appointment: s.data,
                onOpen: () => widget.onOpenTab(2),
                onFind: () => widget.onOpenTab(1),
              ),
            ),
          ]),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _QuickAction(icon: Icons.search, label: 'Pronađi\nljekara', onTap: () => widget.onOpenTab(1)),
          _QuickAction(icon: Icons.event_outlined, label: 'Moji\ntermini', onTap: () => widget.onOpenTab(2)),
          _QuickAction(icon: Icons.medication_outlined, label: 'Recepti i\nnalazi', onTap: () => widget.onOpenTab(3)),
          _QuickAction(icon: Icons.notifications_outlined, label: 'Obavje-\nštenja', onTap: _openNotifications),
        ]),
      ),
      SectionTitle('Preporučeno za vas', action: 'Svi ljekari', onAction: () => widget.onOpenTab(1)),
      FutureBuilder<List<Doctor>>(
        future: _rec,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return Padding(padding: const EdgeInsets.all(16), child: Text('Greška: ${snap.error}'));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) return const EmptyState(icon: Icons.person_search_outlined, message: 'Nema preporuka.');
          return Column(children: [
            for (final d in list)
              DoctorCard(
                doctor: d,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDetailsScreen(doctor: d))),
              ),
          ]);
        },
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _NextAppointmentCard extends StatelessWidget {
  final bool loading;
  final Appointment? appointment;
  final VoidCallback onOpen;
  final VoidCallback onFind;

  const _NextAppointmentCard({required this.loading, required this.appointment, required this.onOpen, required this.onFind});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: a == null ? null : onOpen,
      child: SizedBox(
        height: 128,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : a == null
                ? Row(children: [
                    const IconSquare(Icons.event_available_outlined, size: 52, iconSize: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('Nemate zakazanih termina', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Pronađite ljekara i zakažite pregled u par klikova.',
                            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onFind,
                          child: const Text('Pronađi ljekara →',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      const Expanded(
                        child: Text('SLJEDEĆI TERMIN',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.8)),
                      ),
                      StatusPill(a.status, isPaid: a.isPaid),
                    ]),
                    const Spacer(),
                    Row(children: [
                      DoctorAvatar(a.doctorName ?? '', size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.doctorName ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(a.isOnline ? 'Online konsultacija' : 'Pregled uživo',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ]),
                      ),
                      IconSquare(a.isOnline ? Icons.videocam_outlined : Icons.local_hospital_outlined, size: 36, iconSize: 18),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: AppColors.tint2, borderRadius: BorderRadius.circular(12)),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12.5),
                        child: Row(children: [
                          const Icon(Icons.event_outlined, size: 15, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(dayLabel(a.startUtc)),
                          const SizedBox(width: 14),
                          const Icon(Icons.schedule, size: 15, color: AppColors.primary),
                          const SizedBox(width: 5),
                          Text(hhmm(a.startUtc)),
                          const Spacer(),
                          Text(relativeFromNow(a.startUtc), style: const TextStyle(color: AppColors.deep)),
                        ]),
                      ),
                    ),
                  ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.softShadow),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF4A5263), height: 1.25)),
          ]),
        ),
      ),
    );
  }
}
