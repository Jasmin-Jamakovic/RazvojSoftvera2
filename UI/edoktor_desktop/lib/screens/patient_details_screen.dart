import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../utils/labels.dart';
import '../widgets/entity_avatar.dart';
import '../widgets/medical_record_tabs.dart';

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

  late final RecordContext _record = RecordContext(widget.patient.id);

  @override
  void dispose() {
    _record.dispose();
    super.dispose();
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
      backgroundColor: const Color(0xFFF1F6F2),
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
          Tab(icon: Icon(Icons.medical_information), text: 'Posjete'),
          Tab(icon: Icon(Icons.medication), text: 'Recepti'),
          Tab(icon: Icon(Icons.science), text: 'Nalazi'),
        ]),
        const SizedBox(height: 12),
        Expanded(child: TabBarView(children: [
          _VisitsTab(patientId: p.id),
          RecordEntriesTab(record: _record),
          RecordPrescriptionsTab(record: _record),
          RecordLabResultsTab(record: _record),
        ])),
      ]))),
    );
  }

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
