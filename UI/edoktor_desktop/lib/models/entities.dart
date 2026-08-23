class Specialization {
  final int id; final String name; final String? description;
  Specialization({required this.id, required this.name, this.description});
  factory Specialization.fromJson(Map<String, dynamic> j) => Specialization(id: j['id'], name: j['name'] ?? '', description: j['description']);
}

class Clinic {
  final int id; final String name; final String? address; final int? cityId; final String? cityName;
  Clinic({required this.id, required this.name, this.address, this.cityId, this.cityName});
  factory Clinic.fromJson(Map<String, dynamic> j) => Clinic(id: j['id'], name: j['name'] ?? '', address: j['address'], cityId: j['cityId'], cityName: j['cityName']);
}

class City {
  final int id; final String name; final String? country;
  City({required this.id, required this.name, this.country});
  factory City.fromJson(Map<String, dynamic> j) => City(id: j['id'], name: j['name'] ?? '', country: j['country']);
}

class Doctor {
  final int id; final String firstName, lastName; final String? bio;
  final int yearsExperience; final double consultationPrice;
  final Clinic? clinic; final List<Specialization> specializations;
  final double averageRating; final int reviewCount; final bool hasPhoto;
  Doctor({required this.id, required this.firstName, required this.lastName, this.bio, required this.yearsExperience, required this.consultationPrice, this.clinic, required this.specializations, required this.averageRating, required this.reviewCount, this.hasPhoto = false});
  String get fullName => 'Dr. $firstName $lastName';
  factory Doctor.fromJson(Map<String, dynamic> j) => Doctor(
        id: j['id'], firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '',
        bio: j['bio'], yearsExperience: j['yearsExperience'] ?? 0, consultationPrice: (j['consultationPrice'] ?? 0).toDouble(),
        clinic: j['clinic'] == null ? null : Clinic.fromJson(j['clinic']),
        specializations: (j['specializations'] as List? ?? []).map((e) => Specialization.fromJson(e)).toList(),
        averageRating: (j['averageRating'] ?? 0).toDouble(), reviewCount: j['reviewCount'] ?? 0,
        hasPhoto: j['hasPhoto'] ?? false);
}

class Appointment {
  final int id; final int patientId, doctorId;
  final String? patientName, doctorName;
  final DateTime startUtc;
  final int type;
  final String status;
  final double price;
  final Map<String, dynamic>? payment;
  Appointment({required this.id, required this.patientId, this.patientName, required this.doctorId, this.doctorName, required this.startUtc, required this.type, required this.status, required this.price, this.payment});
  bool get isOnline => type == 1;
  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'], patientId: j['patientId'], patientName: j['patientName'],
        doctorId: j['doctorId'], doctorName: j['doctorName'],
        startUtc: DateTime.parse(j['startUtc']).toLocal(),
        type: j['type'] ?? 0, status: j['status'] ?? 'Pending',
        price: (j['price'] ?? 0).toDouble(),
        payment: j['payment'] as Map<String, dynamic>?);
}
