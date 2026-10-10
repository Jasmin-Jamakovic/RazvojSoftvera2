import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../widgets/reschedule_dialog.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<List<Appointment>> _f;
  String? _status;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() { setState(() { _f = context.read<AppointmentProvider>().list(status: _status); }); }

  Color _color(String s) => switch (s) { 'Pending' => Colors.orange, 'Confirmed' => Colors.green, 'Completed' => Colors.blueGrey, 'Cancelled' => Colors.red, _ => Colors.grey };

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nazad')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Potvrdi')),
      ],
    ));
    return ok ?? false;
  }

  Future<void> _reschedule(Appointment a) async {
    final result = await showDialog<({TimeSlot slot, String reason})>(context: context, builder: (_) => RescheduleDialog(appointment: a));
    if (result == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await context.read<AppointmentProvider>().reschedule(a.id, newTimeSlotId: result.slot.id, reason: result.reason);
      m.showSnackBar(SnackBar(content: Text('Termin je pomjeren na ${DateFormat('dd.MM.yyyy HH:mm').format(result.slot.start)}. Pacijent je obaviješten.')));
      _refresh();
    } catch (e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Termini', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        DropdownButton<String?>(
          value: _status,
          hint: const Text('Status'),
          items: const [DropdownMenuItem(value: null, child: Text('Svi')), DropdownMenuItem(value: 'Pending', child: Text('Pending')), DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')), DropdownMenuItem(value: 'Completed', child: Text('Completed')), DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled'))],
          onChanged: (v) { setState(() => _status = v); _refresh(); }),
        const Spacer(),
        TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Osvježi')),
      ]),
      const SizedBox(height: 12),
      Expanded(child: Card(child: FutureBuilder<List<Appointment>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Nema termina.'));
        return ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final a = list[i];
          final capt = a.payment?['captureId'] as String?;
          return ListTile(
            leading: Container(width: 8, height: 40, color: _color(a.status)),
            title: Text('${a.patientName ?? ""} • ${a.doctorName ?? ""}'),
            subtitle: Text('${fmt.format(a.startUtc)} • ${a.isOnline ? "Online" : "Uživo"} • ${a.price.toStringAsFixed(0)} € • ${a.status}'),
            trailing: Wrap(spacing: 6, children: [
              if (a.status == 'Pending') TextButton(onPressed: () async { try { await context.read<AppointmentProvider>().confirm(a.id); _refresh(); } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('Potvrdi')),
              if (a.status == 'Confirmed') TextButton(onPressed: () async { try { await context.read<AppointmentProvider>().complete(a.id); _refresh(); } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } }, child: const Text('Završi')),
              if (a.status == 'Pending' || a.status == 'Confirmed') Tooltip(
                message: a.startUtc.isAfter(DateTime.now()) ? 'Pomjeri na drugi slobodan termin' : 'Termin koji je već počeo ne može biti pomjeren.',
                child: TextButton(onPressed: a.startUtc.isAfter(DateTime.now()) ? () => _reschedule(a) : null, child: const Text('Pomjeri')),
              ),
              if (a.status != 'Completed' && a.status != 'Cancelled') TextButton(onPressed: () async {
                if (!await _confirm('Otkazivanje termina', 'Otkazati termin za ${a.patientName ?? ""}? Ova akcija je nepovratna.')) return;
                final m = ScaffoldMessenger.of(context);
                try { await context.read<AppointmentProvider>().cancel(a.id); _refresh(); }
                catch(e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
              }, child: const Text('Otkaži', style: TextStyle(color: Colors.red))),
              if (capt != null && a.status == 'Cancelled') TextButton(onPressed: () async {
                if (!await _confirm('Povrat sredstava', 'Izvršiti povrat sredstava za ovaj termin? Ova akcija je nepovratna.')) return;
                final m = ScaffoldMessenger.of(context);
                try { await context.read<PaymentProvider>().refund(capt); m.showSnackBar(const SnackBar(content: Text('Povrat izvršen'))); }
                catch (e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
              }, child: const Text('Povrat')),
            ]),
          );
        });
      }))),
    ]));
  }
}
