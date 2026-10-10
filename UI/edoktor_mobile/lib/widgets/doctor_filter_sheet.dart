import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/city.dart';
import '../providers/city_provider.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Filters for the doctor search: location, maximum price, minimum rating and availability.
class DoctorFilters {
  final int? cityId;
  final String? cityName;
  final double? maxPrice;
  final double? minRating;
  final bool availableSoon;

  const DoctorFilters({this.cityId, this.cityName, this.maxPrice, this.minRating, this.availableSoon = false});

  int get activeCount => [cityId != null, maxPrice != null, minRating != null, availableSoon].where((x) => x).length;

  String get summary => [
        if (cityName != null) cityName!,
        if (maxPrice != null) 'do ${maxPrice!.toStringAsFixed(0)} €',
        if (minRating != null) 'ocjena ${minRating!.toStringAsFixed(minRating! % 1 == 0 ? 0 : 1)}+',
        if (availableSoon) 'slobodan u 7 dana',
      ].join(' · ');
}

class DoctorFilterSheet extends StatefulWidget {
  final DoctorFilters initial;
  const DoctorFilterSheet({super.key, required this.initial});

  static Future<DoctorFilters?> show(BuildContext context, DoctorFilters initial) => showModalBottomSheet<DoctorFilters>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => DoctorFilterSheet(initial: initial),
      );

  @override
  State<DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends State<DoctorFilterSheet> {
  // The top of the price slider means "no limit".
  static const _priceCap = 200.0;
  static const _ratings = [null, 3.0, 4.0, 4.5];

  late final Future<List<City>> _cities = context.read<CityProvider>().list();
  late int? _cityId = widget.initial.cityId;
  late double _price = widget.initial.maxPrice ?? _priceCap;
  late double? _minRating = widget.initial.minRating;
  late bool _availableSoon = widget.initial.availableSoon;

  void _apply(List<City> cities) {
    final city = cities.where((c) => c.id == _cityId).firstOrNull;
    Navigator.pop(context, DoctorFilters(
      cityId: city?.id,
      cityName: city?.name,
      maxPrice: _price >= _priceCap ? null : _price,
      minRating: _minRating,
      availableSoon: _availableSoon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: FutureBuilder<List<City>>(future: _cities, builder: (c, s) {
          final cities = s.data ?? [];
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Filteri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 8),
            const Text('Lokacija', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int?>(
              key: ValueKey('cities-${cities.length}'),
              initialValue: cities.any((x) => x.id == _cityId) ? _cityId : null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: s.hasError ? 'Gradove nije moguće učitati' : 'Svi gradovi',
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Svi gradovi')),
                ...cities.map((x) => DropdownMenuItem<int?>(value: x.id, child: Text(x.name))),
              ],
              onChanged: (v) => setState(() => _cityId = v),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('Maksimalna cijena pregleda', style: TextStyle(fontWeight: FontWeight.w600))),
              Text(_price >= _priceCap ? 'Bez ograničenja' : 'do ${_price.toStringAsFixed(0)} €',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ]),
            Slider(
              value: _price,
              min: 20,
              max: _priceCap,
              divisions: 36,
              label: _price >= _priceCap ? 'Bez ograničenja' : '${_price.toStringAsFixed(0)} €',
              onChanged: (v) => setState(() => _price = v),
            ),
            const SizedBox(height: 6),
            const Text('Minimalna ocjena', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _ratings)
                SelectChip(
                  label: r == null ? 'Sve' : '★ ${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}+',
                  selected: _minRating == r,
                  onTap: () => setState(() => _minRating = r),
                ),
            ]),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Slobodan u narednih 7 dana', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Prikaži samo ljekare koji imaju slobodan termin', style: TextStyle(fontSize: 12)),
              value: _availableSoon,
              onChanged: (v) => setState(() => _availableSoon = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, const DoctorFilters()),
                  child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Poništi')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: GradientButton(label: 'Primijeni filtere', onPressed: () => _apply(cities))),
            ]),
          ]);
        }),
      ),
    );
  }
}
