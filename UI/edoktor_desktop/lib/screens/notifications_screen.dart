import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

/// The doctor's in-app notifications (new appointment, cancellation, payment). The list refreshes
/// itself over SignalR (or by polling); a click marks a notification as read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static final _fmt = DateFormat('dd.MM.yyyy HH:mm');
  bool _onlyUnread = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await context.read<NotificationProvider>().load();
    } catch (e) {
      if (mounted) _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await context.read<NotificationProvider>().markRead(id);
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _markAll() async {
    try {
      await context.read<NotificationProvider>().markAllRead();
      if (mounted) _snack('Sve notifikacije su označene kao pročitane.');
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  IconData _icon(String type) => switch (type) {
        'appointment' => Icons.event,
        'payment' => Icons.payments,
        _ => Icons.notifications,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();
    final list = _onlyUnread ? p.items.where((n) => !n.isRead).toList() : p.items;
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Notifikacije', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        if (p.unreadCount > 0) Chip(label: Text('${p.unreadCount} nepročitanih')),
        const Spacer(),
        TextButton.icon(onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh), label: const Text('Osvježi')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: p.unreadCount == 0 ? null : _markAll,
          icon: const Icon(Icons.done_all), label: const Text('Označi sve kao pročitano')),
      ]),
      const SizedBox(height: 12),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Sve')),
          ButtonSegment(value: true, label: Text('Nepročitane')),
        ],
        selected: {_onlyUnread},
        onSelectionChanged: (v) => setState(() => _onlyUnread = v.first),
      ),
      const SizedBox(height: 12),
      Expanded(child: Card(child: _loading && p.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(child: Text(_onlyUnread ? 'Nema nepročitanih notifikacija.' : 'Nema notifikacija.'))
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final n = list[i];
                    return ListTile(
                      tileColor: n.isRead ? null : const Color(0xFFF1F8F1),
                      leading: Icon(n.isRead ? Icons.notifications_none : _icon(n.type), color: n.isRead ? Colors.grey : const Color(0xFF2E7D32)),
                      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text('${n.body}\n${_fmt.format(n.createdAt)}'),
                      isThreeLine: true,
                      trailing: n.isRead
                          ? null
                          : TextButton(onPressed: () => _markRead(n.id), child: const Text('Označi kao pročitano')),
                      onTap: n.isRead ? null : () => _markRead(n.id),
                    );
                  },
                ))),
    ]));
  }
}
