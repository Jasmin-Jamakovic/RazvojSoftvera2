import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medical_record.dart';
import '../providers/medical_record_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'record_details_screen.dart';

enum _Kind { visit, prescription, lab }

class MedicalRecordTab extends StatefulWidget {
  const MedicalRecordTab({super.key});
  @override
  State<MedicalRecordTab> createState() => _MedicalRecordTabState();
}

class _MedicalRecordTabState extends State<MedicalRecordTab> {
  late Future<MedicalRecord?> _f;
  _Kind? _filter;

  static const _kindStyle = {
    _Kind.visit: (Icons.medical_services_outlined, AppColors.primary, AppColors.tint),
    _Kind.prescription: (Icons.medication_outlined, Color(0xFF7B1FA2), Color(0xFFF3E8FD)),
    _Kind.lab: (Icons.description_outlined, Color(0xFFEF6C00), Color(0xFFFFF2E0)),
  };

  @override
  void initState() {
    super.initState();
    _f = context.read<MedicalRecordProvider>().mine();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MedicalRecord?>(
      future: _f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final r = s.data;
        if (r == null) {
          return const Center(child: EmptyState(icon: Icons.medical_information_outlined, message: 'Nema kartona.'));
        }
        final items = _timeline(r).where((e) => _filter == null || e.kind == _filter).toList();
        return ListView(padding: EdgeInsets.zero, children: [
          _header(context, r),
          if (r.allergies != null && r.allergies!.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                border: Border.all(color: const Color(0xFFFFD8A8)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(TextSpan(
                    style: const TextStyle(color: Color(0xFF8A4B00), fontSize: 13),
                    children: [const TextSpan(text: 'Alergije: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: r.allergies)],
                  )),
                ),
              ]),
            ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              children: [
                SelectChip(label: 'Sve', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                SelectChip(label: 'Pregledi (${r.entries.length})', selected: _filter == _Kind.visit, onTap: () => setState(() => _filter = _Kind.visit)),
                const SizedBox(width: 8),
                SelectChip(label: 'Recepti (${r.prescriptions.length})', selected: _filter == _Kind.prescription, onTap: () => setState(() => _filter = _Kind.prescription)),
                const SizedBox(width: 8),
                SelectChip(label: 'Nalazi (${r.labResults.length})', selected: _filter == _Kind.lab, onTap: () => setState(() => _filter = _Kind.lab)),
              ],
            ),
          ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.inbox_outlined, message: 'Nema unosa.')
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(children: [
                for (var i = 0; i < items.length; i++) _timelineRow(items[i], last: i == items.length - 1),
              ]),
            ),
        ]);
      },
    );
  }

  Widget _header(BuildContext context, MedicalRecord r) {
    final dob = r.dateOfBirth;
    String age = '-';
    if (dob != null) {
      final now = DateTime.now();
      var y = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) y--;
      age = '$y';
    }
    return Container(
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 16, 18, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Moj karton', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        if (r.patientName != null)
          Text(r.patientName!, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          _vital('Krvna grupa', r.bloodType ?? '-'),
          const SizedBox(width: 8),
          _vital('Godine', age),
          const SizedBox(width: 8),
          _vital('Pregleda', '${r.entries.length}'),
        ]),
      ]),
    );
  }

  Widget _vital(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  List<_Item> _timeline(MedicalRecord r) {
    final fmt = DateFormat('dd.MM.yyyy');
    final out = <_Item>[
      for (final e in r.entries)
        _Item(
          kind: _Kind.visit,
          date: e.appointmentDate,
          title: e.diagnosis ?? 'Pregled',
          subtitle: [e.doctorName, e.specialization].whereType<String>().join(' · '),
          trailing: fmt.format(e.appointmentDate),
          lines: [
            if (e.therapy != null) ('Terapija', e.therapy!),
          ],
          details: () => RecordDetailsScreen.visit(r, e),
        ),
      for (final p in r.prescriptions)
        _Item(
          kind: _Kind.prescription,
          date: p.issuedAt,
          title: 'Recept',
          subtitle: p.doctorName ?? '',
          trailing: fmt.format(p.issuedAt),
          lines: [
            for (final it in p.items)
              (
                it.medication,
                [it.dosage, it.frequency, it.duration].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              ),
          ],
          details: () => RecordDetailsScreen.prescription(r, p),
        ),
      for (final l in r.labResults)
        _Item(
          kind: _Kind.lab,
          date: l.createdAt,
          title: l.title,
          subtitle: l.notes ?? '',
          trailing: fmt.format(l.createdAt),
          details: () => RecordDetailsScreen.lab(r, l),
        ),
    ];
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  Widget _timelineRow(_Item it, {required bool last}) {
    final (icon, fg, bg) = _kindStyle[it.kind]!;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          IconSquare(icon, size: 34, iconSize: 17, color: fg, background: bg),
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: last ? Colors.transparent : const Color(0xFFD6DDD8),
            ),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.details())),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(it.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                const SizedBox(width: 8),
                Text(it.trailing, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
              if (it.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(it.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              for (final (label, value) in it.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text.rich(TextSpan(
                    style: const TextStyle(fontSize: 13, color: Color(0xFF4A5263), height: 1.4),
                    children: [
                      TextSpan(text: value.isEmpty ? label : '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (value.isNotEmpty) TextSpan(text: value),
                    ],
                  )),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Text('Detalji i PDF', style: TextStyle(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Item {
  final _Kind kind;
  final DateTime date;
  final String title;
  final String subtitle;
  final String trailing;
  final List<(String, String)> lines;
  final Widget Function() details;

  _Item({
    required this.kind,
    required this.date,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.lines = const [],
    required this.details,
  });
}
