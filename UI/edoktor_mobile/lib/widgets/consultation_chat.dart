import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/consultation_message.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../services/auth_store.dart';
import '../theme/app_theme.dart';
import '../utils/api_config.dart';
import 'ui.dart';

/// Chat with the doctor during an online consultation: text messages and photos (e.g. of a finding).
/// New messages arrive in real time over SignalR.
class ConsultationChat extends StatefulWidget {
  final int appointmentId;
  /// Called for every message from the other participant (used for the unread badge).
  final ValueChanged<ConsultationMessage>? onIncoming;
  const ConsultationChat({super.key, required this.appointmentId, this.onIncoming});

  @override
  State<ConsultationChat> createState() => _ConsultationChatState();
}

class _ConsultationChatState extends State<ConsultationChat> {
  static const _pageSize = 30;
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _text = TextEditingController();
  final _scroll = ScrollController();
  // Oldest first, as displayed.
  final List<ConsultationMessage> _messages = [];
  StreamSubscription<ConsultationMessage>? _sub;
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  String? _error;

  int? get _myId => context.read<AuthProvider>().user?.id;

  @override
  void initState() {
    super.initState();
    _sub = context.read<NotificationProvider>().consultationMessages
        .where((m) => m.appointmentId == widget.appointmentId)
        .listen(_onPushed);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (items, total) = await context.read<AppointmentProvider>().messages(widget.appointmentId, pageSize: _pageSize);
      if (!mounted) return;
      setState(() { _messages..clear()..addAll(items.reversed); _total = total; _page = 0; });
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    try {
      final (items, total) = await context.read<AppointmentProvider>().messages(widget.appointmentId, page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      setState(() {
        _messages.insertAll(0, items.reversed.where((m) => !known.contains(m.id)));
        _total = total;
        _page++;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _onPushed(ConsultationMessage m) {
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() { _messages.add(m); _total++; });
    if (m.senderId != _myId) widget.onIncoming?.call(m);
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
      final m = await context.read<AppointmentProvider>().sendMessage(widget.appointmentId, text: image == null ? text : null, image: image);
      if (image == null) _text.clear();
      _onPushed(m);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Poruka nije poslana: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Uslikaj nalaz'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Odaberi iz galerije'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotografija je veća od 5 MB. Odaberite manju sliku.')));
      return;
    }
    await _send(image: bytes);
  }

  @override
  Widget build(BuildContext context) {
    final myId = _myId;
    return Column(children: [
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: EmptyState(icon: Icons.error_outline, message: 'Poruke nije moguće učitati: $_error'))
                : _messages.isEmpty
                    ? const Center(child: EmptyState(icon: Icons.chat_bubble_outline, message: 'Još nema poruka. Pošaljite pitanje ili fotografiju nalaza.'))
                    : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: [
                        if (_messages.length < _total)
                          Center(
                            child: _loadingOlder
                                ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                                : TextButton(onPressed: _loadOlder, child: const Text('Učitaj starije poruke')),
                          ),
                        for (final m in _messages) _Bubble(message: m, mine: m.senderId == myId),
                      ]),
      ),
      const Divider(height: 1),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Row(children: [
            IconButton(
              tooltip: 'Pošalji fotografiju',
              icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
              onPressed: _sending ? null : _pickPhoto,
            ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(hintText: 'Napišite poruku…', counterText: '', isDense: true),
              ),
            ),
            IconButton(
              tooltip: 'Pošalji',
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _sending ? null : _send,
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final ConsultationMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final path = context.read<AppointmentProvider>().messageImagePath(m.appointmentId, m.id);
    final image = m.hasImage
        ? Image.network(
            '${ApiConfig.baseUrl}$path',
            headers: {if (AuthStore.token != null) 'Authorization': 'Bearer ${AuthStore.token}'},
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(8), child: Text('Fotografiju nije moguće prikazati.')),
          )
        : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? AppColors.tint : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!mine) Text(m.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          if (image != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PhotoViewer(image: image))),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: image),
            ),
          if (m.text != null) Text(m.text!, style: const TextStyle(fontSize: 14, height: 1.35)),
          const SizedBox(height: 2),
          Align(alignment: Alignment.bottomRight, child: Text(hhmm(m.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.muted))),
        ]),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final Image image;
  const _PhotoViewer({required this.image});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Fotografija')),
        body: Center(child: InteractiveViewer(maxScale: 5, child: Image(image: image.image))),
      );
}
