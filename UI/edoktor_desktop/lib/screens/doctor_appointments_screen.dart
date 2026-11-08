import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/labels.dart';
import '../utils/validators.dart';
import 'consultation_chat_screen.dart';
import 'patient_record_screen.dart';

enum _Period { all, upcoming, past }

/// The signed-in doctor's appointments (the API returns only their own), with status/period filters,
/// paging and the per-appointment actions: confirm, complete, cancel, patient record and chat.
class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});
  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  static final _fmt = DateFormat('dd.MM.yyyy HH:mm');
  static const _pageSize = 20;

  final _search = TextEditingController();
  String? _status;
  _Period _period = _Period.upcoming;
  int _page = 0;
  late Future<PagedList<Appointment>> _f;

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _refresh({bool resetPage = false}) {
    if (resetPage) _page = 0;
    final now = DateTime.now();
    setState(() {
      _f = context.read<AppointmentProvider>().list(
        status: _status,
        from: _period == _Period.upcoming ? now : null,
        to: _period == _Period.past ? now : null,
        // Upcoming: nearest appointment first.
        sortAscending: _period == _Period.upcoming,
        page: _page, pageSize: _pageSize,
      );
    });
  }

  Color _color(String s) => switch (s) { 'Pending' => Colors.orange, 'Confirmed' => Colors.green, 'Completed' => Colors.blueGrey, 'Cancelled' => Colors.red, _ => Colors.grey };

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _confirm(String title, String message, {String action = 'Potvrdi'}) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nazad')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
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
    if (!await _confirm('Završetak pregleda', 'Označiti pregled pacijenta ${a.patientName ?? ''} kao završen? Nakon toga pacijent može ostaviti ocjenu.', action: 'Završi')) return;
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

  void _openRecord(Appointment a) => Navigator.push(context, MaterialPageRoute(
      builder: (_) => PatientRecordScreen(patientId: a.patientId, patientName: a.patientName ?? 'Pacijent')));

  void _openChat(Appointment a) => Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationChatScreen(appointment: a)));

  String _payment(Appointment a) => a.price <= 0 ? 'Besplatno' : a.isPaid ? 'Plaćeno' : 'Nije plaćeno';

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Moji termini', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Osvježi')),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 280, child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Pretraga po imenu pacijenta...',
            prefixIcon: const Icon(Icons.search),
            isDense: true, border: const OutlineInputBorder(),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(_search.clear)),
          ),
          onChanged: (_) => setState(() {}),
        )),
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
          onChanged: (v) { _status = v; _refresh(resetPage: true); }),
        SegmentedButton<_Period>(
          segments: const [
            ButtonSegment(value: _Period.upcoming, label: Text('Predstojeći'), icon: Icon(Icons.upcoming)),
            ButtonSegment(value: _Period.past, label: Text('Prošli'), icon: Icon(Icons.history)),
            ButtonSegment(value: _Period.all, label: Text('Svi')),
          ],
          selected: {_period},
          onSelectionChanged: (v) { _period = v.first; _refresh(resetPage: true); },
        ),
      ]),
      const SizedBox(height: 12),
      Expanded(child: Card(child: FutureBuilder<PagedList<Appointment>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}', style: const TextStyle(color: Colors.red)));
        final data = s.data!;
        final q = _search.text.trim().toLowerCase();
        // The API has no patient-name filter, so the search runs over the loaded page.
        final list = q.isEmpty ? data.items : data.items.where((a) => (a.patientName ?? '').toLowerCase().contains(q)).toList();
        final first = data.items.isEmpty ? 0 : _page * _pageSize + 1;
        final last = _page * _pageSize + data.items.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: list.isEmpty
              ? Center(child: Text(q.isEmpty ? 'Nema termina.' : 'Nema termina za pacijenta "${_search.text.trim()}" na ovoj strani.'))
              : ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
                  final a = list[i];
                  final started = !a.startUtc.isAfter(DateTime.now());
                  final active = a.status == 'Pending' || a.status == 'Confirmed';
                  return ListTile(
                    leading: Container(width: 8, height: 40, color: _color(a.status)),
                    title: Text(a.patientName ?? 'Pacijent'),
                    subtitle: Text('${_fmt.format(a.startUtc)} • ${a.isOnline ? 'Online' : 'Uživo'} • ${a.price.toStringAsFixed(2)} € (${_payment(a)}) • ${appointmentStatusLabel(a.status)}'
                        '${a.status == 'Cancelled' && a.cancellationReason != null ? ' • Razlog: ${a.cancellationReason}' : ''}'),
                    trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (a.status == 'Pending') Tooltip(
                        message: a.price > 0 && !a.isPaid ? 'Plaćeni termin se potvrđuje automatski nakon uplate.' : 'Potvrdi termin',
                        child: TextButton(onPressed: () => _confirmAppointment(a), child: const Text('Potvrdi')),
                      ),
                      if (a.status == 'Confirmed') Tooltip(
                        message: started ? 'Označi pregled kao završen' : 'Pregled se može završiti tek nakon zakazanog vremena.',
                        child: TextButton(onPressed: started ? () => _complete(a) : null, child: const Text('Završi')),
                      ),
                      if (active)
                        TextButton(onPressed: () => _cancel(a), child: const Text('Otkaži', style: TextStyle(color: Colors.red))),
                      if (a.isOnline)
                        IconButton(icon: const Icon(Icons.chat_outlined), tooltip: 'Chat sa pacijentom', onPressed: () => _openChat(a)),
                      OutlinedButton.icon(onPressed: () => _openRecord(a), icon: const Icon(Icons.folder_shared, size: 18), label: const Text('Karton pacijenta')),
                    ]),
                  );
                })),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Prikazano $first–$last od ${data.totalCount}'),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna strana',
              onPressed: _page > 0 ? () { _page--; _refresh(); } : null),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća strana',
              onPressed: last < data.totalCount ? () { _page++; _refresh(); } : null),
          ])),
        ]);
      }))),
    ]));
  }
}
