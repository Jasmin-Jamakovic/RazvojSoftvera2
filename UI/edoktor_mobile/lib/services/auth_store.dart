import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthStore {
  static const _tokenKey = 'edoktor.token';
  static const _userKey = 'edoktor.user';

  static String? _token;
  static User? _user;

  static String? get token => _token;
  static User? get user => _user;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_tokenKey);
    final u = p.getString(_userKey);
    if (u != null) {
      _user = User.fromJson(jsonDecode(u));
    }
  }

  static Future<void> save(String token, User user) async {
    _token = token;
    _user = user;
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey, token);
    await p.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_tokenKey);
    await p.remove(_userKey);
  }
}
