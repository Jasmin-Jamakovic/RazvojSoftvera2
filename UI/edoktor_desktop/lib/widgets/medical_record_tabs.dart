import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/medical_record.dart';
import '../providers/providers.dart';
import '../services/auth_store.dart';
import 'lab_result_form.dart';
import 'medical_entry_form.dart';
import 'prescription_form.dart';

final _date = DateFormat('dd.MM.yyyy');
final _dateTime = DateFormat('dd.MM.yyyy HH:mm');
const _green = Color(0xFF2E7D32);

/// Who is looking at [patientId]'s record and what they may change. Tabs listen to it and
/// reload when [changed] is called (e.g. a prescription added on the Posjete tab refreshes Recepti).
class RecordContext extends ChangeNotifier {
  final int patientId;
  final bool isDoctor, isAdmin;
  final int? userId;

  /// Doctor only: their own appointments with this patient (visits can be written only for these).
  List<Appointment> myAppointments = [];
  Set<int> get myAppointmentIds => myAppointments.map((a) => a.id).toSet();

  RecordContext(this.patientId)
      : isDoctor = AuthStore.user?.role == 'doctor',
        isAdmin = AuthStore.user?.role == 'admin',
        userId = AuthStore.user?.id;

  Future<void> loadMyAppointments(AppointmentProvider p) async {
    if (!isDoctor) return;
    myAppointments = await p.forPatient(patientId);
    notifyListeners();
  }

  void changed() => notifyListeners();

  bool canEditVisit(int appointmentId) => isDoctor && myAppointmentIds.contains(appointmentId);
  bool canEditLab(LabResult l) => isAdmin || (isDoctor && l.createdById == userId);
}

Future<bool> _confirmDelete(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
    ],
  ));
  return ok == true;
}

void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Record header: basic health data and the number of visits / prescriptions / lab results.
class RecordHeaderCard extends StatefulWidget {
  final RecordContext record;
  final String patientName;
  const RecordHeaderCard({super.key, required this.record, required this.patientName});
  @override
  State<RecordHeaderCard> createState() => _RecordHeaderCardState();
}

class _RecordHeaderCardState extends State<RecordHeaderCard> {
  late Future<MedicalRecordHeader?> _f;

  @override
  void initState() {
    super.initState();
    _load();
    widget.record.addListener(_load);
  }

  @override
  void dispose() {
    widget.record.removeListener(_load);
    super.dispose();
  }

  void _load() => setState(() { _f = context.read<MedicalRecordProvider>().header(widget.record.patientId); });

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(right: 32, bottom: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label: ', style: const TextStyle(color: Colors.black54)),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ])),
      );

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: FutureBuilder<MedicalRecordHeader?>(
        future: _f,
        builder: (c, s) {
          final h = s.data;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 28, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.folder_shared, color: _green, size: 28)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h?.patientName ?? widget.patientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (s.connectionState != ConnectionState.done)
                const LinearProgressIndicator()
              else if (s.hasError)
                Text('Greška pri učitavanju kartona: ${s.error}', style: const TextStyle(color: Colors.red))
              else if (h == null)
                const Text('Pacijent još nema zdravstveni karton. Karton se otvara upisom prve posjete ili nalaza.', style: TextStyle(color: Colors.black54))
              else
                Wrap(children: [
                  _info('Datum rođenja', h.dateOfBirth == null ? '-' : _date.format(h.dateOfBirth!)),
                  _info('Krvna grupa', h.bloodType ?? '-'),
                  _info('Alergije', (h.allergies?.trim().isEmpty ?? true) ? 'Nema evidentiranih' : h.allergies!),
                  _info('Posjete', '${h.entryCount}'),
                  _info('Recepti', '${h.prescriptionCount}'),
                  _info('Nalazi', '${h.labResultCount}'),
                ]),
            ])),
          ]);
        },
      )));
}

/// A searchable, paged list that reloads (from the first page) whenever [record] changes.
class _PagedRecordList<T> extends StatefulWidget {
  final RecordContext record;
  final Future<PagedList<T>> Function(int page, int pageSize, String? search) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyText, searchHint;
  final List<Widget> actions;
  final int pageSize;
  const _PagedRecordList({super.key, required this.record, required this.fetch, required this.itemBuilder,
      required this.emptyText, required this.searchHint, this.actions = const [], this.pageSize = 5});

  @override
  State<_PagedRecordList<T>> createState() => _PagedRecordListState<T>();
}

class _PagedRecordListState<T> extends State<_PagedRecordList<T>> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;
  int _page = 0;
  late Future<PagedList<T>> _f;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    widget.record.addListener(_reset);
  }

  @override
  void dispose() {
    widget.record.removeListener(_reset);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() => setState(() { _f = widget.fetch(_page, widget.pageSize, _search.text); });
  void _reset() { _page = 0; _load(); }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reset);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Row(children: [
        SizedBox(width: 320, child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true, border: const OutlineInputBorder(),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _reset(); }),
          ),
          onChanged: _onSearch,
        )),
        const Spacer(),
        ...widget.actions,
      ])),
      Expanded(child: FutureBuilder<PagedList<T>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('Greška pri učitavanju: ${s.error}', style: const TextStyle(color: Colors.red)));
        final data = s.data!;
        if (data.items.isEmpty) return Center(child: Text(_search.text.trim().isEmpty ? widget.emptyText : 'Nema rezultata za zadanu pretragu.'));
        final first = _page * widget.pageSize + 1;
        final last = first + data.items.length - 1;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => widget.itemBuilder(c, data.items[i]),
          )),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Prikazano $first–$last od ${data.totalCount}'),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna strana',
              onPressed: _page > 0 ? () { _page--; _load(); } : null),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća strana',
              onPressed: last < data.totalCount ? () { _page++; _load(); } : null),
          ])),
        ]);
      })),
    ]));
  }
}

Widget _section(IconData icon, String title, String? text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 18, color: _green), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 4),
        Text((text?.trim().isEmpty ?? true) ? '-' : text!),
      ]),
    );

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

// ------------------------------------------------------------------ prescription actions (shared by two tabs)

Future<void> _editPrescription(BuildContext context, RecordContext record,
    {required int entryId, required DateTime visitDate, String? diagnosis, Prescription? existing}) async {
  final ok = await showPrescriptionForm(context, entryId: entryId, visitDate: visitDate, diagnosis: diagnosis, existing: existing);
  if (!ok || !context.mounted) return;
  record.changed();
  _snack(context, existing == null ? 'Recept je uspješno izdat.' : 'Recept je uspješno ažuriran.');
}

Future<void> _deletePrescription(BuildContext context, RecordContext record, Prescription p) async {
  if (!await _confirmDelete(context, 'Brisanje recepta', 'Jeste li sigurni da želite obrisati recept od ${_date.format(p.issuedAt)}? Ova akcija je nepovratna.')) return;
  if (!context.mounted) return;
  try {
    await context.read<MedicalRecordProvider>().deletePrescription(p.id);
    record.changed();
    if (context.mounted) _snack(context, 'Recept je uspješno obrisan.');
  } catch (e) {
    if (context.mounted) _snack(context, '$e');
  }
}

// ------------------------------------------------------------------ Posjete

class RecordEntriesTab extends StatelessWidget {
  final RecordContext record;
  const RecordEntriesTab({super.key, required this.record});

  Future<void> _add(BuildContext context) async {
    final appts = context.read<AppointmentProvider>();
    final records = context.read<MedicalRecordProvider>();
    List<Appointment> eligible;
    try {
      await record.loadMyAppointments(appts);
      final withEntry = await records.entryAppointmentIds(record.patientId);
      eligible = record.myAppointments
          .where((a) => (a.status == 'Confirmed' || a.status == 'Completed') && !withEntry.contains(a.id))
          .toList();
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
      return;
    }
    if (!context.mounted) return;
    if (eligible.isEmpty) {
      _snack(context, 'Nema potvrđenih ili završenih termina sa ovim pacijentom bez upisane posjete.');
      return;
    }
    if (!await showMedicalEntryForm(context, appointments: eligible) || !context.mounted) return;
    record.changed();
    _snack(context, 'Posjeta je uspješno upisana u karton.');
  }

  Future<void> _edit(BuildContext context, RecordEntry e) async {
    if (!await showMedicalEntryForm(context, entry: e) || !context.mounted) return;
    record.changed();
    _snack(context, 'Posjeta je uspješno ažurirana.');
  }

  Future<void> _delete(BuildContext context, RecordEntry e) async {
    final extra = e.prescription == null ? '' : ' Obrisaće se i recept izdat na ovoj posjeti.';
    if (!await _confirmDelete(context, 'Brisanje posjete', 'Jeste li sigurni da želite obrisati posjetu od ${_date.format(e.appointmentDate)}?$extra Ova akcija je nepovratna.')) return;
    if (!context.mounted) return;
    try {
      await context.read<MedicalRecordProvider>().deleteEntry(e.id);
      record.changed();
      if (context.mounted) _snack(context, 'Posjeta je uspješno obrisana.');
    } catch (err) {
      if (context.mounted) _snack(context, '$err');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MedicalRecordProvider>();
    return _PagedRecordList<RecordEntry>(
      record: record,
      fetch: (page, size, search) => provider.entries(record.patientId, page: page, pageSize: size, search: search),
      emptyText: 'U kartonu nema evidentiranih posjeta.',
      searchHint: 'Pretraga po dijagnozi...',
      actions: [if (record.isDoctor) FilledButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('Posjeta'))],
      itemBuilder: (c, e) {
        final mine = record.canEditVisit(e.appointmentId);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.assignment, color: _green),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Posjeta ${_dateTime.format(e.appointmentDate)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('dr. ${e.doctorName ?? ''}${e.specialization == null ? '' : ' • ${e.specialization}'}', style: const TextStyle(color: Colors.black54)),
              ])),
              if (mine) ...[
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Uredi posjetu', onPressed: () => _edit(c, e)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Obriši posjetu', onPressed: () => _delete(c, e)),
              ],
            ]),
            const Divider(height: 24),
            _section(Icons.healing, 'Dijagnoza', e.diagnosis),
            _section(Icons.medical_services, 'Terapija', e.therapy),
            _section(Icons.notes, 'Napomene', e.notes),
            Row(children: [
              const Icon(Icons.medication, size: 18, color: _green),
              const SizedBox(width: 8),
              const Text('E-recept', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (mine && e.prescription == null)
                TextButton.icon(
                  onPressed: () => _editPrescription(c, record, entryId: e.id, visitDate: e.appointmentDate, diagnosis: e.diagnosis),
                  icon: const Icon(Icons.add), label: const Text('Recept')),
              if (mine && e.prescription != null) ...[
                TextButton.icon(
                  onPressed: () => _editPrescription(c, record, entryId: e.id, visitDate: e.appointmentDate, diagnosis: e.diagnosis, existing: e.prescription),
                  icon: const Icon(Icons.edit, size: 18), label: const Text('Uredi recept')),
                TextButton.icon(
                  onPressed: () => _deletePrescription(c, record, e.prescription!),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red), label: const Text('Obriši recept', style: TextStyle(color: Colors.red))),
              ],
            ]),
            const SizedBox(height: 6),
            if (e.prescription == null)
              const Text('Na ovoj posjeti nije izdat recept.', style: TextStyle(color: Colors.black54))
            else
              PrescriptionTable(prescription: e.prescription!),
          ])),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Recepti

class RecordPrescriptionsTab extends StatelessWidget {
  final RecordContext record;
  const RecordPrescriptionsTab({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MedicalRecordProvider>();
    return _PagedRecordList<Prescription>(
      record: record,
      fetch: (page, size, search) => provider.prescriptions(record.patientId, page: page, pageSize: size, search: search),
      emptyText: 'Pacijentu nije izdat nijedan recept.',
      searchHint: 'Pretraga po lijeku...',
      actions: [if (record.isDoctor) const Tooltip(message: 'Recept se izdaje na posjeti (kartica Posjete → + Recept).', child: Icon(Icons.info_outline, color: Colors.black45))],
      itemBuilder: (c, p) {
        final mine = record.canEditVisit(p.appointmentId);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Recept od ${_date.format(p.issuedAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Izdao: dr. ${p.doctorName ?? ''}${p.diagnosis == null ? '' : ' • Dijagnoza: ${p.diagnosis}'}',
                    style: const TextStyle(color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              if (mine) ...[
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Uredi recept',
                  onPressed: () => _editPrescription(c, record, entryId: p.medicalRecordEntryId, visitDate: p.issuedAt, diagnosis: p.diagnosis, existing: p)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Obriši recept', onPressed: () => _deletePrescription(c, record, p)),
              ],
            ]),
            const SizedBox(height: 8),
            PrescriptionTable(prescription: p),
          ])),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Nalazi

class RecordLabResultsTab extends StatelessWidget {
  final RecordContext record;
  const RecordLabResultsTab({super.key, required this.record});

  Future<void> _edit(BuildContext context, [LabResult? l]) async {
    if (!await showLabResultForm(context, patientId: record.patientId, result: l) || !context.mounted) return;
    record.changed();
    _snack(context, l == null ? 'Nalaz je uspješno dodan.' : 'Nalaz je uspješno ažuriran.');
  }

  Future<void> _delete(BuildContext context, LabResult l) async {
    if (!await _confirmDelete(context, 'Brisanje nalaza', 'Jeste li sigurni da želite obrisati nalaz "${l.title}"? Ova akcija je nepovratna.')) return;
    if (!context.mounted) return;
    try {
      await context.read<MedicalRecordProvider>().deleteLabResult(l.id);
      record.changed();
      if (context.mounted) _snack(context, 'Nalaz je uspješno obrisan.');
    } catch (e) {
      if (context.mounted) _snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<MedicalRecordProvider>();
    return _PagedRecordList<LabResult>(
      record: record,
      pageSize: 10,
      fetch: (page, size, search) => provider.labResults(record.patientId, page: page, pageSize: size, search: search),
      emptyText: 'Pacijent nema laboratorijskih nalaza.',
      searchHint: 'Pretraga po nazivu nalaza...',
      actions: [if (record.isDoctor || record.isAdmin) FilledButton.icon(onPressed: () => _edit(context), icon: const Icon(Icons.add), label: const Text('Nalaz'))],
      itemBuilder: (c, l) => ListTile(
        leading: const Icon(Icons.science, color: _green),
        title: Text(l.title),
        subtitle: Text([
          if (l.notes?.trim().isNotEmpty ?? false) l.notes!,
          '${_date.format(l.createdAt)}${l.createdByName == null ? '' : ' • Unio: ${l.createdByName}'}',
        ].join('\n')),
        isThreeLine: l.notes?.trim().isNotEmpty ?? false,
        trailing: record.canEditLab(l)
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Uredi nalaz', onPressed: () => _edit(c, l)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Obriši nalaz', onPressed: () => _delete(c, l)),
              ])
            : null,
      ),
    );
  }
}
