import 'package:flutter/material.dart';
import '../services/auth_store.dart';
import '../utils/api_config.dart';

// Shows an entity image loaded from a separate photo endpoint (so list responses carry no blobs),
// authenticated with the current admin token, falling back to initials when there is no image.
class EntityAvatar extends StatelessWidget {
  final String? path; // e.g. /api/doctors/5/photo — null means no photo
  final String initials;
  final double radius;
  const EntityAvatar({super.key, required this.path, required this.initials, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(radius: radius, child: Text(initials));
    if (path == null) return fallback;
    final size = radius * 2;
    return ClipOval(
      child: Image.network(
        '${ApiConfig.baseUrl}$path',
        headers: {'Authorization': 'Bearer ${AuthStore.token}'},
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
