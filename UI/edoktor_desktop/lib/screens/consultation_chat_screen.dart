import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entities.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../providers/providers.dart';
import '../services/auth_store.dart';
import '../utils/api_config.dart';

/// Chat with the patient of an online consultation (same API as the mobile app). New messages arrive
/// over SignalR; while the real-time connection is down the conversation is polled every 10 s.
class ConsultationChatScreen extends StatefulWidget {
  final Appointment appointment;
  const ConsultationChatScreen({super.key, required this.appointment});

  @override
  State<ConsultationChatScreen> createState() => _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen> {
  static const _pageSize = 30;
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _pollInterval = Duration(seconds: 10);
  static final _fmt = DateFormat('dd.MM. HH:mm');

  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<ConsultationMessage> _messages = []; // oldest first, as displayed
  StreamSubscription<ConsultationMessage>? _sub;
  Timer? _poll;
  int _total = 0;
  int _page = 0;
  bool _loading = true, _loadingOlder = false, _sending = false;
  String? _error;

  int get _id => widget.appointment.id;
  int? get _myId => AuthStore.user?.id;
  // The API accepts new messages only while the consultation is confirmed.
  bool get _canSend => widget.appointment.status == 'Confirmed';

  @override
  void initState() {
    super.initState();
    final notifications = context.read<NotificationProvider>();
    _sub = notifications.consultationMessages.where((m) => m.appointmentId == _id).listen(_add);
    _poll = Timer.periodic(_pollInterval, (_) { if (!notifications.isRealtime) _fetchLatest(); });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await context.read<AppointmentProvider>().messages(_id, pageSize: _pageSize);
      if (!mounted) return;
      setState(() { _messages..clear()..addAll(p.items.reversed); _total = p.totalCount; _page = 0; _error = null; });
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Polling fallback: merge the newest page into the conversation.
  Future<void> _fetchLatest() async {
    try {
      final p = await context.read<AppointmentProvider>().messages(_id, pageSize: _pageSize);
      if (!mounted) return;
      for (final m in p.items.reversed) {
        _add(m);
      }
    } catch (e) {
      debugPrint('Chat polling failed: $e');
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    try {
      final p = await context.read<AppointmentProvider>().messages(_id, page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      setState(() { _messages.insertAll(0, p.items.reversed.where((m) => !known.contains(m.id))); _total = p.totalCount; _page++; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _add(ConsultationMessage m) {
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() { _messages.add(m); _total++; });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send({Uint8List? image}) async {
    final text = _text.text.trim();
    if (text.isEmpty && image == null) return;
    setState(() => _sending = true);
    try {
      final m = await context.read<AppointmentProvider>().sendMessage(_id, text: image == null ? text : null, image: image);
      if (image == null) _text.clear();
      _add(m);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Poruka nije poslana: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto() async {
    final files = await FilePicker.pickFiles(type: FileType.image, dialogTitle: 'Fotografija za pacijenta');
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotografija je veća od 5 MB. Odaberite manju sliku.')));
      return;
    }
    await _send(image: bytes);
  }

  Widget _bubble(ConsultationMessage m) {
    final mine = m.senderId == _myId;
    final path = context.read<AppointmentProvider>().messageImagePath(m.appointmentId, m.id);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDCEFDD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine) Text(m.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
          if (m.hasImage)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network('${ApiConfig.baseUrl}$path',
                headers: {if (AuthStore.token != null) 'Authorization': 'Bearer ${AuthStore.token}'},
                width: 260, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Text('Fotografiju nije moguće prikazati.')),
            )),
          if (m.text != null) SelectableText(m.text!),
          const SizedBox(height: 2),
          Text(_fmt.format(m.createdAt), style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6F2),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Chat: ${a.patientName ?? 'Pacijent'} • ${DateFormat('dd.MM.yyyy HH:mm').format(a.startUtc)}'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Osvježi', onPressed: _load)],
      ),
      body: Column(children: [
        if (!_canSend)
          const MaterialBanner(
            backgroundColor: Color(0xFFFFF4E5),
            content: Text('Poruke se mogu slati samo za potvrđenu online konsultaciju. Prikazana je historija razgovora.'),
            actions: [SizedBox.shrink()],
          ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Poruke nije moguće učitati: $_error', style: const TextStyle(color: Colors.red)))
                : _messages.isEmpty
                    ? const Center(child: Text('Još nema poruka.'))
                    : ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
                        if (_messages.length < _total)
                          Center(child: _loadingOlder
                              ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                              : TextButton(onPressed: _loadOlder, child: const Text('Učitaj starije poruke'))),
                        for (final m in _messages) _bubble(m),
                      ])),
        const Divider(height: 1),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(children: [
            IconButton(
              tooltip: 'Pošalji fotografiju',
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2E7D32)),
              onPressed: _sending || !_canSend ? null : _pickPhoto,
            ),
            Expanded(child: TextField(
              controller: _text,
              enabled: _canSend,
              minLines: 1, maxLines: 4, maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(hintText: 'Napišite poruku…', counterText: '', isDense: true, border: OutlineInputBorder()),
            )),
            IconButton(
              tooltip: 'Pošalji',
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Color(0xFF2E7D32)),
              onPressed: _sending || !_canSend ? null : _send,
            ),
          ]),
        ),
      ]),
    );
  }
}
