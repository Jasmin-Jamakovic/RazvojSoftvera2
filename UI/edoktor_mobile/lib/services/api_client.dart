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

  /// [notifyUnauthorized] = false skips the global 401 handler (used by logout, which clears the session itself).
  static Future<dynamic> post(String path, [Object? body, bool notifyUnauthorized = true]) async {
    final r = await http.post(_uri(path), headers: _headers(jsonBody: true), body: body == null ? null : jsonEncode(body));
    return _decode(r, notifyUnauthorized: notifyUnauthorized);
  }

  static Future<dynamic> put(String path, Object? body) async {
    final r = await http.put(_uri(path), headers: _headers(jsonBody: true), body: jsonEncode(body));
    return _decode(r);
  }

  static Future<void> delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers());
    _decode(r);
  }

  static dynamic _decode(http.Response r, {bool notifyUnauthorized = true}) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(r.body);
    }
    if (r.statusCode == 401) {
      if (notifyUnauthorized) onUnauthorized?.call();
      throw ApiException(401, 'Sesija je istekla. Prijavite se ponovo.');
    }
    throw ApiException(r.statusCode, _errorMessage(r));
  }

  /// Extracts a readable message from an error body: the ExceptionFilter / validation shape
  /// `{errors: {key: [msg]}}`, a `message`/`title`/`detail` field, or a plain-string body.
  static String _errorMessage(http.Response r) {
    final fallback = 'HTTP ${r.statusCode}';
    final raw = r.body.trim();
    if (raw.isEmpty) return fallback;
    dynamic body;
    try {
      body = jsonDecode(raw);
    } on FormatException {
      // Not JSON: a plain-text message (but not an HTML error page).
      return raw.startsWith('<') ? fallback : raw;
    }
    if (body is String && body.trim().isNotEmpty) return body.trim();
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map) {
        final lines = <String>[];
        errors.forEach((k, v) {
          if (v is List) {
            lines.addAll(v.map((e) => e.toString()));
          } else if (v != null) {
            lines.add(v.toString());
          }
        });
        if (lines.isNotEmpty) return lines.join('\n');
      }
      for (final key in ['message', 'title', 'detail']) {
        final v = body[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    }
    return fallback;
  }
}
