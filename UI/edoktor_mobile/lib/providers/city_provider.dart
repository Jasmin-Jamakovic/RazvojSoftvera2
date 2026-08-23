import 'package:flutter/foundation.dart';
import '../models/city.dart';
import '../services/api_client.dart';

class CityProvider extends ChangeNotifier {
  Future<List<City>> list() async {
    final res = await ApiClient.get('/api/cities', query: {'pageSize': 100});
    return ((res['items'] as List?) ?? []).map((e) => City.fromJson(e)).toList();
  }
}
