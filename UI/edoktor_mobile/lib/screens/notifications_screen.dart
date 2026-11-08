import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationProvider>().load());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikacije'), actions: [
        TextButton(onPressed: () => p.markAllRead(), child: const Text('Označi sve', style: TextStyle(color: Colors.white))),
      ]),
      body: RefreshIndicator(
        onRefresh: () => p.load(),
        child: p.items.isEmpty
            ? ListView(children: const [SizedBox(height: 200), Center(child: Text('Nema notifikacija.'))])
            : ListView.builder(itemCount: p.items.length, itemBuilder: (c, i) {
                final n = p.items[i];
                return ListTile(
                  leading: Icon(_icon(n.type, n.isRead), color: n.isRead ? Colors.grey : AppColors.primary),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text('${n.body}\n${fmt.format(n.createdAt)}'),
                  isThreeLine: true,
                  onTap: () => p.markRead(n.id),
                );
              }),
      ),
    );
  }

  /// Icon per notification type; unknown types fall back to the bell.
  static IconData _icon(String type, bool isRead) => switch (type) {
        'appointment' => Icons.event_outlined,
        'payment' => Icons.payments_outlined,
        'prescription' => Icons.medication_outlined,
        'lab_result' => Icons.science_outlined,
        _ => isRead ? Icons.notifications_none : Icons.notifications_active,
      };
}
