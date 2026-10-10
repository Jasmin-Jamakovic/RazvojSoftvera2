import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/medical_record.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../utils/labels.dart';
import '../widgets/entity_avatar.dart';

/// Admin view of one patient: profile data, appointment history and the electronic medical record.
class PatientDetailsScreen extends StatefulWidget {
  final User patient;
  const PatientDetailsScreen({super.key, required this.patient});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  static final _date = DateFormat('dd.MM.yyyy');
  static final _dateTime = DateFormat('dd.MM.yyyy HH:mm');

  late final Future<MedicalRecord?> _record;

  @override
  void initState() {
    super.initState();
    _record = context.read<PatientProvider>().medicalRecord(widget.patient.id);
  }

  String get _initials {
    final p = widget.patient;
    return ((p.firstName.isNotEmpty ? p.firstName[0] : '') + (p.lastName.isNotEmpty ? p.lastName[0] : '')).toUpperCase();
  }

  String _gender(String? g) => switch (g) { 'M' => 'Muški', 'F' => 'Ženski', _ => '-' };

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Pacijent: ${p.fullName}'),
      ),
      body: DefaultTabController(length: 4, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EntityAvatar(path: p.hasImage ? '/api/users/${p.id}/photo' : null, initials: _initials, radius: 40),
          const SizedBox(width: 24),
          Expanded(child: Wrap(spacing: 40, runSpacing: 4, children: [
            _InfoColumn(rows: [
              ('Ime i prezime', p.fullName),
              ('Korisničko ime', p.username),
              ('Email', p.email),
              ('Telefon', p.phoneNumber ?? '-'),
            ]),
            _InfoColumn(rows: [
              ('Datum rođenja', p.dateOfBirth == null ? '-' : _date.format(p.dateOfBirth!)),
              ('Spol', _gender(p.gender)),
              ('Grad', p.cityName ?? '-'),
              ('Registrovan', p.createdAt == null ? '-' : _date.format(p.createdAt!)),
            ]),
            _InfoColumn(rows: [
              ('Krvna grupa', p.bloodType ?? '-'),
              ('Alergije', (p.allergies?.trim().isEmpty ?? true) ? 'Nema evidentiranih' : p.allergies!),
            ]),
          ])),
        ]))),
        const SizedBox(height: 12),
        const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(icon: Icon(Icons.event_note), text: 'Historija termina'),
          Tab(icon: Icon(Icons.medical_information), text: 'Pregledi'),
          Tab(icon: Icon(Icons.medication), text: 'Recepti'),
          Tab(icon: Icon(Icons.science), text: 'Nalazi'),
        ]),
        const SizedBox(height: 12),
        Expanded(child: TabBarView(children: [
          _VisitsTab(patientId: p.id),
          _recordTab((r) => _EntriesTab(entries: r.entries)),
          _recordTab((r) => _PrescriptionsTab(prescriptions: r.prescriptions)),
          _recordTab((r) => _LabResultsTab(results: r.labResults)),
        ])),
      ]))),
    );
  }

  Widget _recordTab(Widget Function(MedicalRecord r) builder) => Card(child: FutureBuilder<MedicalRecord?>(
        future: _record,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('Greška pri učitavanju kartona: ${s.error}', style: const TextStyle(color: Colors.red)));
          if (s.data == null) return const Center(child: Text('Pacijent još nema zdravstveni karton.'));
          return builder(s.data!);
        },
      ));

  static String fmtDate(DateTime d) => _date.format(d);
  static String fmtDateTime(DateTime d) => _dateTime.format(d);
}

class _InfoColumn extends StatelessWidget {
  final List<(String, String)> rows;
  const _InfoColumn({required this.rows});

  @override
  Widget build(BuildContext context) => SizedBox(width: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (label, value) in rows)
          Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ])),
      ]));
}

/// Paged list of every appointment the patient booked, newest first.
class _VisitsTab extends StatefulWidget {
  final int patientId;
  const _VisitsTab({required this.patientId});
  @override
  State<_VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends State<_VisitsTab> with AutomaticKeepAliveClientMixin {
  static const _pageSize = 10;
  int _page = 0;
  late Future<PagedList<Appointment>> _f;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _load(); }

  void _load() => setState(() { _f = context.read<PatientProvider>().visits(widget.patientId, page: _page, pageSize: _pageSize); });

  Color _color(String s) => switch (s) { 'Pending' => Colors.orange, 'Confirmed' => Colors.green, 'Completed' => Colors.blueGrey, 'Cancelled' => Colors.red, _ => Colors.grey };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(child: FutureBuilder<PagedList<Appointment>>(future: _f, builder: (c, s) {
      if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (s.hasError) return Center(child: Text('Greška pri učitavanju termina: ${s.error}', style: const TextStyle(color: Colors.red)));
      final data = s.data!;
      if (data.items.isEmpty) return const Center(child: Text('Pacijent nema zakazanih termina.'));
      final first = _page * _pageSize + 1;
      final last = (first + data.items.length - 1);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
          DataColumn(label: Text('Datum i vrijeme')),
          DataColumn(label: Text('Ljekar')),
          DataColumn(label: Text('Tip')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Cijena'), numeric: true),
          DataColumn(label: Text('Plaćeno')),
          DataColumn(label: Text('Razlog otkazivanja')),
        ], rows: data.items.map((a) => DataRow(cells: [
          DataCell(Text(_PatientDetailsScreenState.fmtDateTime(a.startUtc))),
          DataCell(Text('dr. ${a.doctorName ?? ''}')),
          DataCell(Text(a.isOnline ? 'Online' : 'Uživo')),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: _color(a.status), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(appointmentStatusLabel(a.status)),
          ])),
          DataCell(Text('${a.price.toStringAsFixed(2)} €')),
          DataCell(Icon(a.payment?['status'] == 'Captured' ? Icons.check_circle : Icons.remove_circle_outline,
              size: 18, color: a.payment?['status'] == 'Captured' ? Colors.green : Colors.grey)),
          DataCell(Text(a.cancellationReason ?? '-')),
        ])).toList())))),
        Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Prikazano $first–$last od ${data.totalCount}'),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna strana',
            onPressed: _page > 0 ? () { _page--; _load(); } : null),
          IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća strana',
            onPressed: last < data.totalCount ? () { _page++; _load(); } : null),
        ])),
      ]);
    }));
  }
}

/// Master-details: list of examinations on the left, the selected one's findings on the right.
class _EntriesTab extends StatefulWidget {
  final List<RecordEntry> entries;
  const _EntriesTab({required this.entries});
  @override
  State<_EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<_EntriesTab> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) return const Center(child: Text('U kartonu nema evidentiranih pregleda.'));
    final e = entries[_selected];
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 320, child: ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (c, i) {
          final x = entries[i];
          return ListTile(
            selected: i == _selected,
            selectedTileColor: const Color(0xFFE3EDFB),
            leading: const Icon(Icons.assignment),
            title: Text(_PatientDetailsScreenState.fmtDate(x.appointmentDate)),
            subtitle: Text('dr. ${x.doctorName ?? ''}\n${x.diagnosis ?? 'Bez dijagnoze'}', maxLines: 2, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            onTap: () => setState(() => _selected = i),
          );
        },
      )),
      const VerticalDivider(width: 1),
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pregled ${_PatientDetailsScreenState.fmtDateTime(e.appointmentDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('dr. ${e.doctorName ?? ''}${e.specialization == null ? '' : ' • ${e.specialization}'}', style: const TextStyle(color: Colors.black54)),
        const Divider(height: 28),
        _section(Icons.healing, 'Dijagnoza', e.diagnosis),
        _section(Icons.medical_services, 'Terapija', e.therapy),
        _section(Icons.notes, 'Napomene', e.notes),
        const Row(children: [Icon(Icons.medication, size: 18, color: Color(0xFF0D47A1)), SizedBox(width: 8), Text('E-recept', style: TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 6),
        if (e.prescription == null)
          const Text('Na ovom pregledu nije izdat recept.', style: TextStyle(color: Colors.black54))
        else
          PrescriptionTable(prescription: e.prescription!),
      ]))),
    ]);
  }

  Widget _section(IconData icon, String title, String? text) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 18, color: const Color(0xFF0D47A1)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))]),
          const SizedBox(height: 4),
          Text((text?.trim().isEmpty ?? true) ? '-' : text!),
        ]),
      );
}

class PrescriptionTable extends StatelessWidget {
  final Prescription prescription;
  const PrescriptionTable({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) => DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: const [
          DataColumn(label: Text('Lijek')),
          DataColumn(label: Text('Doza')),
          DataColumn(label: Text('Učestalost')),
          DataColumn(label: Text('Trajanje')),
        ],
        rows: prescription.items.map((i) => DataRow(cells: [
          DataCell(Text(i.medication)),
          DataCell(Text(i.dosage ?? '-')),
          DataCell(Text(i.frequency ?? '-')),
          DataCell(Text(i.duration ?? '-')),
        ])).toList(),
      );
}

class _PrescriptionsTab extends StatelessWidget {
  final List<Prescription> prescriptions;
  const _PrescriptionsTab({required this.prescriptions});

  @override
  Widget build(BuildContext context) {
    if (prescriptions.isEmpty) return const Center(child: Text('Pacijentu nije izdat nijedan recept.'));
    final sorted = [...prescriptions]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (c, i) {
        final p = sorted[i];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recept od ${_PatientDetailsScreenState.fmtDate(p.issuedAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Izdao: dr. ${p.doctorName ?? ''}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          PrescriptionTable(prescription: p),
        ]);
      },
    );
  }
}

class _LabResultsTab extends StatelessWidget {
  final List<LabResult> results;
  const _LabResultsTab({required this.results});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const Center(child: Text('Pacijent nema laboratorijskih nalaza.'));
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (c, i) {
        final r = results[i];
        return ListTile(
          leading: const Icon(Icons.science, color: Color(0xFF0D47A1)),
          title: Text(r.title),
          subtitle: Text(r.notes ?? ''),
          trailing: Text(_PatientDetailsScreenState.fmtDate(r.createdAt)),
        );
      },
    );
  }
}
