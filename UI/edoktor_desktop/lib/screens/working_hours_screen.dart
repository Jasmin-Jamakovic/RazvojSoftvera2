import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../widgets/working_hours_dialog.dart';

/// Weekly view of one doctor's bookable slots, with adding working hours and removing free slots.
class WorkingHoursScreen extends StatefulWidget {
  final Doctor doctor;
  const WorkingHoursScreen({super.key, required this.doctor});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  static final _date = DateFormat('dd.MM.');
  static final _dateYear = DateFormat('dd.MM.yyyy');
  static final _time = DateFormat('HH:mm');

  late DateTime _weekStart;
  late Future<List<TimeSlot>> _f;

  String get _doctorName => '${widget.doctor.firstName} ${widget.doctor.lastName}';

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _load();
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateUtils.dateOnly(d);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  DateTime get _weekEnd => DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);

  void _load() => setState(() { _f = context.read<DoctorProvider>().slots(widget.doctor.id, _weekStart, _weekEnd); });

  void _shiftWeek(int weeks) {
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * weeks);
    _load();
  }

  Future<void> _addWorkingHours() async {
    final input = await showDialog<WorkingHoursInput>(context: context, builder: (_) => WorkingHoursDialog(doctorName: _doctorName));
    if (input == null || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      final n = await context.read<DoctorProvider>().addWorkingHours(doctorId: widget.doctor.id, slotMinutes: input.slotMinutes, windows: input.windows);
      m.showSnackBar(SnackBar(content: Text(n == 0
          ? 'Nije kreiran nijedan novi termin – odabrano vrijeme je već pokriveno postojećim terminima.'
          : 'Kreirano je $n novih termina za dr. $_doctorName.')));
      _weekStart = _mondayOf(input.windows.first.start);
      _load();
    } catch (e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _deleteSlot(TimeSlot s) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Brisanje termina'),
      content: Text('Obrisati slobodan termin ${_dateYear.format(s.start)} u ${_time.format(s.start)}? Pacijenti ga više neće moći rezervisati.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
      ],
    ));
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await context.read<DoctorProvider>().deleteSlot(s.id);
      m.showSnackBar(SnackBar(content: Text('Termin ${_dateYear.format(s.start)} u ${_time.format(s.start)} je obrisan.')));
      _load();
    } catch (e) { m.showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final lastDay = DateTime(_weekEnd.year, _weekEnd.month, _weekEnd.day - 1);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6F2),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Radno vrijeme – dr. $_doctorName'),
      ),
      body: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna sedmica', onPressed: () => _shiftWeek(-1)),
          Text('${_date.format(_weekStart)} – ${_dateYear.format(lastDay)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća sedmica', onPressed: () => _shiftWeek(1)),
          TextButton(onPressed: () { _weekStart = _mondayOf(DateTime.now()); _load(); }, child: const Text('Ova sedmica')),
          const SizedBox(width: 16),
          _legend(Colors.green, 'Slobodan'),
          _legend(Colors.blueGrey, 'Rezervisan'),
          _legend(Colors.grey.shade400, 'Prošao'),
          FilledButton.icon(onPressed: _addWorkingHours, icon: const Icon(Icons.add), label: const Text('Dodaj radno vrijeme')),
        ]),
        const SizedBox(height: 12),
        Expanded(child: FutureBuilder<List<TimeSlot>>(future: _f, builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('Greška pri učitavanju termina: ${s.error}', style: const TextStyle(color: Colors.red)));
          final slots = s.data!;
          final free = slots.where((x) => !x.isBooked && x.start.isAfter(DateTime.now())).length;
          final booked = slots.where((x) => x.isBooked).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ove sedmice: $free slobodnih i $booked rezervisanih termina.', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < 7; i++) Expanded(child: _dayColumn(DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i), slots)),
            ])),
          ]);
        })),
      ])),
    );
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label),
      ]);

  Widget _dayColumn(DateTime day, List<TimeSlot> all) {
    final slots = all.where((x) => DateUtils.isSameDay(x.start, day)).toList()..sort((a, b) => a.start.compareTo(b.start));
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final now = DateTime.now();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: isToday ? const BorderSide(color: Color(0xFF2E7D32), width: 1.5) : BorderSide.none),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.all(10), child: Column(children: [
          Text(weekdayNames[day.weekday - 1], style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_date.format(day), style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ])),
        const Divider(height: 1),
        Expanded(child: slots.isEmpty
            ? const Center(child: Text('Neradni dan', style: TextStyle(color: Colors.black38)))
            : ListView(padding: const EdgeInsets.all(8), children: [
                for (final x in slots) Padding(padding: const EdgeInsets.only(bottom: 6), child: _slotTile(x, past: !x.start.isAfter(now))),
              ])),
      ]),
    );
  }

  Widget _slotTile(TimeSlot x, {required bool past}) {
    final label = '${_time.format(x.start)} – ${_time.format(x.end)}';
    final color = x.isBooked ? Colors.blueGrey : past ? Colors.grey.shade400 : Colors.green;
    final canDelete = !x.isBooked && !past;
    return Tooltip(
      message: x.isBooked
          ? 'Rezervisan termin – ne može se obrisati dok se pregled ne otkaže ili pomjeri.'
          : past ? 'Termin je prošao.' : 'Slobodan termin',
      child: Container(
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: past && !x.isBooked ? Colors.black45 : Colors.black87))),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            tooltip: canDelete ? 'Obriši termin' : null,
            icon: Icon(x.isBooked ? Icons.lock_outline : Icons.close),
            onPressed: canDelete ? () => _deleteSlot(x) : null,
          ),
        ]),
      ),
    );
  }
}
