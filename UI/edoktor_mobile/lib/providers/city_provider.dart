import 'package:flutter/foundation.dart';
import '../models/city.dart';
import '../services/api_client.dart';

class CityProvider extends ChangeNotifier {
  /// Every active city (id + name). The endpoint is public, so it also works on the registration
  /// screen, before the user has a token.
  Future<List<City>> list() async {
    final res = await ApiClient.get('/api/cities/lookup');
    return ((res as List?) ?? []).map((e) => City.fromJson(e)).toList();
  }
}
