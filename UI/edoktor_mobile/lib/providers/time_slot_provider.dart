import 'package:flutter/foundation.dart';
import '../models/time_slot.dart';
import '../services/api_client.dart';

class TimeSlotProvider extends ChangeNotifier {
  Future<List<TimeSlot>> forDoctor(int doctorId, {DateTime? from, DateTime? to, bool onlyAvailable = true}) async {
    final res = await ApiClient.get('/api/time-slots', query: {
      'doctorId': doctorId,
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
      'onlyAvailable': onlyAvailable,
    });
    return (res as List).map((e) => TimeSlot.fromJson(e)).toList();
  }
}
