import 'package:flutter/foundation.dart';
import '../models/specialization.dart';
import '../services/api_client.dart';

class SpecializationProvider extends ChangeNotifier {
  Future<List<Specialization>> list() async {
    final res = await ApiClient.get('/api/specializations', query: {'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList();
  }
}
