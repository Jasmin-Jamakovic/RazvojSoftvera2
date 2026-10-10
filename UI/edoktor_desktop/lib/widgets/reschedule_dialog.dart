import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

/// Lets the admin move an appointment to another free slot of the same doctor.
/// Returns the chosen slot and reason, or null when cancelled.
class RescheduleDialog extends StatefulWidget {
  final Appointment appointment;
  const RescheduleDialog({super.key, required this.appointment});

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  static final _dayFmt = DateFormat('dd.MM.yyyy');
  static final _timeFmt = DateFormat('HH:mm');
  static final _fullFmt = DateFormat('dd.MM.yyyy HH:mm');

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late DateTime _day;
  late Future<List<TimeSlot>> _slots;
  TimeSlot? _selected;
  bool _showSlotError = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _load();
  }

  @override
  void dispose() { _reason.dispose(); super.dispose(); }

  void _load() {
    _selected = null;
    _slots = context.read<AppointmentProvider>().freeSlots(widget.appointment.doctorId, _day);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Odaberite datum novog termina',
    );
    if (d == null) return;
    setState(() { _day = d; _load(); });
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    setState(() => _showSlotError = _selected == null);
    if (formValid && _selected != null) {
      Navigator.pop(context, (slot: _selected!, reason: _reason.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return AlertDialog(
      title: Row(children: [
        const Expanded(child: Text('Pomjeranje termina')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(context)),
      ]),
      content: SizedBox(width: 520, child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.patientName ?? ''} • dr. ${a.doctorName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Trenutni termin: ${_fullFmt.format(a.startUtc)}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(child: Text(_dayFmt.format(_day))),
          OutlinedButton(onPressed: _pickDay, child: const Text('Promijeni datum')),
        ]),
        const SizedBox(height: 12),
        const Text('Slobodni termini ljekara:'),
        const SizedBox(height: 8),
        FutureBuilder<List<TimeSlot>>(future: _slots, builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
          }
          if (s.hasError) return Text('Greška pri učitavanju termina: ${s.error}', style: const TextStyle(color: Colors.red));
          final now = DateTime.now();
          final slots = (s.data ?? []).where((t) => t.start.isAfter(now) && DateUtils.isSameDay(t.start, _day)).toList();
          if (slots.isEmpty) {
            return const Text('Ljekar nema slobodnih termina za odabrani datum. Odaberite drugi datum.',
                style: TextStyle(color: Colors.black54));
          }
          return Wrap(spacing: 8, runSpacing: 8, children: slots.map((t) => ChoiceChip(
            label: Text(_timeFmt.format(t.start)),
            selected: _selected?.id == t.id,
            onSelected: (_) => setState(() { _selected = t; _showSlotError = false; }),
          )).toList());
        }),
        if (_showSlotError)
          const Padding(padding: EdgeInsets.only(top: 6),
            child: Text('Odaberite novi termin.', style: TextStyle(color: Colors.red, fontSize: 12))),
        const SizedBox(height: 16),
        TextFormField(controller: _reason, maxLines: 2, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Razlog pomjeranja', helperText: 'Pacijent će dobiti obavijest sa ovim razlogom.'),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.length < 3) return 'Razlog pomjeranja mora imati najmanje 3 znaka.';
            return Validators.maxLen(t, 500, 'Razlog pomjeranja');
          }),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
        FilledButton(onPressed: _submit, child: const Text('Pomjeri termin')),
      ],
    );
  }
}
