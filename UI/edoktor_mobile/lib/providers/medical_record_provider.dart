import 'package:flutter/foundation.dart';
import '../models/medical_record.dart';
import '../services/api_client.dart';

/// The signed-in patient's medical record: the header plus paged visits, prescriptions and lab results.
class MedicalRecordProvider extends ChangeNotifier {
  static const maxPageSize = 100;

  /// Record header (blood type, allergies, counts); null when the patient has no record yet.
  Future<MedicalRecord?> mine() async {
    final res = await ApiClient.get('/api/medical-records/me');
    if (res is! Map<String, dynamic> || res.isEmpty) return null;
    return MedicalRecord.fromJson(res);
  }

  /// Visits (diagnosis / therapy), newest first. [search] matches the diagnosis.
  Future<(List<MedicalRecordEntry>, int)> entries({int page = 0, int pageSize = 20, String? search}) =>
      _page('/api/medical-records/me/entries', MedicalRecordEntry.fromJson, page, pageSize, search);

  /// E-prescriptions. [search] matches a medication.
  Future<(List<Prescription>, int)> prescriptions({int page = 0, int pageSize = 20, String? search}) =>
      _page('/api/medical-records/me/prescriptions', Prescription.fromJson, page, pageSize, search);

  /// Lab results. [search] matches the title.
  Future<(List<LabResult>, int)> labResults({int page = 0, int pageSize = 20, String? search}) =>
      _page('/api/medical-records/me/lab-results', LabResult.fromJson, page, pageSize, search);

  Future<(List<T>, int)> _page<T>(
      String path, T Function(Map<String, dynamic>) fromJson, int page, int pageSize, String? search) async {
    final q = search?.trim();
    final res = await ApiClient.get(path, query: {
      'page': page,
      'pageSize': pageSize.clamp(1, maxPageSize),
      if (q != null && q.isNotEmpty) 'search': q,
    });
    if (res == null) return (<T>[], 0);
    final items = (res['items'] as List? ?? []).map((e) => fromJson(e as Map<String, dynamic>)).toList();
    return (items, (res['totalCount'] as int?) ?? items.length);
  }
}
