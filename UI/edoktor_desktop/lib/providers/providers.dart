import 'dart:convert';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart';
import '../models/dashboard.dart';
import '../models/entities.dart';
import '../models/medical_record.dart';
import '../models/notification_item.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';

class AuthProvider extends ChangeNotifier {
  User? get user => AuthStore.user;

  Future<void> login(String username, String password) async {
    final res = await ApiClient.post('/api/auth/login', {'username': username, 'password': password});
    await AuthStore.save(res['token'], User.fromJson(res['user']));
    notifyListeners();
  }

  /// Ends the session on the server too (the token is revoked), then clears it locally.
  /// A failed server call (e.g. API unreachable) must not keep the admin logged in locally.
  Future<void> logout() async {
    try {
      await ApiClient.post('/api/auth/logout');
    } catch (e) {
      debugPrint('Server logout failed, clearing the local session anyway: $e');
    }
    await AuthStore.clear();
    notifyListeners();
  }
}

class DashboardProvider extends ChangeNotifier {
  Future<DashboardStats> stats() async {
    final res = await ApiClient.get('/api/dashboard/stats');
    return DashboardStats.fromJson(res);
  }

  /// [from] inclusive, [to] exclusive (local dates).
  Future<DoctorReport> doctorReport({required DateTime from, required DateTime to, int? specializationId}) async {
    final res = await ApiClient.get('/api/dashboard/doctor-report', query: {
      'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String(), 'specializationId': specializationId,
    });
    return DoctorReport.fromJson(res);
  }
}

class SpecializationProvider extends ChangeNotifier {
  Future<List<Specialization>> list({String? name}) async {
    final res = await ApiClient.get('/api/specializations', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, String? description}) async {
    final body = {'name': name, 'description': description};
    if (id == null) {
      await ApiClient.post('/api/specializations', body);
    } else {
      await ApiClient.put('/api/specializations/$id', body);
    }
  }
  Future<void> delete(int id) => ApiClient.delete('/api/specializations/$id');
}

class ClinicProvider extends ChangeNotifier {
  Future<List<Clinic>> list({String? name}) async {
    final res = await ApiClient.get('/api/clinics', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Clinic.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, required String address, required int cityId, double? latitude, double? longitude}) async {
    final body = {'name': name, 'address': address, 'cityId': cityId, 'latitude': latitude, 'longitude': longitude};
    if (id == null) {
      await ApiClient.post('/api/clinics', body);
    } else {
      await ApiClient.put('/api/clinics/$id', body);
    }
  }
  Future<void> delete(int id) => ApiClient.delete('/api/clinics/$id');

  /// Address -> coordinate candidates (OpenStreetMap lookup done by the API).
  Future<List<GeocodingResult>> geocode(String address, {int? cityId}) async {
    final res = await ApiClient.get('/api/geocoding', query: {'address': address.trim(), 'cityId': cityId});
    return (res as List? ?? []).map((e) => GeocodingResult.fromJson(e)).toList();
  }
}

class CountryProvider extends ChangeNotifier {
  Future<List<Country>> list({String? name}) async {
    final res = await ApiClient.get('/api/countries', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => Country.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name}) async {
    final body = {'name': name};
    if (id == null) {
      await ApiClient.post('/api/countries', body);
    } else {
      await ApiClient.put('/api/countries/$id', body);
    }
  }
  Future<void> delete(int id) => ApiClient.delete('/api/countries/$id');
}

class CityProvider extends ChangeNotifier {
  Future<List<City>> list({String? name, int? countryId}) async {
    final res = await ApiClient.get('/api/cities', query: {'name': name?.isEmpty == true ? null : name, 'countryId': countryId, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => City.fromJson(e)).toList();
  }
  Future<void> upsert({int? id, required String name, required int countryId}) async {
    final body = {'name': name, 'countryId': countryId};
    if (id == null) {
      await ApiClient.post('/api/cities', body);
    } else {
      await ApiClient.put('/api/cities/$id', body);
    }
  }
  Future<void> delete(int id) => ApiClient.delete('/api/cities/$id');
}

class DoctorProvider extends ChangeNotifier {
  Future<List<Doctor>> list({String? name}) async {
    final res = await ApiClient.get('/api/doctors', query: {'name': name?.isEmpty == true ? null : name, 'pageSize': 100});
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

  Future<PagedList<Appointment>> visits(int patientId, {int page = 0, int pageSize = 10}) async {
    final res = await ApiClient.get('/api/appointments', query: {'patientId': patientId, 'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }
}

/// A patient's electronic medical record: header, paged visits / prescriptions / lab results and their CRUD.
class MedicalRecordProvider extends ChangeNotifier {
  static const _base = '/api/medical-records';

  /// Null when the patient has no medical record yet.
  Future<MedicalRecordHeader?> header(int patientId) async {
    final res = await ApiClient.get('$_base/patient/$patientId');
    return res == null ? null : MedicalRecordHeader.fromJson(res);
  }

  Future<PagedList<T>> _paged<T>(String path, T Function(Map<String, dynamic>) map, int page, int pageSize, String? search) async {
    final res = await ApiClient.get(path, query: {
      'page': page, 'pageSize': pageSize, 'search': search?.trim().isEmpty == true ? null : search?.trim(),
    });
    final items = (res['items'] as List? ?? []).map((e) => map(e as Map<String, dynamic>)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }

  Future<PagedList<RecordEntry>> entries(int patientId, {int page = 0, int pageSize = 5, String? search}) =>
      _paged('$_base/patient/$patientId/entries', RecordEntry.fromJson, page, pageSize, search);
  Future<PagedList<Prescription>> prescriptions(int patientId, {int page = 0, int pageSize = 5, String? search}) =>
      _paged('$_base/patient/$patientId/prescriptions', Prescription.fromJson, page, pageSize, search);
  Future<PagedList<LabResult>> labResults(int patientId, {int page = 0, int pageSize = 10, String? search}) =>
      _paged('$_base/patient/$patientId/lab-results', LabResult.fromJson, page, pageSize, search);

  /// Ids of the appointments that already have a visit written into the record.
  Future<Set<int>> entryAppointmentIds(int patientId) async {
    const pageSize = 100;
    final ids = <int>{};
    for (var page = 0;; page++) {
      final p = await entries(patientId, page: page, pageSize: pageSize);
      ids.addAll(p.items.map((e) => e.appointmentId));
      if (p.items.length < pageSize) break;
    }
    return ids;
  }

  Map<String, dynamic> _entryBody(int appointmentId, String diagnosis, String? therapy, String? notes) =>
      {'appointmentId': appointmentId, 'diagnosis': diagnosis, 'therapy': therapy, 'notes': notes};
  Future<void> addEntry({required int appointmentId, required String diagnosis, String? therapy, String? notes}) =>
      ApiClient.post('$_base/entries', _entryBody(appointmentId, diagnosis, therapy, notes));
  Future<void> updateEntry(int id, {required int appointmentId, required String diagnosis, String? therapy, String? notes}) =>
      ApiClient.put('$_base/entries/$id', _entryBody(appointmentId, diagnosis, therapy, notes));
  Future<void> deleteEntry(int id) => ApiClient.delete('$_base/entries/$id');

  Future<void> addPrescription({required int entryId, required List<PrescriptionItem> items}) =>
      ApiClient.post('$_base/prescriptions', {'medicalRecordEntryId': entryId, 'items': items.map((i) => i.toJson()).toList()});
  Future<void> updatePrescription(int id, {required int entryId, required List<PrescriptionItem> items}) =>
      ApiClient.put('$_base/prescriptions/$id', {'medicalRecordEntryId': entryId, 'items': items.map((i) => i.toJson()).toList()});
  Future<void> deletePrescription(int id) => ApiClient.delete('$_base/prescriptions/$id');

  Future<void> addLabResult({required int patientId, required String title, String? notes}) =>
      ApiClient.post('$_base/lab-results', {'patientId': patientId, 'title': title, 'notes': notes});
  Future<void> updateLabResult(int id, {required int patientId, required String title, String? notes}) =>
      ApiClient.put('$_base/lab-results/$id', {'patientId': patientId, 'title': title, 'notes': notes});
  Future<void> deleteLabResult(int id) => ApiClient.delete('$_base/lab-results/$id');
}

class AppointmentProvider extends ChangeNotifier {
  /// One page of appointments (for a doctor the API returns only their own).
  Future<PagedList<Appointment>> list({String? status, DateTime? from, DateTime? to, int page = 0, int pageSize = 20}) async {
    final res = await ApiClient.get('/api/appointments', query: {
      'status': status, 'from': from?.toUtc().toIso8601String(), 'to': to?.toUtc().toIso8601String(),
      'page': page, 'pageSize': pageSize,
    });
    final items = (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }

  /// Every appointment with [patientId] (for a doctor: only the ones with that doctor).
  Future<List<Appointment>> forPatient(int patientId) async {
    const pageSize = 100;
    final all = <Appointment>[];
    for (var page = 0;; page++) {
      final res = await ApiClient.get('/api/appointments', query: {'patientId': patientId, 'page': page, 'pageSize': pageSize});
      final items = (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
  }

  /// Consultation chat: newest first, so page 0 is the latest part of the conversation.
  Future<PagedList<ConsultationMessage>> messages(int appointmentId, {int page = 0, int pageSize = 30}) async {
    final res = await ApiClient.get('/api/video-calls/$appointmentId/messages', query: {'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => ConsultationMessage.fromJson(e)).toList();
    return PagedList(items, res['totalCount'] ?? items.length);
  }

  Future<ConsultationMessage> sendMessage(int appointmentId, {String? text, Uint8List? image}) async {
    final res = await ApiClient.post('/api/video-calls/$appointmentId/messages', {
      'text': text, if (image != null) 'image': base64Encode(image),
    });
    return ConsultationMessage.fromJson(res);
  }

  String messageImagePath(int appointmentId, int messageId) => '/api/video-calls/$appointmentId/messages/$messageId/image';

  /// Every appointment matching the filters, fetched page by page (the API caps a page at 100).
  Future<List<Appointment>> listAll({String? status, DateTime? from, DateTime? to}) async {
    const pageSize = 100;
    final all = <Appointment>[];
    for (var page = 0;; page++) {
      final res = await ApiClient.get('/api/appointments', query: {
        'status': status, 'from': from?.toUtc().toIso8601String(), 'to': to?.toUtc().toIso8601String(),
        'page': page, 'pageSize': pageSize,
      });
      final items = (res['items'] as List? ?? []).map((e) => Appointment.fromJson(e)).toList();
      all.addAll(items);
      if (items.length < pageSize) break;
    }
    return all;
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
