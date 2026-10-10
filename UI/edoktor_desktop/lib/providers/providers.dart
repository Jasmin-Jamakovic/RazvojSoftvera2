import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';
import '../models/dashboard.dart';
import '../models/entities.dart';
import '../models/medical_record.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';

class AuthProvider extends ChangeNotifier {
  bool get isLoggedIn => AuthStore.token != null;
  User? get user => AuthStore.user;

  Future<void> login(String username, String password) async {
    final res = await ApiClient.post('/api/auth/login', {'username': username, 'password': password});
    await AuthStore.save(res['token'], User.fromJson(res['user']));
    notifyListeners();
  }

  Future<void> logout() async { await AuthStore.clear(); notifyListeners(); }
}

class DashboardProvider extends ChangeNotifier {
  Future<DashboardStats> stats() async {
    final res = await ApiClient.get('/api/dashboard/stats');
    return DashboardStats.fromJson(res);
  }
}

class SpecializationProvider extends ChangeNotifier {
  Future<List<Specialization>> list({String? name}) async {
    final res = await ApiClient.get('/api/specializations', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, String? description}) async {
    final body = {'name': name, 'description': description};
    if (id == null) await ApiClient.post('/api/specializations', body);
    else await ApiClient.put('/api/specializations/$id', body);
  }
  Future<void> delete(int id) => ApiClient.delete('/api/specializations/$id');
}

class ClinicProvider extends ChangeNotifier {
  Future<List<Clinic>> list({String? name, int? cityId}) async {
    final res = await ApiClient.get('/api/clinics', query: {'name': name?.isEmpty == true ? null : name, 'cityId': cityId, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Clinic.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, String? address, int? cityId, double? latitude, double? longitude}) async {
    final body = {'name': name, 'address': address, 'cityId': cityId, 'latitude': latitude, 'longitude': longitude};
    if (id == null) await ApiClient.post('/api/clinics', body);
    else await ApiClient.put('/api/clinics/$id', body);
  }
  Future<void> delete(int id) => ApiClient.delete('/api/clinics/$id');
}

class CityProvider extends ChangeNotifier {
  Future<List<City>> list({String? name}) async {
    final res = await ApiClient.get('/api/cities', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => City.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, String? country}) async {
    final body = {'name': name, 'country': country};
    if (id == null) await ApiClient.post('/api/cities', body);
    else await ApiClient.put('/api/cities/$id', body);
  }
  Future<void> delete(int id) => ApiClient.delete('/api/cities/$id');
}

class DoctorProvider extends ChangeNotifier {
  Future<List<Doctor>> list({String? name, int? specializationId}) async {
    final res = await ApiClient.get('/api/doctors', query: {'name': name?.isEmpty == true ? null : name, 'specializationId': specializationId, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Doctor.fromJson(e)).toList();
  }
  Future<Doctor> create(Map<String, dynamic> body) async {
    final res = await ApiClient.post('/api/doctors', body);
    return Doctor.fromJson(res);
  }
  Future<Doctor> update(int id, Map<String, dynamic> body) async {
    final res = await ApiClient.put('/api/doctors/$id', body);
    return Doctor.fromJson(res);
  }
  Future<void> delete(int id) => ApiClient.delete('/api/doctors/$id');

  /// Creates bookable slots inside the given local working windows (one per working day).
  Future<int> addWorkingHours({required int doctorId, required int slotMinutes, required List<DateTimeRange> windows}) async {
    final res = await ApiClient.post('/api/time-slots/generate', {
      'doctorId': doctorId,
      'slotMinutes': slotMinutes,
      'windows': windows.map((w) => {'startUtc': w.start.toUtc().toIso8601String(), 'endUtc': w.end.toUtc().toIso8601String()}).toList(),
    });
    return res['generated'] as int;
  }

  /// All slots of a doctor between [from] and [to] (local). The API caps a page at 100, so pages are fetched until exhausted.
  Future<List<TimeSlot>> slots(int doctorId, DateTime from, DateTime to) async {
    const pageSize = 100;
    final all = <TimeSlot>[];
    for (var page = 0;; page++) {
      final res = await ApiClient.get('/api/time-slots', query: {
        'doctorId': doctorId, 'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String(),
        'page': page, 'pageSize': pageSize,
      });
      final items = (res as List? ?? []).map((e) => TimeSlot.fromJson(e)).toList();
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
  }

  Future<void> deleteSlot(int id) => ApiClient.delete('/api/time-slots/$id');
}

class PatientProvider extends ChangeNotifier {
  Future<List<User>> list({String? search}) async {
    final res = await ApiClient.get('/api/users', query: {'role': 'patient', 'search': search?.isEmpty == true ? null : search, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => User.fromJson(e)).toList();
  }

  /// Null when the patient has no medical record yet.
  Future<MedicalRecord?> medicalRecord(int patientId) async {
    final res = await ApiClient.get('/api/medical-records/patient/$patientId');
    return res == null ? null : MedicalRecord.fromJson(res);
  }

  Future<PagedList<Appointment>> visits(int patientId, {int page = 0, int pageSize = 10}) async {
    final res = await ApiClient.get('/api/appointments', query: {'patientId': patientId, 'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }
}

class AppointmentProvider extends ChangeNotifier {
  Future<List<Appointment>> list({String? status, int? doctorId}) async {
    final res = await ApiClient.get('/api/appointments', query: {'status': status, 'doctorId': doctorId, 'pageSize': 200});
    return (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
  }
  Future<void> confirm(int id) => ApiClient.post('/api/appointments/$id/confirm');
  Future<void> complete(int id) => ApiClient.post('/api/appointments/$id/complete');
  Future<void> cancel(int id, {String? reason}) => ApiClient.post('/api/appointments/$id/cancel', {'reason': reason});
  Future<void> reschedule(int id, {required int newTimeSlotId, required String reason}) =>
      ApiClient.post('/api/appointments/$id/reschedule', {'newTimeSlotId': newTimeSlotId, 'reason': reason});

  /// Free future slots of [doctorId] on the given local calendar day.
  Future<List<TimeSlot>> freeSlots(int doctorId, DateTime day) async {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));
    final res = await ApiClient.get('/api/time-slots', query: {
      'doctorId': doctorId, 'onlyAvailable': true,
      'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String(),
    });
    return (res as List? ?? []).map((e) => TimeSlot.fromJson(e)).toList();
  }
}

class PaymentProvider extends ChangeNotifier {
  Map<String, dynamic> _filter({String? search, String? status, DateTime? from, DateTime? to}) => {
        'search': search?.trim().isEmpty == true ? null : search?.trim(),
        'status': status,
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
      };

  Future<PagedList<Payment>> list({String? search, String? status, DateTime? from, DateTime? to, int page = 0, int pageSize = 20}) async {
    final res = await ApiClient.get('/api/payments', query: {..._filter(search: search, status: status, from: from, to: to), 'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => Payment.fromJson(e)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }

  Future<PaymentSummary> summary({String? search, String? status, DateTime? from, DateTime? to}) async {
    final res = await ApiClient.get('/api/payments/summary', query: _filter(search: search, status: status, from: from, to: to));
    return PaymentSummary.fromJson(res);
  }

  Future<void> refund(String captureId, {String? reason}) async {
    await ApiClient.post('/api/payments/paypal/captures/$captureId/refund', {'reason': reason});
  }
}
