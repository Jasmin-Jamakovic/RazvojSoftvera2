class City {
  final int id;
  final String name;
  City({required this.id, required this.name});
  factory City.fromJson(Map<String, dynamic> j) => City(id: j['id'], name: j['name'] ?? '');
}
