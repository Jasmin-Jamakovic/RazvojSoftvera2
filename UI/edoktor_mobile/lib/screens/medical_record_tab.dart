import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/medical_record.dart';
import '../providers/medical_record_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'record_details_screen.dart';

enum _Kind { visit, prescription, lab }

const _kindStyle = {
  _Kind.visit: (Icons.medical_services_outlined, AppColors.primary, AppColors.tint),
  _Kind.prescription: (Icons.medication_outlined, Color(0xFF7B1FA2), Color(0xFFF3E8FD)),
  _Kind.lab: (Icons.description_outlined, Color(0xFFEF6C00), Color(0xFFFFF2E0)),
};

final _fmt = DateFormat('dd.MM.yyyy');

/// The patient's record: header (blood type, allergies, counts) and three paged sections as tabs.
class MedicalRecordTab extends StatefulWidget {
  const MedicalRecordTab({super.key});
  @override
  State<MedicalRecordTab> createState() => _MedicalRecordTabState();
}

class _MedicalRecordTabState extends State<MedicalRecordTab> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(_onTab);
  MedicalRecord? _record;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHeader({bool showSpinner = true}) async {
    if (showSpinner) setState(() { _loading = true; _error = null; });
    try {
      final r = await context.read<MedicalRecordProvider>().mine();
      if (!mounted) return;
      setState(() { _record = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _record == null) {
      return RefreshIndicator(
        onRefresh: _loadHeader,
        child: ListView(children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 60),
          EmptyState(
            icon: Icons.error_outline,
            message: 'Karton nije moguće učitati: $_error',
            action: TextButton(onPressed: _loadHeader, child: const Text('Pokušaj ponovo')),
          ),
        ]),
      );
    }
    final r = _record;
    if (r == null) {
      return RefreshIndicator(
        onRefresh: _loadHeader,
        child: ListView(children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 60),
          const EmptyState(icon: Icons.medical_information_outlined, message: 'Nema kartona.'),
        ]),
      );
    }
    final provider = context.read<MedicalRecordProvider>();
    Future<void> refreshHeader() => _loadHeader(showSpinner: false);
    return Column(children: [
      _header(context, r),
      if (r.allergies != null && r.allergies!.trim().isNotEmpty) _allergies(r.allergies!),
      SizedBox(
        height: 58,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          children: [
            SelectChip(label: 'Pregledi (${r.entryCount})', selected: _tabs.index == 0, onTap: () => _tabs.animateTo(0)),
            const SizedBox(width: 8),
            SelectChip(label: 'Recepti (${r.prescriptionCount})', selected: _tabs.index == 1, onTap: () => _tabs.animateTo(1)),
            const SizedBox(width: 8),
            SelectChip(label: 'Nalazi (${r.labResultCount})', selected: _tabs.index == 2, onTap: () => _tabs.animateTo(2)),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _PagedSection<MedicalRecordEntry>(
            kind: _Kind.visit,
            fetch: (page, search) => provider.entries(page: page, search: search),
            onRefresh: refreshHeader,
            searchHint: 'Pretraži po dijagnozi',
            emptyMessage: 'Nema evidentiranih pregleda.',
            toItem: (e) => _Item(
              title: e.diagnosis ?? 'Pregled',
              subtitle: [e.doctorName, e.specialization].whereType<String>().join(' · '),
              trailing: _fmt.format(e.appointmentDate),
              lines: [if (e.therapy != null) ('Terapija', e.therapy!)],
              details: () => RecordDetailsScreen.visit(r, e),
            ),
          ),
          _PagedSection<Prescription>(
            kind: _Kind.prescription,
            fetch: (page, search) => provider.prescriptions(page: page, search: search),
            onRefresh: refreshHeader,
            searchHint: 'Pretraži po lijeku',
            emptyMessage: 'Nema izdatih recepata.',
            toItem: (p) => _Item(
              title: p.diagnosis == null || p.diagnosis!.trim().isEmpty ? 'Recept' : 'Recept · ${p.diagnosis}',
              subtitle: p.doctorName ?? '',
              trailing: _fmt.format(p.issuedAt),
              lines: [
                for (final it in p.items)
                  (it.medication, [it.dosage, it.frequency, it.duration].whereType<String>().where((s) => s.isNotEmpty).join(' · ')),
              ],
              details: () => RecordDetailsScreen.prescription(r, p),
            ),
          ),
          _PagedSection<LabResult>(
            kind: _Kind.lab,
            fetch: (page, search) => provider.labResults(page: page, search: search),
            onRefresh: refreshHeader,
            searchHint: 'Pretraži po nazivu nalaza',
            emptyMessage: 'Nema laboratorijskih nalaza.',
            toItem: (l) => _Item(
              title: l.title,
              subtitle: l.notes ?? '',
              trailing: _fmt.format(l.createdAt),
              details: () => RecordDetailsScreen.lab(r, l),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _allergies(String allergies) => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E5),
          border: Border.all(color: const Color(0xFFFFD8A8)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(
              style: const TextStyle(color: Color(0xFF8A4B00), fontSize: 13),
              children: [const TextSpan(text: 'Alergije: ', style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: allergies)],
            )),
          ),
        ]),
      );

  Widget _header(BuildContext context, MedicalRecord r) {
    final dob = r.dateOfBirth;
    String age = '-';
    if (dob != null) {
      final now = DateTime.now();
      var y = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) y--;
      age = '$y';
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 16, 18, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Moj karton', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        if (r.patientName != null)
          Text(r.patientName!, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
        const SizedBox(height: 16),
        Row(children: [
          _vital('Krvna grupa', r.bloodType ?? '-'),
          const SizedBox(width: 8),
          _vital('Godine', age),
          const SizedBox(width: 8),
          _vital('Pregleda', '${r.entryCount}'),
        ]),
      ]),
    );
  }

  Widget _vital(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
      );
}

/// One record section: a searchable, infinitely scrolling list with pull-to-refresh, empty and error states.
class _PagedSection<T> extends StatefulWidget {
  final _Kind kind;
  final Future<(List<T>, int)> Function(int page, String? search) fetch;
  final Future<void> Function() onRefresh;
  final _Item Function(T) toItem;
  final String searchHint;
  final String emptyMessage;

  const _PagedSection({
    super.key,
    required this.kind,
    required this.fetch,
    required this.onRefresh,
    required this.toItem,
    required this.searchHint,
    required this.emptyMessage,
  });

  @override
  State<_PagedSection<T>> createState() => _PagedSectionState<T>();
}

class _PagedSectionState<T> extends State<_PagedSection<T>> with AutomaticKeepAliveClientMixin {
  final List<T> _items = [];
  final _search = TextEditingController();
  Timer? _debounce;
  int _total = 0;
  int _page = 0;
  int _generation = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool get _hasMore => _items.length < _total;

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() { _loading = _items.isEmpty; _error = null; _moreError = null; });
    try {
      final (items, total) = await widget.fetch(0, _search.text);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items..clear()..addAll(items);
        _total = total;
        _page = 0;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = '$e');
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() => Future.wait([_reload(), widget.onRefresh()]);

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final gen = _generation;
    setState(() { _loadingMore = true; _moreError = null; });
    try {
      final (items, total) = await widget.fetch(_page + 1, _search.text);
      if (!mounted || gen != _generation) return;
      setState(() { _items.addAll(items); _total = total; _page++; });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _moreError = '$e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _items.clear());
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searching = _search.text.trim().isNotEmpty;
    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: TextField(
          controller: _search,
          onChanged: _onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: searching
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _onSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
    ];

    if (_loading) {
      children.add(const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
    } else if (_error != null && _items.isEmpty) {
      children.add(EmptyState(
        icon: Icons.error_outline,
        message: 'Podatke nije moguće učitati: $_error',
        action: TextButton(onPressed: _reload, child: const Text('Pokušaj ponovo')),
      ));
    } else if (_items.isEmpty) {
      children.add(EmptyState(icon: Icons.inbox_outlined, message: searching ? 'Nema rezultata pretrage.' : widget.emptyMessage));
    } else {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Column(children: [
          for (var i = 0; i < _items.length; i++)
            _timelineRow(context, widget.kind, widget.toItem(_items[i]), last: i == _items.length - 1 && !_hasMore),
        ]),
      ));
      if (_hasMore) {
        children.add(Center(
          child: _loadingMore
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(children: [
                    if (_moreError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Greška: $_moreError', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ),
                    TextButton(onPressed: _loadMore, child: Text('Učitaj još (${_total - _items.length})')),
                  ]),
                ),
        ));
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Infinite scroll: fetch the next page when near the bottom (a failed page waits for the button).
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 300 && _moreError == null) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 16),
          children: children,
        ),
      ),
    );
  }
}

Widget _timelineRow(BuildContext context, _Kind kind, _Item it, {required bool last}) {
  final (icon, fg, bg) = _kindStyle[kind]!;
  return IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(children: [
        IconSquare(icon, size: 34, iconSize: 17, color: fg, background: bg),
        Expanded(
          child: Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: last ? Colors.transparent : const Color(0xFFD6DDD8),
          ),
        ),
      ]),
      const SizedBox(width: 12),
      Expanded(
        child: AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => it.details())),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(it.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(width: 8),
              Text(it.trailing, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
            if (it.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(it.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            for (final (label, value) in it.lines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF4A5263), height: 1.4),
                  children: [
                    TextSpan(text: value.isEmpty ? label : '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (value.isNotEmpty) TextSpan(text: value),
                  ],
                )),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(children: [
                Text('Detalji i PDF', style: TextStyle(fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
              ]),
            ),
          ]),
        ),
      ),
    ]),
  );
}

class _Item {
  final String title;
  final String subtitle;
  final String trailing;
  final List<(String, String)> lines;
  final Widget Function() details;

  _Item({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.lines = const [],
    required this.details,
  });
}
