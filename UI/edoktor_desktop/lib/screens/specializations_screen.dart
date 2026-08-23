import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

class SpecializationsScreen extends StatefulWidget {
  const SpecializationsScreen({super.key});
  @override
  State<SpecializationsScreen> createState() => _SpecializationsScreenState();
}

class _SpecializationsScreenState extends State<SpecializationsScreen> {
  late Future<List<Specialization>> _f;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _refresh() { setState(() { _f = context.read<SpecializationProvider>().list(name: _search.text); }); }

  Future<void> _edit([Specialization? s]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: s?.name ?? '');
    final desc = TextEditingController(text: s?.description ?? '');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(s == null ? 'Nova specijalizacija' : 'Uredi specijalizaciju')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(c, false)),
      ]),
      content: SizedBox(width: 400, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Naziv'),
          validator: (v) => Validators.requiredMax(v, 100, 'Naziv')),
        const SizedBox(height: 8),
        TextFormField(controller: desc, maxLines: 3, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Opis'),
          validator: (v) => Validators.maxLen(v, 500, 'Opis')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(c, true); }, child: const Text('Sačuvaj')),
      ],
    ));
    if (ok == true) {
      try {
        await context.read<SpecializationProvider>().upsert(id: s?.id, name: name.text.trim(), description: desc.text.trim());
        _refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s == null ? 'Specijalizacija je uspješno dodana.' : 'Specijalizacija je uspješno ažurirana.')));
      }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  Future<void> _confirmDelete(Specialization x) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Brisanje specijalizacije'),
      content: Text('Jeste li sigurni da želite obrisati "${x.name}"? Ova akcija je nepovratna.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
      ],
    ));
    if (ok != true) return;
    try { await context.read<SpecializationProvider>().delete(x.id); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('Specijalizacije', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const Spacer(), FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Dodaj'))]),
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
      Expanded(child: Card(child: FutureBuilder<List<Specialization>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        return ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final x = list[i];
          return ListTile(
            title: Text(x.name),
            subtitle: Text(x.description ?? ''),
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
