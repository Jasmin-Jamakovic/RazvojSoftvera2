import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../widgets/medical_record_tabs.dart';

/// The doctor's view of a patient's electronic medical record: header + Posjete / Recepti / Nalazi, paged.
/// The doctor writes visits and prescriptions for their own appointments with this patient and adds lab results.
class PatientRecordScreen extends StatefulWidget {
  final int patientId;
  final String patientName;
  const PatientRecordScreen({super.key, required this.patientId, required this.patientName});

  @override
  State<PatientRecordScreen> createState() => _PatientRecordScreenState();
}

class _PatientRecordScreenState extends State<PatientRecordScreen> {
  late final RecordContext _record = RecordContext(widget.patientId);

  @override
  void initState() {
    super.initState();
    // Which visits are the doctor's own (editable) depends on their appointments with this patient.
    _record.loadMyAppointments(context.read<AppointmentProvider>()).catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    });
  }

  @override
  void dispose() {
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6F2),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Karton pacijenta: ${widget.patientName}'),
      ),
      body: DefaultTabController(length: 3, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RecordHeaderCard(record: _record, patientName: widget.patientName),
        const SizedBox(height: 12),
        const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
          Tab(icon: Icon(Icons.medical_information), text: 'Posjete'),
          Tab(icon: Icon(Icons.medication), text: 'Recepti'),
          Tab(icon: Icon(Icons.science), text: 'Nalazi'),
        ]),
        const SizedBox(height: 12),
        Expanded(child: TabBarView(children: [
          RecordEntriesTab(record: _record),
          RecordPrescriptionsTab(record: _record),
          RecordLabResultsTab(record: _record),
        ])),
      ]))),
    );
  }
}
