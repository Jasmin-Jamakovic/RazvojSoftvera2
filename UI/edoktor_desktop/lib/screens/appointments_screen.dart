import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/labels.dart';
import '../utils/validators.dart';
import '../widgets/reschedule_dialog.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static final _fmt = DateFormat('dd.MM.yyyy HH:mm');

  late Future<List<Appointment>> _f;
  String? _status;
  @override
  void initState() { super.initState(); _refresh(); }
  void _refresh() { setState(() { _f = context.read<AppointmentProvider>().listAll(status: _status); }); }

  Color _color(String s) => switch (s) { 'Pending' => Colors.orange, 'Confirmed' => Colors.green, 'Completed' => Colors.blueGrey, 'Cancelled' => Colors.red, _ => Colors.grey };

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String message, {String action = 'Potvrdi', bool danger = false}) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nazad')),
        FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null, onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ));
    return ok ?? false;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    try {
      await action();
      if (mounted) _snack(success);
      _refresh();
    } catch (e) {
      if (mounted) _snack('$e');
    }
  }

  Future<void> _confirmAppointment(Appointment a) async {
    if (!await _confirm('Potvrda termina', 'Potvrditi termin pacijenta ${a.patientName ?? ''} (${_fmt.format(a.startUtc)})?')) return;
    if (!mounted) return;
    await _run(() => context.read<AppointmentProvider>().confirm(a.id), 'Termin je potvrđen. Pacijent je obaviješten.');
  }

  Future<void> _complete(Appointment a) async {
    if (!await _confirm('Završetak pregleda', 'Označiti pregled pacijenta ${a.patientName ?? ''} kao završen? Nakon toga pacijent može ostaviti ocjenu.')) return;
    if (!mounted) return;
    await _run(() => context.read<AppointmentProvider>().complete(a.id), 'Pregled je označen kao završen.');
  }

  Future<void> _cancel(Appointment a) async {
    final formKey = GlobalKey<FormState>();
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [
        const Expanded(child: Text('Otkazivanje termina')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
      ]),
      content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Otkazati termin pacijenta ${a.patientName ?? ''} (${_fmt.format(a.startUtc)})? Ova akcija je nepovratna.'),
        const SizedBox(height: 12),
        TextFormField(controller: reason, maxLines: 2, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Razlog otkazivanja', helperText: 'Pacijent će dobiti obavijest sa ovim razlogom.'),
          validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Unesite razlog otkazivanja (najmanje 3 znaka).' : Validators.maxLen(v, 500, 'Razlog')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nazad')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(c, true); },
          child: const Text('Otkaži termin')),
      ],
    ));
    if (ok != true || !mounted) return;
    await _run(() => context.read<AppointmentProvider>().cancel(a.id, reason: reason.text.trim()), 'Termin je otkazan. Pacijent je obaviješten.');
  }

  Future<void> _refund(Appointment a, String captureId) async {
    if (!await _confirm('Povrat sredstava', 'Izvršiti povrat sredstava za ovaj termin? Ova akcija je nepovratna.', action: 'Izvrši povrat', danger: true)) return;
    if (!mounted) return;
    await _run(() => context.read<PaymentProvider>().refund(captureId), 'Povrat sredstava je izvršen.');
  }

  Future<void> _reschedule(Appointment a) async {
    final result = await showDialog<({TimeSlot slot, String reason})>(context: context, builder: (_) => RescheduleDialog(appointment: a));
    if (result == null || !mounted) return;
    await _run(() => context.read<AppointmentProvider>().reschedule(a.id, newTimeSlotId: result.slot.id, reason: result.reason),
        'Termin je pomjeren na ${_fmt.format(result.slot.start)}. Pacijent je obaviješten.');
  }

  /// Audit trail of one appointment: who created/confirmed/moved/completed/cancelled it, when and why.
  void _details(Appointment a) {
    final events = <(IconData, String, DateTime, String?)>[
      (Icons.add_circle_outline, 'Zakazan (pacijent ${a.patientName ?? ''})', a.createdAt, null),
      if (a.confirmedAt != null)
        (Icons.check_circle_outline, 'Potvrđen – ${a.confirmedByName ?? 'automatski nakon PayPal uplate'}', a.confirmedAt!, null),
      if (a.rescheduledAt != null)
        (Icons.event_repeat, 'Pomjeren – ${a.rescheduledByName ?? '-'}', a.rescheduledAt!, a.rescheduleReason),
      if (a.completedAt != null)
        (Icons.task_alt, 'Završen – ${a.completedByName ?? '-'}', a.completedAt!, null),
      if (a.cancelledAt != null)
        (Icons.cancel_outlined, 'Otkazan – ${a.cancelledByName ?? '-'}', a.cancelledAt!, a.cancellationReason),
    ]..sort((x, y) => x.$3.compareTo(y.$3));
    showDialog<void>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text('Termin ${_fmt.format(a.startUtc)}')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c)),
      ]),
      content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.patientName ?? ''} • dr. ${a.doctorName ?? ''} • ${a.isOnline ? 'Online' : 'Uživo'} • ${a.price.toStringAsFixed(2)} €'),
        const SizedBox(height: 4),
        Text('Status: ${appointmentStatusLabel(a.status)}', style: TextStyle(color: _color(a.status), fontWeight: FontWeight.w600)),
        const Divider(height: 24),
        const Text('Historija promjena', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final (icon, title, at, reason) in events)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: const Color(0xFF2E7D32)),
            title: Text(title),
            subtitle: Text(reason == null ? _fmt.format(at) : '${_fmt.format(at)}\nRazlog: $reason'),
            isThreeLine: reason != null,
          ),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Termini', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(children: [
        DropdownButton<String?>(
          value: _status,
          hint: const Text('Status'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Svi statusi')),
            DropdownMenuItem(value: 'Pending', child: Text('Na čekanju')),
            DropdownMenuItem(value: 'Confirmed', child: Text('Potvrđeni')),
            DropdownMenuItem(value: 'Completed', child: Text('Završeni')),
            DropdownMenuItem(value: 'Cancelled', child: Text('Otkazani')),
          ],
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
          final paid = a.payment?['status'] == 'Captured';
          final upcoming = a.startUtc.isAfter(DateTime.now());
          return ListTile(
            onTap: () => _details(a),
            leading: Container(width: 8, height: 40, color: _color(a.status)),
            title: Text('${a.patientName ?? ""} • dr. ${a.doctorName ?? ""}'),
            subtitle: Text('${_fmt.format(a.startUtc)} • ${a.isOnline ? "Online" : "Uživo"} • ${a.price.toStringAsFixed(0)} € • ${appointmentStatusLabel(a.status)}'
                '${a.status == 'Cancelled' && a.cancellationReason != null ? ' • Razlog: ${a.cancellationReason}' : ''}'),
            trailing: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              IconButton(icon: const Icon(Icons.history), tooltip: 'Historija promjena', onPressed: () => _details(a)),
              if (a.status == 'Pending') TextButton(onPressed: () => _confirmAppointment(a), child: const Text('Potvrdi')),
              if (a.status == 'Confirmed') Tooltip(
                message: upcoming ? 'Pregled se može završiti tek nakon zakazanog vremena.' : 'Označi pregled kao završen',
                child: TextButton(onPressed: upcoming ? null : () => _complete(a), child: const Text('Završi')),
              ),
              if (a.status == 'Pending' || a.status == 'Confirmed') Tooltip(
                message: upcoming ? 'Pomjeri na drugi slobodan termin' : 'Termin koji je već počeo ne može biti pomjeren.',
                child: TextButton(onPressed: upcoming ? () => _reschedule(a) : null, child: const Text('Pomjeri')),
              ),
              if (a.status == 'Pending' || a.status == 'Confirmed')
                TextButton(onPressed: () => _cancel(a), child: const Text('Otkaži', style: TextStyle(color: Colors.red))),
              if (capt != null && paid && a.status == 'Cancelled')
                TextButton(onPressed: () => _refund(a, capt), child: const Text('Povrat')),
            ]),
          );
        });
      }))),
    ]));
  }
}
