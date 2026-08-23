import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/appointment.dart';
import '../providers/appointment_provider.dart';
import '../utils/confirm.dart';
import 'paypal_checkout_screen.dart';
import 'video_call_screen.dart';

class MyAppointmentsTab extends StatefulWidget {
  const MyAppointmentsTab({super.key});
  @override
  State<MyAppointmentsTab> createState() => _MyAppointmentsTabState();
}

class _MyAppointmentsTabState extends State<MyAppointmentsTab> {
  late Future<List<Appointment>> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<AppointmentProvider>().mine();
  }

  Future<void> _refresh() async { setState(() { _f = context.read<AppointmentProvider>().mine(); }); }

  Future<void> _cancel(Appointment a) async {
    final ok = await confirmDialog(
      context,
      title: 'Otkazivanje termina',
      message: 'Da li ste sigurni da želite otkazati termin kod ${a.doctorName ?? "ljekara"}? Ova akcija je nepovratna.',
      confirmLabel: 'Otkaži termin',
      cancelLabel: 'Nazad',
      danger: true,
    );
    if (!ok || !mounted) return;
    try { await context.read<AppointmentProvider>().cancel(a.id); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _pay(Appointment a) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PaypalCheckoutScreen(appointmentId: a.id, price: a.price)),
    );
    if (paid == true) _refresh();
  }

  Future<void> _join(Appointment a) async {
    try {
      final res = await context.read<AppointmentProvider>().roomFor(a.id);
      final url = res['joinUrl'] as String?;
      if (url == null || !mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VideoCallScreen(joinUrl: url, doctorName: a.doctorName ?? 'ljekar'),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return SafeArea(child: Column(children: [
      Container(padding: const EdgeInsets.all(16), alignment: Alignment.centerLeft, child: const Text('Moji termini', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      Expanded(child: RefreshIndicator(onRefresh: _refresh, child: FutureBuilder<List<Appointment>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        if (list.isEmpty) return ListView(children: const [SizedBox(height: 200), Center(child: Text('Nema termina.'))]);
        return ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final a = list[i];
          final canCancel = a.status == 'Pending' || (a.status == 'Confirmed' && a.startUtc.difference(DateTime.now()).inHours >= 24);
          final canJoin = a.status == 'Confirmed' && a.isOnline && a.startUtc.difference(DateTime.now()).inMinutes <= 30;
          final canPay = a.status == 'Pending' && !a.isPaid;
          return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.doctorName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${fmt.format(a.startUtc)} • ${a.typeLabel}'),
            const SizedBox(height: 8),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _statusColor(a.status), borderRadius: BorderRadius.circular(12)), child: Text(a.status, style: const TextStyle(color: Colors.white, fontSize: 12))),
              const SizedBox(width: 6),
              if (a.isPaid)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(12)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, color: Colors.white, size: 12), SizedBox(width: 2), Text('Plaćeno', style: TextStyle(color: Colors.white, fontSize: 12))])),
              const Spacer(),
              if (canPay) FilledButton.icon(onPressed: () => _pay(a), icon: const Icon(Icons.payment, size: 16), label: const Text('Plati')),
              if (canJoin) TextButton.icon(onPressed: () => _join(a), icon: const Icon(Icons.videocam), label: const Text('Uđi')),
              if (canCancel) TextButton(onPressed: () => _cancel(a), child: const Text('Otkaži')),
            ]),
          ])));
        });
      }))),
    ]));
  }

  Color _statusColor(String s) => switch (s) { 'Pending' => Colors.orange, 'Confirmed' => Colors.green, 'Completed' => Colors.blueGrey, 'Cancelled' => Colors.red, _ => Colors.grey };
}
