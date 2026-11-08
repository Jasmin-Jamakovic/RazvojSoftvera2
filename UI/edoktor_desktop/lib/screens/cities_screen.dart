import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

class CitiesScreen extends StatefulWidget {
  const CitiesScreen({super.key});
  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  late Future<List<City>> _f;
  final _search = TextEditingController();

  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  void _refresh() { setState(() { _f = context.read<CityProvider>().list(name: _search.text); }); }

  Future<void> _edit([City? c]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: c?.name ?? '');
    final provider = context.read<CityProvider>();
    // Every city belongs to a country, so the form needs the country list first.
    final List<Country> countries;
    try {
      countries = await context.read<CountryProvider>().list();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    if (countries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prvo dodajte državu.')));
      return;
    }
    int? countryId = countries.any((x) => x.id == c?.countryId) ? c!.countryId : null;
    var saving = false;
    String? error;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(c == null ? 'Novi grad' : 'Uredi grad')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: saving ? null : () => Navigator.pop(ctx, false)),
      ]),
      content: SizedBox(width: 400, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Naziv'),
          validator: (v) => Validators.requiredMax(v, 100, 'Naziv')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: countryId,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Država'),
          items: countries.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
          onChanged: saving ? null : (v) => setLocal(() => countryId = v),
          validator: (v) => v == null ? 'Država je obavezno polje.' : null),
        if (error != null)
          Padding(padding: const EdgeInsets.only(top: 12),
            child: Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: Colors.red)))),
      ]))),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Odustani')),
        FilledButton(
          onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            setLocal(() { saving = true; error = null; });
            try {
              await provider.upsert(id: c?.id, name: name.text.trim(), countryId: countryId!);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) setLocal(() { saving = false; error = '$e'; });
            }
          },
          child: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sačuvaj')),
      ],
    )));
    if (ok != true || !mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c == null ? 'Grad je uspješno dodan.' : 'Grad je uspješno ažuriran.')));
  }

  Future<void> _confirmDelete(City x) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Brisanje grada'),
      content: Text('Jeste li sigurni da želite obrisati "${x.name}"? Ova akcija je nepovratna.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
      ],
    ));
    if (ok != true || !mounted) return;
    try {
      await context.read<CityProvider>().delete(x.id);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grad je uspješno obrisan.')));
    }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Gradovi', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const Spacer(),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Dodaj')),
      ]),
      const SizedBox(height: 16),
      SizedBox(width: 360, child: TextField(
        controller: _search,
        decoration: InputDecoration(
          hintText: 'Pretraga po nazivu...',
          prefixIcon: const Icon(Icons.search),
          isDense: true, border: const OutlineInputBorder(),
          suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _refresh(); }),
        ),
        onChanged: (_) => _refresh(),
      )),
      const SizedBox(height: 16),
      Expanded(child: Card(child: FutureBuilder<List<City>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Nema gradova za prikaz.'));
        return ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final x = list[i];
          return ListTile(
            leading: const Icon(Icons.location_city, color: Color(0xFF2E7D32)),
            title: Text(x.name),
            subtitle: Text(x.countryName ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _edit(x)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(x)),
            ]),
          );
        });
      }))),
    ]));
  }
}
