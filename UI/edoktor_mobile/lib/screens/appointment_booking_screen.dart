import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/doctor.dart';
import '../models/time_slot.dart';
import '../providers/appointment_provider.dart';
import '../providers/time_slot_provider.dart';
import '../utils/confirm.dart';
import 'paypal_checkout_screen.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final Doctor doctor;
  const AppointmentBookingScreen({super.key, required this.doctor});
  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selectedDay;
  TimeSlot? _slot;
  List<TimeSlot> _slots = [];
  int _type = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _loading = true);
    final day = _selectedDay ?? DateTime.now();
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final s = await context.read<TimeSlotProvider>().forDoctor(widget.doctor.id, from: from.toUtc(), to: to.toUtc());
    if (!mounted) return;
    setState(() { _slots = s; _slot = null; _loading = false; });
  }

  Future<void> _confirm() async {
    if (_slot == null) return;
    final t = '${_slot!.startUtc.hour.toString().padLeft(2, '0')}:${_slot!.startUtc.minute.toString().padLeft(2, '0')}';
    final ok = await confirmDialog(
      context,
      title: 'Potvrda zakazivanja',
      message: 'Zakazati termin kod ${widget.doctor.fullName} u $t? Nakon zakazivanja slijedi plaćanje.',
      confirmLabel: 'Zakaži',
    );
    if (!ok || !mounted) return;
    try {
      final appt = await context.read<AppointmentProvider>().create(doctorId: widget.doctor.id, timeSlotId: _slot!.id, type: _type);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaypalCheckoutScreen(appointmentId: appt.id, price: appt.price)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zakazivanje termina')),
      body: Column(children: [
        ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(widget.doctor.fullName), subtitle: Text(widget.doctor.specializations.map((s) => s.name).join(', '))),
        TableCalendar(
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 90)),
          focusedDay: _focused,
          selectedDayPredicate: (d) => _selectedDay != null && isSameDay(_selectedDay!, d),
          onDaySelected: (s, f) { setState(() { _selectedDay = s; _focused = f; }); _loadSlots(); },
          calendarStyle: const CalendarStyle(selectedDecoration: BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _slots.isEmpty
                  ? const Center(child: Text('Nema slobodnih termina za ovaj dan.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(spacing: 8, runSpacing: 8, children: _slots.map((s) {
                        final selected = _slot?.id == s.id;
                        return ChoiceChip(
                          label: Text('${s.startUtc.hour.toString().padLeft(2, '0')}:${s.startUtc.minute.toString().padLeft(2, '0')}'),
                          selected: selected,
                          onSelected: (_) => setState(() => _slot = s),
                        );
                      }).toList()),
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: _type,
              items: const [DropdownMenuItem(value: 0, child: Text('Uživo')), DropdownMenuItem(value: 1, child: Text('Online konsultacija'))],
              onChanged: (v) => setState(() => _type = v ?? 0),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            )),
            const SizedBox(width: 8),
            FilledButton(onPressed: _slot == null ? null : _confirm, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12), child: Text('Potvrdi'))),
          ]),
        ),
      ]),
    );
  }
}
