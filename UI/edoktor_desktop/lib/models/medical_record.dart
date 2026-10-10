DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v).toLocal();

class PrescriptionItem {
  final String medication;
  final String? dosage, frequency, duration;
  PrescriptionItem({required this.medication, this.dosage, this.frequency, this.duration});
  factory PrescriptionItem.fromJson(Map<String, dynamic> j) => PrescriptionItem(
        medication: j['medication'] ?? '', dosage: j['dosage'], frequency: j['frequency'], duration: j['duration']);
}

class Prescription {
  final int id;
  final String? doctorName;
  final DateTime issuedAt;
  final List<PrescriptionItem> items;
  Prescription({required this.id, this.doctorName, required this.issuedAt, required this.items});
  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        id: j['id'], doctorName: j['doctorName'], issuedAt: _date(j['issuedAt'])!,
        items: (j['items'] as List? ?? []).map((e) => PrescriptionItem.fromJson(e)).toList());
}

class RecordEntry {
  final int id;
  final DateTime appointmentDate;
  final String? doctorName, specialization, diagnosis, therapy, notes;
  final Prescription? prescription;
  RecordEntry({required this.id, required this.appointmentDate, this.doctorName, this.specialization, this.diagnosis, this.therapy, this.notes, this.prescription});
  factory RecordEntry.fromJson(Map<String, dynamic> j) => RecordEntry(
        id: j['id'], appointmentDate: _date(j['appointmentDate'])!, doctorName: j['doctorName'],
        specialization: j['specialization'], diagnosis: j['diagnosis'], therapy: j['therapy'], notes: j['notes'],
        prescription: j['prescription'] == null ? null : Prescription.fromJson(j['prescription']));
}

class LabResult {
  final int id;
  final String title;
  final String? notes;
  final DateTime createdAt;
  LabResult({required this.id, required this.title, this.notes, required this.createdAt});
  factory LabResult.fromJson(Map<String, dynamic> j) =>
      LabResult(id: j['id'], title: j['title'] ?? '', notes: j['notes'], createdAt: _date(j['createdAt'])!);
}

class MedicalRecord {
  final String? bloodType, allergies;
  final DateTime? dateOfBirth;
  final List<RecordEntry> entries;
  final List<LabResult> labResults;
  final List<Prescription> prescriptions;
  MedicalRecord({this.bloodType, this.allergies, this.dateOfBirth, required this.entries, required this.labResults, required this.prescriptions});
  factory MedicalRecord.fromJson(Map<String, dynamic> j) => MedicalRecord(
        bloodType: j['bloodType'], allergies: j['allergies'], dateOfBirth: _date(j['dateOfBirth']),
        entries: (j['entries'] as List? ?? []).map((e) => RecordEntry.fromJson(e)).toList(),
        labResults: (j['labResults'] as List? ?? []).map((e) => LabResult.fromJson(e)).toList(),
        prescriptions: (j['prescriptions'] as List? ?? []).map((e) => Prescription.fromJson(e)).toList());
}
