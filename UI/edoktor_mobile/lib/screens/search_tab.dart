import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/specialization.dart';
import '../providers/doctor_provider.dart';
import '../providers/specialization_provider.dart';
import '../widgets/doctor_card.dart';
import 'doctor_details_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final _q = TextEditingController();
  List<Specialization> _specs = [];
  int? _specId;
  List<Doctor> _doctors = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSpecs();
    _search();
  }

  Future<void> _loadSpecs() async {
    final s = await context.read<SpecializationProvider>().list();
    setState(() => _specs = s);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final res = await context.read<DoctorProvider>().search(name: _q.text, specializationId: _specId);
    if (!mounted) return;
    setState(() { _doctors = res; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _q,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Pretražite ljekare...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              suffixIcon: IconButton(icon: const Icon(Icons.tune), onPressed: _search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            _chip('Svi', _specId == null, () { setState(() => _specId = null); _search(); }),
            ..._specs.map((s) => _chip(s.name, _specId == s.id, () { setState(() => _specId = s.id); _search(); })),
          ]),
        ),
        if (_loading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
        else Expanded(child: _doctors.isEmpty ? const Center(child: Text('Nema rezultata.')) : ListView.builder(itemCount: _doctors.length, itemBuilder: (c, i) => DoctorCard(doctor: _doctors[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDetailsScreen(doctor: _doctors[i])))))),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
  );
}
