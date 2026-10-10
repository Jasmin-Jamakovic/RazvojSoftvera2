class User {
  final int id;
  final String firstName, lastName, username, email;
  final String? role;
  final int roleId;
  final bool hasImage;
  final String? phoneNumber, gender, bloodType, allergies, cityName;
  final DateTime? dateOfBirth, createdAt;
  User({required this.id, required this.firstName, required this.lastName, required this.username, required this.email, this.role, required this.roleId, this.hasImage = false,
      this.phoneNumber, this.gender, this.bloodType, this.allergies, this.cityName, this.dateOfBirth, this.createdAt});
  String get fullName => '$firstName $lastName'.trim();
  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'], firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '',
        username: j['username'] ?? '', email: j['email'] ?? '', role: j['role'], roleId: j['roleId'] ?? 0,
        hasImage: j['hasImage'] ?? false,
        phoneNumber: j['phoneNumber'], gender: j['gender'], bloodType: j['bloodType'], allergies: j['allergies'], cityName: j['cityName'],
        dateOfBirth: j['dateOfBirth'] == null ? null : DateTime.parse(j['dateOfBirth']),
        createdAt: j['createdAt'] == null ? null : DateTime.parse(j['createdAt']).toLocal());
  Map<String, dynamic> toJson() => {'id': id, 'firstName': firstName, 'lastName': lastName, 'username': username, 'email': email, 'role': role, 'roleId': roleId};
}
