import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/city.dart';
import '../providers/auth_provider.dart';
import '../providers/city_provider.dart';
import '../utils/validators.dart';
import 'shell_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final phoneNumber = TextEditingController();
  final _birthDateText = TextEditingController();
  DateTime? _birthDate;
  String? gender;
  List<City> _cities = [];
  int? _cityId;
  bool _busy = false; String? _error;

  @override
  void initState() {
    super.initState();
    context.read<CityProvider>().list().then((c) { if (mounted) setState(() => _cities = c); });
  }

  @override
  void dispose() {
    for (final c in [firstName, lastName, username, email, password, confirmPassword, phoneNumber, _birthDateText]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Datum rođenja',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d == null) return;
    setState(() {
      _birthDate = d;
      _birthDateText.text = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}.';
    });
  }

  String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await context.read<AuthProvider>().register({
        'firstName': firstName.text, 'lastName': lastName.text,
        'username': username.text, 'email': email.text, 'password': password.text,
        'phoneNumber': phoneNumber.text, 'gender': gender, 'cityId': _cityId,
        'dateOfBirth': _isoDate(_birthDate!),
      });
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registracija')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey, autovalidateMode: AutovalidateMode.onUserInteraction, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: firstName, decoration: const InputDecoration(labelText: 'Ime', border: OutlineInputBorder()), validator: (v) => Validators.requiredMax(v, 50, 'Ime')), const SizedBox(height: 12),
          TextFormField(controller: lastName, decoration: const InputDecoration(labelText: 'Prezime', border: OutlineInputBorder()), validator: (v) => Validators.requiredMax(v, 50, 'Prezime')), const SizedBox(height: 12),
          TextFormField(controller: username, decoration: const InputDecoration(labelText: 'Korisničko ime', border: OutlineInputBorder()), validator: (v) => Validators.requiredMax(v, 50, 'Korisničko ime')), const SizedBox(height: 12),
          TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => Validators.email(v)), const SizedBox(height: 12),
          TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Lozinka', border: OutlineInputBorder()), validator: (v) => Validators.password(v)), const SizedBox(height: 12),
          TextFormField(controller: confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Potvrdi lozinku', border: OutlineInputBorder()), validator: (v) => Validators.confirm(v, password.text)), const SizedBox(height: 12),
          TextFormField(
            controller: _birthDateText,
            readOnly: true,
            onTap: _pickBirthDate,
            decoration: const InputDecoration(labelText: 'Datum rođenja', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today_outlined)),
            validator: (_) => _birthDate == null ? 'Odaberite datum rođenja.' : null), const SizedBox(height: 12),
          TextFormField(controller: phoneNumber, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()), validator: (v) => Validators.phone(v)), const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(labelText: 'Spol', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'M', child: Text('Muški')), DropdownMenuItem(value: 'F', child: Text('Ženski'))],
            validator: (v) => v == null ? 'Odaberite spol.' : null,
            onChanged: (v) => setState(() => gender = v)), const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey('city-${_cities.length}'),
            initialValue: _cities.any((c) => c.id == _cityId) ? _cityId : null,
            decoration: const InputDecoration(labelText: 'Grad', border: OutlineInputBorder()),
            items: _cities.map((ci) => DropdownMenuItem(value: ci.id, child: Text(ci.name))).toList(),
            validator: (v) => v == null ? 'Odaberite grad.' : null,
            onChanged: (v) => setState(() => _cityId = v)),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.red))],
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_busy ? '...' : 'Registruj se'))),
        ])),
      ),
    );
  }
}
