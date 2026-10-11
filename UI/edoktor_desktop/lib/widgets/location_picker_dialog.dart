import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../providers/providers.dart';

/// Picks a clinic's coordinates: click on the map, or look the address up and choose a result.
/// Returns the chosen point, or null when cancelled.
class LocationPickerDialog extends StatefulWidget {
  final LatLng? initial;
  final String address;
  final int? cityId;
  const LocationPickerDialog({super.key, this.initial, required this.address, this.cityId});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  // Centre of Bosnia and Herzegovina, used when nothing is picked yet.
  static const _defaultCenter = LatLng(43.9159, 17.6791);

  final _map = MapController();
  late final TextEditingController _query = TextEditingController(text: widget.address);
  LatLng? _point;
  List<GeocodingResult> _results = [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() { _query.dispose(); super.dispose(); }

  Future<void> _search() async {
    setState(() { _searching = true; _searchError = null; _results = []; });
    try {
      final results = await context.read<ClinicProvider>().geocode(_query.text, cityId: widget.cityId);
      setState(() {
        _results = results;
        if (results.isEmpty) _searchError = 'Adresa nije pronađena. Provjerite unos ili kliknite lokaciju na karti.';
      });
      if (results.length == 1) _choose(results.first.point);
    } catch (e) {
      setState(() => _searchError = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(LatLng p) {
    setState(() => _point = p);
    _map.move(p, 16);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Expanded(child: Text('Lokacija klinike')),
        IconButton(icon: const Icon(Icons.close), tooltip: 'Zatvori', onPressed: () => Navigator.pop(context)),
      ]),
      content: SizedBox(width: 640, height: 520, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: TextField(
            controller: _query,
            decoration: const InputDecoration(labelText: 'Adresa (ulica i broj)', prefixIcon: Icon(Icons.search), isDense: true),
            onSubmitted: (_) => _search(),
          )),
          const SizedBox(width: 8),
          FilledButton(onPressed: _searching ? null : _search, child: Text(_searching ? 'Tražim…' : 'Pronađi')),
        ]),
        if (_searchError != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (_results.length > 1)
          SizedBox(height: 96, child: ListView(children: [
            for (final r in _results)
              ListTile(dense: true, leading: const Icon(Icons.place_outlined), title: Text(r.displayName, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _choose(r.point)),
          ])),
        const SizedBox(height: 8),
        const Text('Ili kliknite na kartu da postavite lokaciju.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _point ?? _defaultCenter,
              initialZoom: _point == null ? 7 : 16,
              onTap: (_, p) => setState(() => _point = p),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.edoktor.admin'),
              if (_point != null)
                MarkerLayer(markers: [
                  Marker(point: _point!, width: 40, height: 40, alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, size: 40, color: Colors.red)),
                ]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap')),
            ],
          ),
        )),
        const SizedBox(height: 8),
        Text(_point == null ? 'Lokacija nije odabrana.' : 'Odabrano: ${_point!.latitude.toStringAsFixed(5)}, ${_point!.longitude.toStringAsFixed(5)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani')),
        FilledButton(onPressed: _point == null ? null : () => Navigator.pop(context, _point), child: const Text('Potvrdi lokaciju')),
      ],
    );
  }
}
