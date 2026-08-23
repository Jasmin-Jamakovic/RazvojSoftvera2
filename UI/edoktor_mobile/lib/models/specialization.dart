class Specialization {
  final int id;
  final String name;
  final String? description;
  Specialization({required this.id, required this.name, this.description});
  factory Specialization.fromJson(Map<String, dynamic> j) =>
      Specialization(id: j['id'], name: j['name'] ?? '', description: j['description']);
}
