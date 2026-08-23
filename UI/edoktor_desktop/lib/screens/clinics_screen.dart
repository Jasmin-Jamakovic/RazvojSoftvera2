import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';
import '../utils/validators.dart';

class ClinicsScreen extends StatefulWidget {
  const ClinicsScreen({super.key});
  @override
  State<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends State<ClinicsScreen> {
  late Future<List<Clinic>> _f;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _refresh() { setState(() { _f = context.read<ClinicProvider>().list(name: _search.text); }); }

  Future<void> _edit([Clinic? c]) async {
    final cities = await context.read<CityProvider>().list();
    if (!mounted) return;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: c?.name ?? '');
    final addr = TextEditingController(text: c?.address ?? '');
    int? selectedCityId = c?.cityId;

    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Row(children: [
        Expanded(child: Text(c == null ? 'Nova klinika' : 'Uredi kliniku')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(ctx, false)),
      ]),
      content: SizedBox(width: 400, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Naziv'),
          validator: (v) => Validators.requiredMax(v, 150, 'Naziv')),
        const SizedBox(height: 8),
        TextFormField(controller: addr, autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(labelText: 'Adresa'),
          validator: (v) => Validators.requiredMax(v, 200, 'Adresa')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: selectedCityId,
          decoration: const InputDecoration(labelText: 'Grad'),
          items: cities.map((ci) => DropdownMenuItem(value: ci.id, child: Text(ci.name))).toList(),
          validator: (v) => v == null ? 'Odaberite grad.' : null,
          onChanged: (v) => setLocal(() => selectedCityId = v),
        ),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Odustani')),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Sačuvaj')),
      ],
    )));
    if (ok == true) {
      try {
        await context.read<ClinicProvider>().upsert(id: c?.id, name: name.text.trim(), address: addr.text.trim(), cityId: selectedCityId);
        _refresh();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c == null ? 'Klinika je uspješno dodana.' : 'Klinika je uspješno ažurirana.')));
      }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
    }
  }

  Future<void> _confirmDelete(Clinic x) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Brisanje klinike'),
      content: Text('Jeste li sigurni da želite obrisati "${x.name}"? Ova akcija je nepovratna.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Odustani')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Obriši')),
      ],
    ));
    if (ok != true) return;
    try { await context.read<ClinicProvider>().delete(x.id); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('Klinike', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const Spacer(), FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Dodaj'))]),
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
      Expanded(child: Card(child: FutureBuilder<List<Clinic>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        return ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final x = list[i];
          return ListTile(
            title: Text(x.name),
            subtitle: Text('${x.address ?? ""}, ${x.cityName ?? ""}'),
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
