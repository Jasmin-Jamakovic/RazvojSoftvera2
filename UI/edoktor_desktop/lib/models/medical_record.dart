DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v).toLocal();

class PrescriptionItem {
  final int? id;
  final String medication;
  final String? dosage, frequency, duration;
  PrescriptionItem({this.id, required this.medication, this.dosage, this.frequency, this.duration});
  factory PrescriptionItem.fromJson(Map<String, dynamic> j) => PrescriptionItem(
        id: j['id'], medication: j['medication'] ?? '', dosage: j['dosage'], frequency: j['frequency'], duration: j['duration']);
  Map<String, dynamic> toJson() => {'medication': medication, 'dosage': dosage, 'frequency': frequency, 'duration': duration};
}

class Prescription {
  final int id, medicalRecordEntryId, appointmentId;
  final String? doctorName, diagnosis;
  final DateTime issuedAt;
  final List<PrescriptionItem> items;
  Prescription({required this.id, required this.medicalRecordEntryId, required this.appointmentId, this.doctorName, this.diagnosis, required this.issuedAt, required this.items});
  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        id: j['id'], medicalRecordEntryId: j['medicalRecordEntryId'] ?? 0, appointmentId: j['appointmentId'] ?? 0,
        doctorName: j['doctorName'], diagnosis: j['diagnosis'], issuedAt: _date(j['issuedAt'])!,
        items: (j['items'] as List? ?? []).map((e) => PrescriptionItem.fromJson(e)).toList());
}

/// One visit in the medical record (diagnosis / therapy written by the appointment's doctor).
class RecordEntry {
  final int id, appointmentId, doctorId;
  final DateTime appointmentDate;
  final String? doctorName, specialization, diagnosis, therapy, notes;
  final Prescription? prescription;
  RecordEntry({required this.id, required this.appointmentId, required this.doctorId, required this.appointmentDate, this.doctorName, this.specialization, this.diagnosis, this.therapy, this.notes, this.prescription});
  factory RecordEntry.fromJson(Map<String, dynamic> j) => RecordEntry(
        id: j['id'], appointmentId: j['appointmentId'] ?? 0, doctorId: j['doctorId'] ?? 0,
        appointmentDate: _date(j['appointmentDate'])!, doctorName: j['doctorName'],
        specialization: j['specialization'], diagnosis: j['diagnosis'], therapy: j['therapy'], notes: j['notes'],
        prescription: j['prescription'] == null ? null : Prescription.fromJson(j['prescription']));
}

class LabResult {
  final int id, patientId;
  final String title;
  final String? notes, createdByName;
  final int? createdById;
  final DateTime createdAt;
  LabResult({required this.id, required this.patientId, required this.title, this.notes, required this.createdAt, this.createdById, this.createdByName});
  factory LabResult.fromJson(Map<String, dynamic> j) => LabResult(
        id: j['id'], patientId: j['patientId'] ?? 0, title: j['title'] ?? '', notes: j['notes'],
        createdAt: _date(j['createdAt'])!, createdById: j['createdById'], createdByName: j['createdByName']);
}

/// Record "header": basic health data and how many visits / prescriptions / lab results it holds.
/// The lists themselves are loaded page by page from their own endpoints.
class MedicalRecordHeader {
  final int id, patientId;
  final String? patientName, bloodType, allergies;
  final DateTime? dateOfBirth;
  final int entryCount, prescriptionCount, labResultCount;
  MedicalRecordHeader({required this.id, required this.patientId, this.patientName, this.bloodType, this.allergies, this.dateOfBirth,
      required this.entryCount, required this.prescriptionCount, required this.labResultCount});
  factory MedicalRecordHeader.fromJson(Map<String, dynamic> j) => MedicalRecordHeader(
        id: j['id'], patientId: j['patientId'], patientName: j['patientName'], bloodType: j['bloodType'], allergies: j['allergies'],
        dateOfBirth: j['dateOfBirth'] == null ? null : DateTime.parse(j['dateOfBirth']),
        entryCount: j['entryCount'] ?? 0, prescriptionCount: j['prescriptionCount'] ?? 0, labResultCount: j['labResultCount'] ?? 0);
}
