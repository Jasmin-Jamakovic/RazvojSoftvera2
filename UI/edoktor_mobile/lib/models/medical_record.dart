class MedicalRecord {
  final int id;
  final int patientId;
  final String? patientName;
  final String? bloodType;
  final String? allergies;
  final DateTime? dateOfBirth;
  final List<MedicalRecordEntry> entries;
  final List<LabResult> labResults;
  final List<Prescription> prescriptions;

  MedicalRecord({
    required this.id, required this.patientId, this.patientName, this.bloodType, this.allergies, this.dateOfBirth,
    required this.entries, required this.labResults, required this.prescriptions,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> j) => MedicalRecord(
        id: j['id'],
        patientId: j['patientId'],
        patientName: j['patientName'],
        bloodType: j['bloodType'],
        allergies: j['allergies'],
        dateOfBirth: j['dateOfBirth'] == null ? null : DateTime.tryParse(j['dateOfBirth']),
        entries: (j['entries'] as List? ?? []).map((e) => MedicalRecordEntry.fromJson(e)).toList(),
        labResults: (j['labResults'] as List? ?? []).map((e) => LabResult.fromJson(e)).toList(),
        prescriptions: (j['prescriptions'] as List? ?? []).map((e) => Prescription.fromJson(e)).toList(),
      );
}

class MedicalRecordEntry {
  final int id;
  final DateTime appointmentDate;
  final String? doctorName;
  final String? specialization;
  final String? diagnosis;
  final String? therapy;
  final String? notes;
  final Prescription? prescription;

  MedicalRecordEntry({
    required this.id, required this.appointmentDate, this.doctorName, this.specialization,
    this.diagnosis, this.therapy, this.notes, this.prescription,
  });

  factory MedicalRecordEntry.fromJson(Map<String, dynamic> j) => MedicalRecordEntry(
        id: j['id'],
        appointmentDate: DateTime.parse(j['appointmentDate']).toLocal(),
        doctorName: j['doctorName'],
        specialization: j['specialization'],
        diagnosis: j['diagnosis'],
        therapy: j['therapy'],
        notes: j['notes'],
        prescription: j['prescription'] == null ? null : Prescription.fromJson(j['prescription']),
      );
}

class Prescription {
  final int id;
  final int appointmentId;
  final String? doctorName;
  final DateTime issuedAt;
  final List<PrescriptionItem> items;
  Prescription({required this.id, required this.appointmentId, this.doctorName, required this.issuedAt, required this.items});
  factory Prescription.fromJson(Map<String, dynamic> j) => Prescription(
        id: j['id'],
        appointmentId: j['appointmentId'] ?? 0,
        doctorName: j['doctorName'],
        issuedAt: DateTime.parse(j['issuedAt']).toLocal(),
        items: (j['items'] as List? ?? []).map((e) => PrescriptionItem.fromJson(e)).toList(),
      );
}

class PrescriptionItem {
  final int id;
  final String medication;
  final String? dosage;
  final String? frequency;
  final String? duration;
  PrescriptionItem({required this.id, required this.medication, this.dosage, this.frequency, this.duration});
  factory PrescriptionItem.fromJson(Map<String, dynamic> j) => PrescriptionItem(
        id: j['id'],
        medication: j['medication'] ?? '',
        dosage: j['dosage'],
        frequency: j['frequency'],
        duration: j['duration'],
      );
}

class LabResult {
  final int id;
  final String title;
  final String? notes;
  final String? fileUrl;
  final DateTime createdAt;
  LabResult({required this.id, required this.title, this.notes, this.fileUrl, required this.createdAt});
  factory LabResult.fromJson(Map<String, dynamic> j) => LabResult(
        id: j['id'],
        title: j['title'] ?? '',
        notes: j['notes'],
        fileUrl: j['fileUrl'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}
