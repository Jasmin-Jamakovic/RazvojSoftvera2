import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/time_slot.dart';
import '../providers/appointment_provider.dart';
import '../providers/time_slot_provider.dart';
import '../theme/app_theme.dart';
import '../utils/confirm.dart';
import '../widgets/ui.dart';
import 'paypal_checkout_screen.dart';

class AppointmentBookingScreen extends StatefulWidget {
  final Doctor doctor;
  const AppointmentBookingScreen({super.key, required this.doctor});
  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  DateTime? _selectedDay;
  TimeSlot? _slot;
  List<TimeSlot> _slots = [];
  int _type = 0;
  bool _loading = false;

  late final List<DateTime> _days;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = List.generate(21, (i) => DateTime(today.year, today.month, today.day + i));
    _selectedDay = _days.first;
    _loadSlots();
  }

  void _pickDay(DateTime d) {
    if (_selectedDay == d) return;
    setState(() => _selectedDay = d);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() => _loading = true);
    final day = _selectedDay ?? DateTime.now();
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final s = await context.read<TimeSlotProvider>().forDoctor(widget.doctor.id, from: from.toUtc(), to: to.toUtc());
    // Ignore the response if the user already picked another day.
    if (!mounted || _selectedDay != day) return;
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
    setState(() => _booking = true);
    try {
      final appt = await context.read<AppointmentProvider>().create(doctorId: widget.doctor.id, timeSlotId: _slot!.id, type: _type);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaypalCheckoutScreen(appointmentId: appt.id, price: appt.price)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _selectedDay ?? _days.first;
    final d = widget.doctor;
    final buttonLabel = _slot == null
        ? 'Odaberite vrijeme'
        : 'Zakaži · ${bsDaysShort[day.weekday - 1]} ${day.day}. ${bsMonthsShort[day.month - 1]} u ${hhmm(_slot!.startUtc)}';
    return Scaffold(
      appBar: AppBar(title: const Text('Zakaži termin')),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.only(top: 16, bottom: 16), children: [
            AppCard(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                DoctorAvatar(d.fullName, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(d.specializations.map((s) => s.name).join(', '), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ]),
                ),
                Text('${d.consultationPrice.toStringAsFixed(0)} €',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text('${bsMonths[day.month - 1]} ${day.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _DayChip(day: _days[i], selected: _days[i] == day, onTap: () => _pickDay(_days[i])),
              ),
            ),
            const GroupLabel('Slobodni termini'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  : _slots.isEmpty
                      ? const EmptyState(icon: Icons.event_busy_outlined, message: 'Nema slobodnih termina za ovaj dan.\nProbajte drugi dan.')
                      : LayoutBuilder(builder: (context, c) {
                          final w = (c.maxWidth - 16) / 3;
                          return Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final s in _slots)
                              _SlotChip(width: w, label: hhmm(s.startUtc), selected: _slot?.id == s.id, onTap: () => setState(() => _slot = s)),
                          ]);
                        }),
            ),
            const GroupLabel('Vrsta pregleda'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _TypeCard(icon: Icons.local_hospital_outlined, title: 'Uživo', sub: 'U ordinaciji', selected: _type == 0, onTap: () => setState(() => _type = 0))),
                const SizedBox(width: 8),
                Expanded(child: _TypeCard(icon: Icons.videocam_outlined, title: 'Online', sub: 'Video poziv', selected: _type == 1, onTap: () => setState(() => _type = 1))),
              ]),
            ),
          ]),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Color(0x14142346), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: GradientButton(label: buttonLabel, busy: _booking, onPressed: _slot == null ? null : _confirm),
        ),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip({required this.day, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 56,
          decoration: BoxDecoration(
            color: selected ? null : Colors.white,
            gradient: selected ? AppColors.gradient : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected ? AppColors.glowShadow : AppColors.softShadow,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(bsDaysShort[day.weekday - 1],
                style: TextStyle(fontSize: 11, color: selected ? Colors.white.withValues(alpha: 0.8) : AppColors.muted)),
            const SizedBox(height: 2),
            Text('${day.day}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selected ? Colors.white : AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final double width;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SlotChip({required this.width, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.tint : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: selected ? AppColors.primary : AppColors.ink)),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({required this.icon, required this.title, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.tint2 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: 1.5),
          ),
          child: Row(children: [
            IconSquare(icon, size: 34, iconSize: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
