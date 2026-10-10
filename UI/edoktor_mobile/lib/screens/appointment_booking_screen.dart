import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
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
  static const _free = AppColors.primaryLight;
  static const _busy = Color(0xFFB8BEC8);
  static const _selected = Color(0xFF1E63D6);

  late final DateTime _today;
  late final DateTime _lastDay;
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  TimeSlot? _slot;
  int _type = 0;
  bool _loading = false;
  bool _booking = false;
  String? _error;

  // Free future slots of the shown month, grouped by local calendar day.
  Map<DateTime, List<TimeSlot>> _freeByDay = {};

  List<TimeSlot> get _slots => _selectedDay == null ? const [] : (_freeByDay[_selectedDay] ?? const []);

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(DateTime.now());
    _lastDay = _today.add(const Duration(days: 90));
    _focusedMonth = _today;
    _loadMonth(selectFirstFree: true);
  }

  Future<void> _loadMonth({bool selectFirstFree = false}) async {
    final month = DateTime(_focusedMonth.year, _focusedMonth.month);
    final from = month.isBefore(_today) ? _today : month;
    final to = DateTime(month.year, month.month + 1);
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final slots = await context.read<TimeSlotProvider>().freeInRange(widget.doctor.id, from, to);
      // Ignore the response if the user already moved to another month.
      if (!mounted || month != DateTime(_focusedMonth.year, _focusedMonth.month)) return;
      final grouped = <DateTime, List<TimeSlot>>{};
      for (final t in slots.where((t) => t.startUtc.isAfter(now))) {
        grouped.putIfAbsent(DateUtils.dateOnly(t.startUtc), () => []).add(t);
      }
      for (final list in grouped.values) {
        list.sort((a, b) => a.startUtc.compareTo(b.startUtc));
      }
      setState(() {
        _freeByDay = grouped;
        if (selectFirstFree && grouped.isNotEmpty) {
          _selectedDay = (grouped.keys.toList()..sort()).first;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickDay(DateTime day, DateTime focused) {
    setState(() { _selectedDay = DateUtils.dateOnly(day); _slot = null; _focusedMonth = focused; });
  }

  void _changeMonth(DateTime focused) {
    _focusedMonth = focused;
    _selectedDay = null;
    _slot = null;
    _loadMonth(selectFirstFree: true);
  }

  Widget _dayCell(DateTime day, {required Color? bg, required Color fg, bool bold = false, Border? border}) => Center(
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border),
          child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ),
      );

  Widget _availabilityCell(DateTime day) {
    final hasFree = _freeByDay.containsKey(DateUtils.dateOnly(day));
    final isToday = DateUtils.isSameDay(day, _today);
    return _dayCell(day,
        bg: hasFree ? _free : _busy.withValues(alpha: 0.35),
        fg: hasFree ? Colors.white : const Color(0xFF6B7385),
        bold: hasFree,
        border: isToday ? Border.all(color: AppColors.deep, width: 1.5) : null);
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);

  Widget _calendar() => AppCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(children: [
          TableCalendar<void>(
            firstDay: _today,
            lastDay: _lastDay,
            focusedDay: _focusedMonth.isBefore(_today) ? _today : _focusedMonth,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: 'Mjesec'},
            rowHeight: 46,
            headerStyle: const HeaderStyle(titleCentered: true, formatButtonVisible: false),
            selectedDayPredicate: (d) => _selectedDay != null && DateUtils.isSameDay(d, _selectedDay),
            onDaySelected: _pickDay,
            onPageChanged: _changeMonth,
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (c, d) => Center(
                child: Text('${bsMonths[d.month - 1]} ${d.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              dowBuilder: (c, d) => Center(
                child: Text(bsDaysShort[d.weekday - 1], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              defaultBuilder: (c, d, f) => _availabilityCell(d),
              todayBuilder: (c, d, f) => _availabilityCell(d),
              selectedBuilder: (c, d, f) => _dayCell(d, bg: _selected, fg: Colors.white, bold: true),
              disabledBuilder: (c, d, f) => _dayCell(d, bg: null, fg: const Color(0xFFC9CED6)),
              outsideBuilder: (c, d, f) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 16, runSpacing: 6, alignment: WrapAlignment.center, children: [
            _legend(_free, 'Slobodno'),
            _legend(_busy, 'Zauzeto'),
            _legend(_selected, 'Odabrano'),
          ]),
        ]),
      );

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
    final day = _selectedDay ?? _today;
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
                DoctorPhoto(doctorId: d.id, name: d.fullName, hasPhoto: d.hasPhoto, size: 44),
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
            const SizedBox(height: 16),
            _calendar(),
            GroupLabel(_selectedDay == null ? 'Slobodni termini' : 'Slobodni termini · ${dayLabel(_selectedDay!)}'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  : _error != null
                      ? EmptyState(icon: Icons.error_outline, message: 'Termine nije moguće učitati: $_error')
                      : _selectedDay == null
                          ? EmptyState(
                              icon: Icons.event_busy_outlined,
                              message: _freeByDay.isEmpty
                                  ? 'Ljekar nema slobodnih termina u ovom mjesecu.\nPogledajte sljedeći mjesec.'
                                  : 'Odaberite zeleni datum u kalendaru.')
                          : _slots.isEmpty
                              ? const EmptyState(icon: Icons.event_busy_outlined, message: 'Nema slobodnih termina za ovaj dan.\nOdaberite zeleni datum.')
                              : LayoutBuilder(builder: (context, c) {
                                  final w = (c.maxWidth - 16) / 3;
                                  return Wrap(spacing: 8, runSpacing: 8, children: [
                                    for (final t in _slots)
                                      _SlotChip(width: w, label: hhmm(t.startUtc), selected: _slot?.id == t.id, onTap: () => setState(() => _slot = t)),
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
