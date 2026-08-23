import 'package:flutter/foundation.dart';
import '../models/dashboard.dart';
import '../models/entities.dart';
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
  Future<int> generateSlots({required int doctorId, required DateTime from, required DateTime to}) async {
    final res = await ApiClient.post('/api/time-slots/generate', {'doctorId': doctorId, 'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()});
    return res['generated'] as int;
  }
}

class PatientProvider extends ChangeNotifier {
  Future<List<User>> list({String? search}) async {
    final res = await ApiClient.get('/api/users', query: {'role': 'patient', 'search': search?.isEmpty == true ? null : search, 'pageSize': 100});
    return (res['items'] as List? ?? []).map((e) => User.fromJson(e)).toList();
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
}

class PaymentProvider extends ChangeNotifier {
  Future<void> refund(String captureId, {String? reason}) async {
    await ApiClient.post('/api/payments/paypal/captures/$captureId/refund', {'reason': reason});
  }
}
