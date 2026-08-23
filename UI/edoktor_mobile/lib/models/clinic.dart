class Clinic {
  final int id;
  final String name;
  final String? address;
  final int? cityId;
  final String? cityName;
  Clinic({required this.id, required this.name, this.address, this.cityId, this.cityName});
  factory Clinic.fromJson(Map<String, dynamic> j) =>
      Clinic(id: j['id'], name: j['name'] ?? '', address: j['address'], cityId: j['cityId'], cityName: j['cityName']);
}
