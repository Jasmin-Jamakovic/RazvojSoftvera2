import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medical_record.dart';
import '../providers/medical_record_provider.dart';

class MedicalRecordTab extends StatefulWidget {
  const MedicalRecordTab({super.key});
  @override
  State<MedicalRecordTab> createState() => _MedicalRecordTabState();
}

class _MedicalRecordTabState extends State<MedicalRecordTab> {
  late Future<MedicalRecord?> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<MedicalRecordProvider>().mine();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Moj zdravstveni karton'), automaticallyImplyLeading: false, bottom: const TabBar(tabs: [Tab(text: 'Pregledi'), Tab(text: 'Recepti'), Tab(text: 'Nalazi')])),
        body: FutureBuilder<MedicalRecord?>(future: _f, builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return Center(child: Text('${s.error}'));
          final r = s.data;
          if (r == null) return const Center(child: Text('Nema kartona.'));
          return Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.person, color: Color(0xFF0D47A1))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.patientName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (r.dateOfBirth != null) Text('Rođen/a: ${DateFormat('dd.MM.yyyy').format(r.dateOfBirth!)}'),
                if (r.bloodType != null) Text('Krvna grupa: ${r.bloodType}'),
                if (r.allergies != null && r.allergies!.isNotEmpty) Text('Alergije: ${r.allergies}'),
              ])),
            ])))),
            Expanded(child: TabBarView(children: [_visits(r), _prescriptions(r), _labs(r)])),
          ]);
        }),
      ),
    );
  }

  Widget _visits(MedicalRecord r) {
    final fmt = DateFormat('dd.MM.yyyy');
    if (r.entries.isEmpty) return const Center(child: Text('Nema unosa.'));
    return ListView.builder(itemCount: r.entries.length, itemBuilder: (c, i) {
      final e = r.entries[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${fmt.format(e.appointmentDate)} • ${e.doctorName ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
        if (e.specialization != null) Text(e.specialization!, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        if (e.diagnosis != null) _row('Dijagnoza', e.diagnosis!),
        if (e.therapy != null) _row('Terapija', e.therapy!),
        if (e.notes != null) _row('Bilješke', e.notes!),
      ])));
    });
  }

  Widget _prescriptions(MedicalRecord r) {
    if (r.prescriptions.isEmpty) return const Center(child: Text('Nema recepata.'));
    final fmt = DateFormat('dd.MM.yyyy');
    return ListView.builder(itemCount: r.prescriptions.length, itemBuilder: (c, i) {
      final p = r.prescriptions[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${fmt.format(p.issuedAt)} • ${p.doctorName ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...p.items.map((it) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• ${it.medication}${it.dosage != null ? ' (${it.dosage})' : ''}${it.frequency != null ? ' — ${it.frequency}' : ''}${it.duration != null ? ' — ${it.duration}' : ''}'))),
      ])));
    });
  }

  Widget _labs(MedicalRecord r) {
    if (r.labResults.isEmpty) return const Center(child: Text('Nema nalaza.'));
    final fmt = DateFormat('dd.MM.yyyy');
    return ListView.builder(itemCount: r.labResults.length, itemBuilder: (c, i) {
      final l = r.labResults[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: ListTile(
        title: Text(l.title),
        subtitle: Text('${fmt.format(l.createdAt)}${l.notes != null ? "\n${l.notes}" : ""}'),
        trailing: l.fileUrl != null ? const Icon(Icons.download) : null,
      ));
    });
  }

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)])));
}
