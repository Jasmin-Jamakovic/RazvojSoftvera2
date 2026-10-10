import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import 'auth_store.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  /// Invoked when the API returns 401 (expired/invalid token) so the app can
  /// clear the session and send the user back to login. Set in main().
  static void Function()? onUnauthorized;

  static Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{};
    if (AuthStore.token != null) h['Authorization'] = 'Bearer ${AuthStore.token}';
    if (jsonBody) h['Content-Type'] = 'application/json';
    return h;
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final qs = query?.entries
        .where((e) => e.value != null)
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}')
        .join('&');
    final q = (qs != null && qs.isNotEmpty) ? '?$qs' : '';
    return Uri.parse('${ApiConfig.baseUrl}$path$q');
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final r = await http.get(_uri(path, query), headers: _headers());
    return _decode(r);
  }

  static Future<dynamic> post(String path, [Object? body]) async {
    final r = await http.post(_uri(path), headers: _headers(jsonBody: true), body: body == null ? null : jsonEncode(body));
    return _decode(r);
  }

  static Future<dynamic> put(String path, Object? body) async {
    final r = await http.put(_uri(path), headers: _headers(jsonBody: true), body: jsonEncode(body));
    return _decode(r);
  }

  static Future<void> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers());
    _decode(r);
  }

  static dynamic _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(r.body);
    }
    if (r.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(401, 'Sesija je istekla. Prijavite se ponovo.');
    }
    String message = 'HTTP ${r.statusCode}';
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['errors'] is Map) {
        final errors = body['errors'] as Map;
        final lines = <String>[];
        errors.forEach((k, v) {
          if (v is List) lines.addAll(v.map((e) => e.toString()));
        });
        if (lines.isNotEmpty) message = lines.join('\n');
      }
    } catch (_) {}
    throw ApiException(r.statusCode, message);
  }
}
