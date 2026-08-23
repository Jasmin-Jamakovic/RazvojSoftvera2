import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Embeds the online-consultation room in-app instead of dumping the URL to the console.
class VideoCallScreen extends StatefulWidget {
  final String joinUrl;
  final String doctorName;
  const VideoCallScreen({super.key, required this.joinUrl, required this.doctorName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final WebViewController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.joinUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Konsultacija — ${widget.doctorName}')),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}
