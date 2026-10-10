import 'package:flutter/foundation.dart';
import '../models/doctor.dart';
import '../models/review.dart';
import '../services/api_client.dart';

class DoctorProvider extends ChangeNotifier {
  Future<List<Doctor>> search({String? name, int? specializationId}) async {
    final res = await ApiClient.get('/api/doctors', query: {
      'name': name?.isEmpty == true ? null : name,
      'specializationId': specializationId,
      'pageSize': 50,
    });
    final items = (res['items'] as List? ?? []).map((e) => Doctor.fromJson(e)).toList();
    return items;
  }

  Future<List<Doctor>> recommended({int n = 10}) async {
    final res = await ApiClient.get('/api/doctors/recommended', query: {'n': n});
    return (res as List).map((e) => Doctor.fromJson(e)).toList();
  }

  /// Newest reviews of a doctor (first page) and the total count.
  Future<(List<Review>, int)> reviews(int doctorId, {int pageSize = 5}) async {
    final res = await ApiClient.get('/api/reviews', query: {'doctorId': doctorId, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => Review.fromJson(e)).toList();
    return (items, (res['totalCount'] as int?) ?? items.length);
  }

  Future<Doctor> byId(int id) async {
    final res = await ApiClient.get('/api/doctors/$id');
    return Doctor.fromJson(res);
  }
}
