import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../services/api_client.dart';

class AppointmentProvider extends ChangeNotifier {
  Future<List<Appointment>> mine() async {
    final res = await ApiClient.get('/api/appointments', query: {'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
  }

  Future<Appointment> create({required int doctorId, required int timeSlotId, required int type}) async {
    final res = await ApiClient.post('/api/appointments', {'doctorId': doctorId, 'timeSlotId': timeSlotId, 'type': type});
    return Appointment.fromJson(res);
  }

  Future<Appointment> cancel(int id, {String? reason}) async {
    final res = await ApiClient.post('/api/appointments/$id/cancel', {'reason': reason});
    return Appointment.fromJson(res);
  }

  Future<void> review(int appointmentId, {required int rating, String? comment}) async {
    await ApiClient.post('/api/reviews', {
      'appointmentId': appointmentId,
      'rating': rating,
      'comment': (comment?.trim().isEmpty ?? true) ? null : comment!.trim(),
    });
  }

  Future<Map<String, dynamic>> roomFor(int appointmentId) async {
    final res = await ApiClient.post('/api/video-calls/$appointmentId/room');
    return res as Map<String, dynamic>;
  }
}
