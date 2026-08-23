class ApiConfig {
  // Override with: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5190
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5190');
}
