import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../widgets/entity_avatar.dart';
import 'patient_details_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});
  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  static const _pageSize = 20;
  late Future<PagedList<User>> _f;
  final _search = TextEditingController();
  int _page = 0;
  @override
  void initState() { super.initState(); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  /// A new search starts again from the first page.
  void _refresh({bool resetPage = true}) {
    if (resetPage) _page = 0;
    setState(() { _f = context.read<PatientProvider>().page(search: _search.text, page: _page, pageSize: _pageSize); });
  }

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
      Expanded(child: Card(child: FutureBuilder<PagedList<User>>(future: _f, builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final data = s.data!;
        final list = data.items;
        if (list.isEmpty) return const Center(child: Text('Nema pacijenata.'));
        final first = _page * _pageSize + 1;
        final last = _page * _pageSize + list.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: ListView.separated(itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (c, i) {
          final u = list[i];
          return ListTile(
            leading: EntityAvatar(path: u.hasImage ? '/api/users/${u.id}/photo' : null, initials: _initials(u)),
            title: Text(u.fullName),
            subtitle: Text('${u.username} • ${u.email}'),
            trailing: const Tooltip(message: 'Historija termina i zdravstveni karton', child: Icon(Icons.chevron_right)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailsScreen(patient: u))),
          );
          })),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(8), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Prikazano $first–$last od ${data.totalCount}'),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Prethodna strana',
              onPressed: _page > 0 ? () { _page--; _refresh(resetPage: false); } : null),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Sljedeća strana',
              onPressed: last < data.totalCount ? () { _page++; _refresh(resetPage: false); } : null),
          ])),
        ]);
      }))),
    ]));
  }
}
