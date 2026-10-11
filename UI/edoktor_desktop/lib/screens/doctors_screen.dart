import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';
import '../widgets/entity_avatar.dart';
import 'working_hours_screen.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});
  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  static const _maxPhotoBytes = 5 * 1024 * 1024;
  late Future<List<Doctor>> _f;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _refresh() { setState(() { _f = context.read<DoctorProvider>().list(name: _search.text); }); }

  Future<void> _edit([Doctor? d]) async {
    final (clinics, specs) = await (context.read<ClinicProvider>().list(), context.read<SpecializationProvider>().list()).wait;
    if (!mounted) return;
    // A doctor needs a clinic and at least one specialization, so the form only opens once both exist.
    final missing = [if (clinics.isEmpty) 'kliniku (meni "Klinike")', if (specs.isEmpty) 'specijalizaciju (meni "Specijalizacije")'];
    if (missing.isNotEmpty) {
      await showDialog<void>(context: context, builder: (c) => AlertDialog(
        title: const Text('Nedostaju podaci'),
        content: Text('Prije dodavanja ljekara dodajte barem jednu ${missing.join(' i jednu ')}.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('U redu'))],
      ));
      return;
    }
    final formKey = GlobalKey<FormState>();
    final firstName = TextEditingController(text: d?.firstName ?? '');
    final lastName = TextEditingController(text: d?.lastName ?? '');
    final email = TextEditingController();
    final username = TextEditingController();
    final phone = TextEditingController(text: d?.phoneNumber ?? '');
    final bio = TextEditingController(text: d?.bio ?? '');
    final years = TextEditingController(text: '${d?.yearsExperience ?? 0}');
    final price = TextEditingController(text: d == null ? '50' : d.consultationPrice.toStringAsFixed(2));
    int? clinicId = d?.clinic?.id ?? clinics.first.id;
    final selectedSpecs = <int>{...?d?.specializations.map((s) => s.id)};
    Uint8List? photo;
    String? photoError;

    Future<void> pickPhoto(void Function(void Function()) set) async {
      final files = await FilePicker.pickFiles(type: FileType.image, dialogTitle: 'Fotografija ljekara');
      if (files.isEmpty) return;
      final bytes = await files.first.readAsBytes();
      set(() {
        if (bytes.length > _maxPhotoBytes) {
          photoError = 'Slika je veća od 5 MB. Odaberite manju sliku.';
        } else {
          photo = bytes;
          photoError = null;
        }
      });
    }

    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(d == null ? 'Novi ljekar' : 'Uredi ljekara')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
      ]),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          ClipOval(child: SizedBox(width: 72, height: 72, child: photo != null
              ? Image.memory(photo!, fit: BoxFit.cover)
              : EntityAvatar(path: d != null && d.hasPhoto ? '/api/doctors/${d.id}/photo' : null, initials: _initials(firstName.text, lastName.text), radius: 36))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton.icon(onPressed: () => pickPhoto(set), icon: const Icon(Icons.photo_camera_outlined), label: Text(photo == null && !(d?.hasPhoto ?? false) ? 'Dodaj fotografiju' : 'Promijeni fotografiju')),
            const SizedBox(height: 4),
            Text(photoError ?? 'PNG, JPEG, GIF ili WEBP, najviše 5 MB.', style: TextStyle(fontSize: 12, color: photoError == null ? Colors.black54 : Colors.red)),
          ])),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: firstName, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Ime'),
          validator: (v) => Validators.requiredMax(v, 50, 'Ime')),
        const SizedBox(height: 8),
        TextFormField(controller: lastName, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Prezime'),
          validator: (v) => Validators.requiredMax(v, 50, 'Prezime')),
        if (d == null) ...[
          const SizedBox(height: 8),
          TextFormField(controller: email, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Email', helperText: 'Na ovu adresu se šalje privremena lozinka.'),
            validator: (v) => Validators.email(v)),
          const SizedBox(height: 8),
          TextFormField(controller: username, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Korisničko ime (opciono)', helperText: 'Ako ostane prazno: dr.ime.prezime'),
            validator: (v) => (v == null || v.trim().isEmpty) ? null
                : RegExp(r'^[a-zA-Z0-9._-]{3,50}$').hasMatch(v.trim()) ? null
                : 'Korisničko ime smije sadržavati slova, brojeve i . _ - (3–50 znakova).'),
        ] else if (d.email != null) ...[
          const SizedBox(height: 8),
          InputDecorator(decoration: const InputDecoration(labelText: 'Email (ne mijenja se)'), child: Text(d.email!)),
        ],
        const SizedBox(height: 8),
        TextFormField(controller: phone, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Telefon (opciono)'), keyboardType: TextInputType.phone,
          validator: (v) => Validators.phone(v, optional: true)),
        const SizedBox(height: 8),
        TextFormField(controller: years, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Godine iskustva'), keyboardType: TextInputType.number,
          validator: (v) => Validators.intRange(v, min: 0, max: 70, field: 'Godine iskustva')),
        const SizedBox(height: 8),
        TextFormField(controller: price, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Cijena konsultacije (EUR)', helperText: 'npr. 50 ili 49,99'), keyboardType: TextInputType.number,
          validator: (v) => Validators.positiveDecimal(v, field: 'Cijena', max: 10000)),
        const SizedBox(height: 8),
        TextFormField(controller: bio, maxLines: 4, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Biografija'),
          validator: (v) => Validators.maxLen(v, 1000, 'Biografija')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: clinicId,
          items: clinics.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          onChanged: (v) => set(() => clinicId = v),
          validator: (v) => v == null ? 'Odaberite kliniku.' : null,
          decoration: const InputDecoration(labelText: 'Klinika')),
        const SizedBox(height: 12),
        const Align(alignment: Alignment.centerLeft, child: Text('Specijalizacije:')),
        Wrap(spacing: 6, runSpacing: 6, children: specs.map((s) => FilterChip(
          label: Text(s.name),
          selected: selectedSpecs.contains(s.id),
          onSelected: (v) => set(() => v ? selectedSpecs.add(s.id) : selectedSpecs.remove(s.id)),
        )).toList()),
        if (selectedSpecs.isEmpty)
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 6),
            child: Text('Odaberite barem jednu specijalizaciju.', style: TextStyle(color: Colors.red, fontSize: 12)))),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(onPressed: () {
          final formValid = formKey.currentState!.validate();
          set(() {});
          if (formValid && selectedSpecs.isNotEmpty) Navigator.pop(c, true);
        }, child: const Text('Sačuvaj')),
      ],
    )));

    if (ok != true || !mounted) return;

    final body = {
      'firstName': firstName.text.trim(),
      'lastName': lastName.text.trim(),
      'username': username.text.trim().isEmpty ? null : username.text.trim(),
      'email': d == null ? email.text.trim() : null,
      'phoneNumber': phone.text.trim().isEmpty ? null : phone.text.trim(),
      'clinicId': clinicId,
      'bio': bio.text.trim(),
      'yearsExperience': int.parse(years.text.trim()),
      // The form accepts a decimal comma (49,99) as well as a point.
      'consultationPrice': double.parse(price.text.trim().replaceAll(',', '.')),
      'profilePhoto': photo == null ? null : base64Encode(photo!),
      'specializationIds': selectedSpecs.toList(),
    };
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (d == null) {
        await context.read<DoctorProvider>().create(body);
      } else {
        await context.read<DoctorProvider>().update(d.id, body);
      }
      _refresh();
      messenger.showSnackBar(SnackBar(content: Text(d == null
          ? 'Ljekar je uspješno dodan. Privremena lozinka je poslana na ${email.text.trim()}.'
          : 'Podaci ljekara su uspješno ažurirani.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _confirmDelete(Doctor d) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Brisanje ljekara'),
      content: Text('Jeste li sigurni da želite obrisati ljekara "${d.fullName}"? Ova akcija je nepovratna.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
      ],
    ));
    if (ok != true) return;
    try { await context.read<DoctorProvider>().delete(d.id); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  String _initials(String f, String l) => ((f.isNotEmpty ? f[0] : '') + (l.isNotEmpty ? l[0] : '')).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Ljekari', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(width: 24),
        SizedBox(width: 260, child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Pretraga po imenu',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _refresh(); }),
            isDense: true, border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _refresh(),
        )),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.search), label: const Text('Traži')),
        const Spacer(),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Dodaj ljekara')),
      ]),
      const SizedBox(height: 16),
      Expanded(child: Card(child: FutureBuilder<List<Doctor>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Nema ljekara.'));
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [
          DataColumn(label: Text('Foto')), DataColumn(label: Text('Ime')), DataColumn(label: Text('Specijalizacije')), DataColumn(label: Text('Klinika')), DataColumn(label: Text('Cijena')), DataColumn(label: Text('Ocjena')), DataColumn(label: Text('Akcije')),
        ], rows: list.map((d) => DataRow(cells: [
          DataCell(EntityAvatar(path: d.hasPhoto ? '/api/doctors/${d.id}/photo' : null, initials: _initials(d.firstName, d.lastName))),
          DataCell(Text(d.fullName)),
          DataCell(Text(d.specializations.map((s) => s.name).join(', '))),
          DataCell(Text(d.clinic?.name ?? '')),
          DataCell(Text('${d.consultationPrice.toStringAsFixed(0)} €')),
          DataCell(Text('${d.averageRating.toStringAsFixed(1)} (${d.reviewCount})')),
          DataCell(Row(children: [
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Uredi ljekara', onPressed: () => _edit(d)),
            IconButton(icon: const Icon(Icons.event_available), tooltip: 'Radno vrijeme i termini',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkingHoursScreen(doctor: d)))),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Obriši ljekara', onPressed: () => _confirmDelete(d)),
          ])),
        ])).toList()));
      }))),
    ]));
  }
}
