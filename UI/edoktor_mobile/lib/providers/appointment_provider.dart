import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/consultation_message.dart';
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

  /// One page of the consultation chat, newest first, plus the total message count.
  Future<(List<ConsultationMessage>, int)> messages(int appointmentId, {int page = 0, int pageSize = 30}) async {
    final res = await ApiClient.get('/api/video-calls/$appointmentId/messages', query: {'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => ConsultationMessage.fromJson(e)).toList();
    return (items, (res['totalCount'] as int?) ?? items.length);
  }

  Future<ConsultationMessage> sendMessage(int appointmentId, {String? text, Uint8List? image}) async {
    final res = await ApiClient.post('/api/video-calls/$appointmentId/messages', {
      'text': text,
      'image': image == null ? null : base64Encode(image),
    });
    return ConsultationMessage.fromJson(res);
  }

  String messageImagePath(int appointmentId, int messageId) => '/api/video-calls/$appointmentId/messages/$messageId/image';

  Future<Map<String, dynamic>> roomFor(int appointmentId) async {
    final res = await ApiClient.post('/api/video-calls/$appointmentId/room');
    return res as Map<String, dynamic>;
  }
}
