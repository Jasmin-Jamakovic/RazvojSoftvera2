import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const weekdayNames = ['Ponedjeljak', 'Utorak', 'Srijeda', 'Četvrtak', 'Petak', 'Subota', 'Nedjelja'];
const _weekdayShort = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];

String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Result of the dialog: one local working window per selected day, plus the slot length.
typedef WorkingHoursInput = ({List<DateTimeRange> windows, int slotMinutes});

/// Collects a doctor's working hours: period, working days, daily start/end time and slot length.
class WorkingHoursDialog extends StatefulWidget {
  final String doctorName;
  const WorkingHoursDialog({super.key, required this.doctorName});

  @override
  State<WorkingHoursDialog> createState() => _WorkingHoursDialogState();
}

class _WorkingHoursDialogState extends State<WorkingHoursDialog> {
  static const _maxDays = 92;
  static const _slotOptions = [15, 20, 30, 45, 60];
  static final _date = DateFormat('dd.MM.yyyy');

  late DateTimeRange _range;
  final Set<int> _days = {1, 2, 3, 4, 5}; // DateTime.monday..friday
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  int _slotMinutes = 30;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = DateTimeRange(start: today, end: today.add(const Duration(days: 13)));
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  List<DateTimeRange> get _windows {
    final result = <DateTimeRange>[];
    for (var d = _range.start; !d.isAfter(_range.end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (!_days.contains(d.weekday)) continue;
      result.add(DateTimeRange(
        start: DateTime(d.year, d.month, d.day, _start.hour, _start.minute),
        end: DateTime(d.year, d.month, d.day, _end.hour, _end.minute),
      ));
    }
    return result;
  }

  String? get _daysError => _days.isEmpty ? 'Odaberite barem jedan radni dan.' : null;

  String? get _rangeError {
    if (_range.duration.inDays + 1 > _maxDays) return 'Period može trajati najviše $_maxDays dana.';
    if (_days.isNotEmpty && _windows.isEmpty) return 'U odabranom periodu nema nijednog odabranog radnog dana.';
    return null;
  }

  String? get _timeError {
    final length = _minutes(_end) - _minutes(_start);
    if (length <= 0) return 'Kraj radnog vremena mora biti nakon početka (npr. 09:00 – 17:00).';
    if (length < _slotMinutes) return 'Radno vrijeme je kraće od trajanja jednog termina ($_slotMinutes min).';
    return null;
  }

  bool get _valid => _daysError == null && _rangeError == null && _timeError == null;

  int get _slotsPerDay => ((_minutes(_end) - _minutes(_start)) / _slotMinutes).floor();

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final r = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Period radnog vremena',
      saveText: 'Primijeni',
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'Početak radnog vremena' : 'Kraj radnog vremena',
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    setState(() {
      if (start) {
        _start = t;
      } else {
        _end = t;
      }
    });
  }

  void _submit() {
    setState(() => _submitted = true);
    if (_valid) Navigator.pop(context, (windows: _windows, slotMinutes: _slotMinutes));
  }

  Widget _error(String? msg) => msg == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 12)));

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Expanded(child: Text('Radno vrijeme – dr. ${widget.doctorName}')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(context)),
      ]),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('Period'),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.date_range),
          label: Text('${_date.format(_range.start)} – ${_date.format(_range.end)}'),
        ),
        _error(_rangeError),
        _label('Radni dani'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var wd = 1; wd <= 7; wd++)
            FilterChip(
              label: Text(_weekdayShort[wd - 1]),
              tooltip: weekdayNames[wd - 1],
              selected: _days.contains(wd),
              onSelected: (v) => setState(() => v ? _days.add(wd) : _days.remove(wd)),
            ),
        ]),
        if (_submitted) _error(_daysError),
        _label('Radno vrijeme'),
        Row(children: [
          OutlinedButton.icon(onPressed: () => _pickTime(true), icon: const Icon(Icons.schedule), label: Text('Od ${formatTime(_start)}')),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
          OutlinedButton.icon(onPressed: () => _pickTime(false), icon: const Icon(Icons.schedule), label: Text('Do ${formatTime(_end)}')),
        ]),
        _error(_timeError),
        _label('Trajanje jednog termina'),
        SizedBox(width: 200, child: DropdownButtonFormField<int>(
          initialValue: _slotMinutes,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: _slotOptions.map((m) => DropdownMenuItem(value: m, child: Text('$m minuta'))).toList(),
          onChanged: (v) => setState(() => _slotMinutes = v ?? 30),
        )),
        const SizedBox(height: 16),
        if (_valid)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE3EDFB), borderRadius: BorderRadius.circular(8)),
            child: Text('Biće kreirano do ${_windows.length * _slotsPerDay} termina u ${_windows.length} radnih dana '
                '($_slotsPerDay po danu). Termini koji se preklapaju sa postojećim ili su već prošli se preskaču.'),
          ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
        FilledButton(onPressed: _submit, child: const Text('Kreiraj termine')),
      ],
    );
  }
}
