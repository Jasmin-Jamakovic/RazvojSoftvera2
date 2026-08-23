import 'package:flutter/foundation.dart';
import '../models/medical_record.dart';
import '../services/api_client.dart';

class MedicalRecordProvider extends ChangeNotifier {
  Future<MedicalRecord?> mine() async {
    final res = await ApiClient.get('/api/medical-records/me');
    if (res == null) return null;
    return MedicalRecord.fromJson(res);
  }
}
