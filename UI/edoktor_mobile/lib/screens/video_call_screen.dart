import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/consultation_chat.dart';

/// Online consultation: the video room (Jitsi in a WebView) with a chat panel for messages and photos.
class VideoCallScreen extends StatefulWidget {
  final int appointmentId;
  final String joinUrl;
  final String doctorName;
  const VideoCallScreen({super.key, required this.appointmentId, required this.joinUrl, required this.doctorName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  WebViewController? _ctrl;
  bool _permissionsDenied = false;
  bool _chatOpen = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _start();
  }

  Future<void> _start() async {
    // The WebView can only pass the camera/microphone to the call once the app itself holds both permissions.
    final statuses = await [Permission.camera, Permission.microphone].request();
    final granted = statuses.values.every((s) => s.isGranted);
    if (!mounted) return;
    setState(() {
      _permissionsDenied = !granted;
      _ctrl = WebViewController(onPermissionRequest: (request) => request.grant())
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.joinUrl));
    });
  }

  void _toggleChat() => setState(() { _chatOpen = !_chatOpen; if (_chatOpen) _unread = 0; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Konsultacija — ${widget.doctorName}'),
        actions: [
          IconButton(
            tooltip: _chatOpen ? 'Sakrij chat' : 'Otvori chat',
            onPressed: _toggleChat,
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: Icon(_chatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline),
            ),
          ),
        ],
      ),
      body: Column(children: [
        if (_permissionsDenied)
          MaterialBanner(
            backgroundColor: const Color(0xFFFFF4E5),
            content: const Text('Bez dozvole za kameru i mikrofon ljekar vas neće vidjeti ni čuti. Omogućite dozvole u postavkama.'),
            actions: [TextButton(onPressed: openAppSettings, child: const Text('Postavke'))],
          ),
        Expanded(
          flex: 3,
          child: kIsWeb
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Video poziv radi u Android aplikaciji. Chat je dostupan ispod.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  ),
                )
              : _ctrl == null
                  ? const Center(child: CircularProgressIndicator())
                  : WebViewWidget(controller: _ctrl!),
        ),
        // Kept alive while hidden so incoming messages still update the unread badge.
        Offstage(
          offstage: !_chatOpen && !kIsWeb,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: Material(
              color: AppColors.bg,
              child: ConsultationChat(
                appointmentId: widget.appointmentId,
                onIncoming: (_) { if (!_chatOpen) setState(() => _unread++); },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
