import 'package:flutter/foundation.dart';
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

  Future<void> register(Map<String, dynamic> body) async {
    final res = await ApiClient.post('/api/auth/register', body);
    await AuthStore.save(res['token'], User.fromJson(res['user']));
    notifyListeners();
  }

  /// Re-fetches the current user from the API and persists it (keeping the existing token).
  Future<void> refreshMe() async {
    final res = await ApiClient.get('/api/auth/me');
    if (res != null && AuthStore.token != null) {
      await AuthStore.save(AuthStore.token!, User.fromJson(res));
      notifyListeners();
    }
  }

  /// Updates the current user's own profile, then refreshes the cached user.
  Future<void> updateProfile(Map<String, dynamic> body) async {
    final id = AuthStore.user!.id;
    await ApiClient.put('/api/users/$id', body);
    await refreshMe();
  }

  /// Changes the current user's password (old password is verified server-side).
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await ApiClient.post('/api/auth/change-password', {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  /// Requests a reset code by email. Returns the server's message (identical whether or not the account exists).
  Future<String> forgotPassword(String email) async {
    final res = await ApiClient.post('/api/auth/forgot-password', {'email': email.trim()});
    return (res?['message'] as String?) ?? 'Kod za resetovanje lozinke je poslan na vaš email.';
  }

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await ApiClient.post('/api/auth/reset-password', {'email': email.trim(), 'code': code.trim(), 'newPassword': newPassword});
  }

  Future<void> logout() async {
    await AuthStore.clear();
    notifyListeners();
  }
}
