import 'package:flutter/foundation.dart';
import '../models/time_slot.dart';
import '../services/api_client.dart';

class TimeSlotProvider extends ChangeNotifier {
  /// All free slots of a doctor in [from, to), fetched page by page (the API caps a page at 100).
  Future<List<TimeSlot>> freeInRange(int doctorId, DateTime from, DateTime to) async {
    const pageSize = 100;
    final all = <TimeSlot>[];
    for (var page = 0;; page++) {
      final res = await ApiClient.get('/api/time-slots', query: {
        'doctorId': doctorId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'onlyAvailable': true,
        'page': page,
        'pageSize': pageSize,
      });
      final items = (res as List).map((e) => TimeSlot.fromJson(e)).toList();
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
  }
}
