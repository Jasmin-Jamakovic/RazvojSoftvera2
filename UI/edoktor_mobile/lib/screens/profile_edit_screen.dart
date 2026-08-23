import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/city.dart';
import '../providers/auth_provider.dart';
import '../providers/city_provider.dart';
import '../utils/validators.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _bloodType;
  late final TextEditingController _allergies;
  String? _gender;
  List<City> _cities = [];
  int? _cityId;

  Uint8List? _newImageBytes; // freshly picked image (not yet saved)
  String? _existingImageB64; // current image from server
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _firstName = TextEditingController(text: u.firstName);
    _lastName = TextEditingController(text: u.lastName);
    _email = TextEditingController(text: u.email);
    _phone = TextEditingController(text: u.phoneNumber ?? '');
    _bloodType = TextEditingController(text: u.bloodType ?? '');
    _allergies = TextEditingController(text: u.allergies ?? '');
    _gender = (u.gender == 'M' || u.gender == 'F') ? u.gender : null;
    _cityId = u.cityId;
    _existingImageB64 = u.image;
    context.read<CityProvider>().list().then((c) { if (mounted) setState(() => _cities = c); });
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone, _bloodType, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _newImageBytes = bytes);
  }

  ImageProvider? _avatarImage() {
    if (_newImageBytes != null) return MemoryImage(_newImageBytes!);
    if (_existingImageB64 != null && _existingImageB64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_existingImageB64!));
      } catch (_) {}
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'cityId': _cityId,
        'gender': _gender,
        'bloodType': _bloodType.text.trim().isEmpty ? null : _bloodType.text.trim(),
        'allergies': _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
      };
      // Only send the image when the user picked a new one.
      if (_newImageBytes != null) body['image'] = base64Encode(_newImageBytes!);

      await context.read<AuthProvider>().updateProfile(body);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil je uspješno ažuriran.')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _firstName.text.isNotEmpty ? _firstName.text[0].toUpperCase() : 'U';
    final avatar = _avatarImage();
    return Scaffold(
      appBar: AppBar(title: const Text('Uredi profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Stack(children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFE3F2FD),
                backgroundImage: avatar,
                child: avatar == null ? Text(initials, style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 36, fontWeight: FontWeight.bold)) : null,
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Material(
                  color: const Color(0xFF0D47A1), shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickImage,
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.camera_alt, color: Colors.white, size: 18)),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 8),
            Center(child: TextButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: const Text('Promijeni sliku'))),
            const SizedBox(height: 12),
            TextFormField(controller: _firstName, decoration: const InputDecoration(labelText: 'Ime', border: OutlineInputBorder()), validator: (v) => Validators.requiredMax(v, 50, 'Ime')),
            const SizedBox(height: 12),
            TextFormField(controller: _lastName, decoration: const InputDecoration(labelText: 'Prezime', border: OutlineInputBorder()), validator: (v) => Validators.requiredMax(v, 50, 'Prezime')),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => Validators.email(v)),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()), validator: (v) => Validators.phone(v)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('city-${_cities.length}'),
              initialValue: _cities.any((c) => c.id == _cityId) ? _cityId : null,
              decoration: const InputDecoration(labelText: 'Grad', border: OutlineInputBorder()),
              items: _cities.map((ci) => DropdownMenuItem(value: ci.id, child: Text(ci.name))).toList(),
              validator: (v) => v == null ? 'Odaberite grad.' : null,
              onChanged: (v) => setState(() => _cityId = v)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Spol', border: OutlineInputBorder()),
              items: const [DropdownMenuItem(value: 'M', child: Text('Muški')), DropdownMenuItem(value: 'F', child: Text('Ženski'))],
              validator: (v) => v == null ? 'Odaberite spol.' : null,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _bloodType, decoration: const InputDecoration(labelText: 'Krvna grupa (opciono)', border: OutlineInputBorder()), validator: (v) => Validators.maxLen(v, 5, 'Krvna grupa')),
            const SizedBox(height: 12),
            TextFormField(controller: _allergies, maxLines: 2, decoration: const InputDecoration(labelText: 'Alergije (opciono)', border: OutlineInputBorder()), validator: (v) => Validators.maxLen(v, 300, 'Alergije')),
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? 'Spremanje...' : 'Sačuvaj'))),
          ]),
        ),
      ),
    );
  }
}
