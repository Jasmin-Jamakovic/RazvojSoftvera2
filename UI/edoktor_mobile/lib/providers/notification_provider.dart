import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/consultation_message.dart';
import '../models/notification_item.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';
import '../utils/api_config.dart';
import 'package:signalr_netcore/signalr_client.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _items = [];
  List<NotificationItem> get items => _items;
  int get unreadCount => _items.where((n) => !n.isRead).length;
  HubConnection? _hub;
  Timer? _poll;
  static const _pollInterval = Duration(seconds: 30);
  final _consultation = StreamController<ConsultationMessage>.broadcast();

  /// Chat messages of online consultations, pushed in real time over the same SignalR connection.
  Stream<ConsultationMessage> get consultationMessages => _consultation.stream;

  Future<void> load() async {
    final res = await ApiClient.get('/api/notifications', query: {'pageSize': 100});
    _items = (res['items'] as List? ?? []).map((e) => NotificationItem.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    await ApiClient.post('/api/notifications/$id/read');
    await load();
  }

  Future<void> markAllRead() async {
    await ApiClient.post('/api/notifications/read-all');
    await load();
  }

  Future<void> connectSignalR() async {
    await disconnect(); // never keep a connection/timer from a previous session
    final token = AuthStore.token;
    if (token == null) return;
    final url = '${ApiConfig.baseUrl}/hubs/notifications?access_token=$token';
    _hub = HubConnectionBuilder().withUrl(url).withAutomaticReconnect().build();
    _hub!.on('notification:new', (args) {
      if (args != null && args.isNotEmpty) {
        load();
      }
    });
    _hub!.on('consultation:message', (args) {
      if (args != null && args.isNotEmpty && args.first is Map) {
        _consultation.add(ConsultationMessage.fromJson(Map<String, dynamic>.from(args.first as Map)));
      }
    });
    try {
      await _hub!.start();
    } catch (e) {
      debugPrint('SignalR connection failed, falling back to polling every ${_pollInterval.inSeconds}s: $e');
      _startPolling();
    }
  }

  /// Fallback when real-time push is unavailable: reload notifications periodically.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) async {
      if (AuthStore.token == null) {
        _poll?.cancel();
        _poll = null;
        return;
      }
      try {
        await load();
      } catch (e) {
        debugPrint('Notification polling failed: $e');
      }
    });
  }

  /// Stops the SignalR connection and the polling timer (on logout / session expiry).
  Future<void> disconnect() async {
    _poll?.cancel();
    _poll = null;
    final hub = _hub;
    _hub = null;
    if (hub == null) return;
    try {
      await hub.stop();
    } catch (e) {
      debugPrint('SignalR disconnect failed: $e');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _hub?.stop();
    _consultation.close();
    super.dispose();
  }
}
