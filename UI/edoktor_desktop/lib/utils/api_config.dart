class ApiConfig {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:5190');

  /// Map tile server used by the clinic location picker.
  static const String mapTileUrl =
      String.fromEnvironment('MAP_TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
}
