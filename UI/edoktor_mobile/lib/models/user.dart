class User {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String? phoneNumber;
  final String? gender;
  final String? bloodType;
  final String? allergies;
  final int? cityId;
  final String? cityName;
  /// Patient's own location (used by the recommender's distance factor); null when not set.
  final double? latitude, longitude;
  final int roleId;
  final String? role;
  /// Base64-encoded profile image (maps to the API's byte[] Image field). Null when unset.
  final String? image;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    this.phoneNumber,
    this.gender,
    this.bloodType,
    this.allergies,
    this.cityId,
    this.cityName,
    this.latitude,
    this.longitude,
    required this.roleId,
    this.role,
    this.image,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        username: json['username'] ?? '',
        email: json['email'] ?? '',
        phoneNumber: json['phoneNumber'],
        gender: json['gender'],
        bloodType: json['bloodType'],
        allergies: json['allergies'],
        cityId: json['cityId'],
        cityName: json['cityName'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        roleId: json['roleId'] ?? 0,
        role: json['role'],
        image: json['image'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'bloodType': bloodType,
        'allergies': allergies,
        'cityId': cityId,
        'cityName': cityName,
        'latitude': latitude,
        'longitude': longitude,
        'roleId': roleId,
        'role': role,
        'image': image,
      };
}
