import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/doctor.dart';
import '../models/specialization.dart';
import '../providers/doctor_provider.dart';
import '../providers/specialization_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/doctor_card.dart';
import '../widgets/ui.dart';
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

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _loadSpecs() async {
    final s = await context.read<SpecializationProvider>().list();
    if (!mounted) return;
    setState(() => _specs = s);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final res = await context.read<DoctorProvider>().search(name: _q.text, specializationId: _specId);
    if (!mounted) return;
    setState(() { _doctors = res; _loading = false; });
  }

  void _pickSpec(int? id) {
    setState(() => _specId = id);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Text('Pronađi ljekara', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: AppColors.softShadow),
            child: TextField(
              controller: _q,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ime ljekara…',
                prefixIcon: const Icon(Icons.search),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconSquare(Icons.arrow_forward, size: 32, iconSize: 16, color: Colors.white, background: AppColors.primary, onTap: _search),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              SelectChip(label: 'Svi', selected: _specId == null, onTap: () => _pickSpec(null)),
              for (final s in _specs) ...[
                const SizedBox(width: 8),
                SelectChip(label: s.name, selected: _specId == s.id, onTap: () => _pickSpec(s.id)),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _doctors.isEmpty
                  ? const Center(child: EmptyState(icon: Icons.person_search_outlined, message: 'Nema rezultata za ovu pretragu.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      itemCount: _doctors.length,
                      itemBuilder: (c, i) => DoctorCard(
                        doctor: _doctors[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorDetailsScreen(doctor: _doctors[i]))),
                      ),
                    ),
        ),
      ]),
    );
  }
}
