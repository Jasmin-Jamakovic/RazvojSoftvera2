import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../providers/auth_provider.dart';
import '../providers/doctor_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/doctor_card.dart';
import 'doctor_details_screen.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<Doctor>> _rec;

  @override
  void initState() {
    super.initState();
    _rec = context.read<DoctorProvider>().recommended();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = context.watch<NotificationProvider>().unreadCount;
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Text('eDoktor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const Spacer(),
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              if (unread > 0)
                Positioned(right: 6, top: 6, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Center(child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))))),
            ]),
            CircleAvatar(radius: 18, backgroundColor: const Color(0xFFE3F2FD), child: Text(user?.firstName.isNotEmpty == true ? user!.firstName[0] : 'U', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: Text('Dobrodošli, ${user?.firstName ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Preporučeno za vas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Doctor>>(
            future: _rec,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Greška: ${snap.error}')));
              final list = snap.data ?? [];
              if (list.isEmpty) return const Center(child: Text('Nema preporuka.'));
              return ListView.builder(itemCount: list.length, itemBuilder: (c, i) => DoctorCard(doctor: list[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDetailsScreen(doctor: list[i])))));
            },
          ),
        ),
      ]),
    );
  }
}
