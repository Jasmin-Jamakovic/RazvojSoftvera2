import 'package:flutter/material.dart';
import '../services/api_client.dart';

class GeoPlace {
  final String displayName;
  final double latitude, longitude;
  GeoPlace(this.displayName, this.latitude, this.longitude);
  factory GeoPlace.fromJson(Map<String, dynamic> j) =>
      GeoPlace(j['displayName'] ?? '', (j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());
}

/// Lets the patient find their address (OpenStreetMap lookup done by the API) and pick one result.
/// The chosen coordinates are used by the recommender to rank doctors by distance to their clinic.
Future<GeoPlace?> showLocationSearchDialog(BuildContext context, {int? cityId}) =>
    showDialog<GeoPlace>(context: context, builder: (_) => _LocationSearchDialog(cityId: cityId));

class _LocationSearchDialog extends StatefulWidget {
  final int? cityId;
  const _LocationSearchDialog({this.cityId});
  @override
  State<_LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<_LocationSearchDialog> {
  final _address = TextEditingController();
  List<GeoPlace>? _results;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _address.dispose(); super.dispose(); }

  Future<void> _search() async {
    final text = _address.text.trim();
    if (text.length < 3) { setState(() => _error = 'Unesite adresu (najmanje 3 znaka).'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final res = await ApiClient.get('/api/geocoding', query: {'address': text, 'cityId': widget.cityId});
      final list = ((res as List?) ?? []).map((e) => GeoPlace.fromJson(e)).toList();
      if (mounted) setState(() { _results = list; if (list.isEmpty) _error = 'Adresa nije pronađena. Pokušajte drugačije.'; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lokacija za preporuke'),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Unesite svoju adresu (ulica i broj). Koristi se samo za prikaz ljekara u vašoj blizini.',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _busy ? null : _search(),
          decoration: InputDecoration(
            labelText: 'Adresa',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _busy ? null : _search),
          ),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_results != null && _results!.isNotEmpty)
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final r in _results!)
              ListTile(
                dense: true,
                leading: const Icon(Icons.place_outlined),
                title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(context, r),
              ),
          ])),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Odustani'))],
    );
  }
}
