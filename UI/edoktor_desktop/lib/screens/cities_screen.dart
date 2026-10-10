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
    final country = TextEditingController(text: c?.country ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(c == null ? 'Novi grad' : 'Uredi grad')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(ctx, false)),
      ]),
      content: SizedBox(width: 400, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Naziv'),
          validator: (v) => Validators.requiredMax(v, 100, 'Naziv')),
        const SizedBox(height: 8),
        TextFormField(controller: country, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Država (opciono)'),
          validator: (v) => Validators.maxLen(v, 100, 'Država')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Sačuvaj')),
      ],
    ));
    if (ok == true) {
      try {
        await context.read<CityProvider>().upsert(id: c?.id, name: name.text.trim(), country: country.text.trim().isEmpty ? null : country.text.trim());
        _refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c == null ? 'Grad je uspješno dodan.' : 'Grad je uspješno ažuriran.')));
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
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
    if (ok != true) return;
    try { await context.read<CityProvider>().delete(x.id); _refresh(); }
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
            subtitle: Text(x.country ?? ''),
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
