import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/entity_avatar.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late Future<List<User>> _f;
  final _search = TextEditingController();
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  void _refresh() { setState(() { _f = context.read<PatientProvider>().list(search: _search.text); }); }

  String _initials(User u) => ((u.firstName.isNotEmpty ? u.firstName[0] : '') + (u.lastName.isNotEmpty ? u.lastName[0] : '')).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Pacijenti', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(width: 24),
        SizedBox(width: 300, child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Pretraga (ime, korisničko ime, email)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _refresh(); }),
            isDense: true, border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _refresh(),
        )),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.search), label: const Text('Traži')),
      ]),
      const SizedBox(height: 12),
      Expanded(child: Card(child: FutureBuilder<List<User>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final list = s.data ?? [];
        if (list.isEmpty) return const Center(child: Text('Nema pacijenata.'));
        return ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final u = list[i];
          return ListTile(
            leading: EntityAvatar(path: u.hasImage ? '/api/users/${u.id}/photo' : null, initials: _initials(u)),
            title: Text(u.fullName),
            subtitle: Text('${u.username} • ${u.email}'),
          );
        });
      }))),
    ]));
  }
}
