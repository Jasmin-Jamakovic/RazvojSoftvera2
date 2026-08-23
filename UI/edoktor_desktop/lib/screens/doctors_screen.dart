import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';
import '../widgets/entity_avatar.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});
  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late Future<List<Doctor>> _f;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _refresh() { setState(() { _f = context.read<DoctorProvider>().list(name: _search.text); }); }

  Future<void> _edit([Doctor? d]) async {
    final clinics = await context.read<ClinicProvider>().list();
    final specs = await context.read<SpecializationProvider>().list();
    final formKey = GlobalKey<FormState>();
    final firstName = TextEditingController(text: d?.firstName ?? '');
    final lastName = TextEditingController(text: d?.lastName ?? '');
    final email = TextEditingController();
    final username = TextEditingController();
    final bio = TextEditingController(text: d?.bio ?? '');
    final years = TextEditingController(text: '${d?.yearsExperience ?? 0}');
    final price = TextEditingController(text: '${d?.consultationPrice ?? 50}');
    int? clinicId = d?.clinic?.id ?? (clinics.isNotEmpty ? clinics.first.id : null);
    final selectedSpecs = <int>{...?d?.specializations.map((s) => s.id)};

    if (!mounted) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, set) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(d == null ? 'Novi ljekar' : 'Uredi ljekara')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
      ]),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: firstName, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Ime'),
          validator: (v) => Validators.requiredMax(v, 50, 'Ime')),
        const SizedBox(height: 8),
        TextFormField(controller: lastName, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Prezime'),
          validator: (v) => Validators.requiredMax(v, 50, 'Prezime')),
        if (d == null) ...[
          const SizedBox(height: 8),
          TextFormField(controller: username, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Username (opciono)'),
            validator: (v) => Validators.maxLen(v, 50, 'Username')),
          const SizedBox(height: 8),
          TextFormField(controller: email, autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: const InputDecoration(labelText: 'Email (opciono)'),
            validator: (v) => Validators.email(v, optional: true)),
        ],
        const SizedBox(height: 8),
        TextFormField(controller: years, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Godine iskustva'), keyboardType: TextInputType.number,
          validator: (v) => Validators.intRange(v, min: 0, max: 70, field: 'Godine iskustva')),
        const SizedBox(height: 8),
        TextFormField(controller: price, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Cijena konsultacije (EUR)'), keyboardType: TextInputType.number,
          validator: (v) => Validators.positiveDecimal(v, field: 'Cijena', max: 100000)),
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
          onSelected: (v) { set(() { if (v) selectedSpecs.add(s.id); else selectedSpecs.remove(s.id); }); },
        )).toList()),
        if (selectedSpecs.isEmpty)
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 6),
            child: Text('Odaberite barem jednu specijalizaciju.', style: TextStyle(color: Colors.red, fontSize: 12)))),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(onPressed: () {
          final formValid = formKey.currentState!.validate();
          if (selectedSpecs.isEmpty) { set(() {}); }
          if (formValid && selectedSpecs.isNotEmpty) Navigator.pop(c, true);
        }, child: const Text('Sačuvaj')),
      ],
    )));

    if (ok != true) return;

    final body = {
      'firstName': firstName.text,
      'lastName': lastName.text,
      'username': username.text.isEmpty ? null : username.text,
      'email': email.text.isEmpty ? null : email.text,
      'clinicId': clinicId,
      'bio': bio.text,
      'yearsExperience': int.tryParse(years.text) ?? 0,
      'consultationPrice': double.tryParse(price.text) ?? 0,
      'specializationIds': selectedSpecs.toList(),
    };
    try {
      if (d == null) await context.read<DoctorProvider>().create(body);
      else await context.read<DoctorProvider>().update(d.id, body);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d == null ? 'Ljekar je uspješno dodan.' : 'Podaci ljekara su uspješno ažurirani.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
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

  Future<void> _generateSlots(Doctor d) async {
    final from = DateTime.now();
    final to = from.add(const Duration(days: 14));
    try {
      final n = await context.read<DoctorProvider>().generateSlots(doctorId: d.id, from: from, to: to);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generisano $n termina')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
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
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(d)),
            IconButton(icon: const Icon(Icons.event_available), tooltip: 'Generiši termine (14 dana)', onPressed: () => _generateSlots(d)),
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(d)),
          ])),
        ])).toList()));
      }))),
    ]));
  }
}
