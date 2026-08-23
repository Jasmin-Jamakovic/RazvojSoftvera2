class User {
  final int id;
  final String firstName, lastName, username, email;
  final String? role;
  final int roleId;
  final bool hasImage;
  User({required this.id, required this.firstName, required this.lastName, required this.username, required this.email, this.role, required this.roleId, this.hasImage = false});
  String get fullName => '$firstName $lastName'.trim();
  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'], firstName: j['firstName'] ?? '', lastName: j['lastName'] ?? '',
        username: j['username'] ?? '', email: j['email'] ?? '', role: j['role'], roleId: j['roleId'] ?? 0,
        hasImage: j['hasImage'] ?? false);
  Map<String, dynamic> toJson() => {'id': id, 'firstName': firstName, 'lastName': lastName, 'username': username, 'email': email, 'role': role, 'roleId': roleId};
}
