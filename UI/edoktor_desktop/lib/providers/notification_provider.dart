import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../models/notification_item.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';
import '../utils/api_config.dart';

/// In-app notifications of the signed-in user (the doctor), kept fresh over SignalR
/// (`notification:new` on the user's group), with 30 s polling when real-time push is unavailable.
/// The same connection also delivers consultation chat messages (`consultation:message`).
class NotificationProvider extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 30);

  List<NotificationItem> _items = [];
  List<NotificationItem> get items => _items;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  HubConnection? _hub;
  Timer? _poll;
  final _consultation = StreamController<ConsultationMessage>.broadcast();

  /// Chat messages of online consultations, pushed in real time.
  Stream<ConsultationMessage> get consultationMessages => _consultation.stream;

  /// True while the SignalR connection is up (otherwise screens should poll on their own).
  bool get isRealtime => _hub?.state == HubConnectionState.Connected;

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

  /// Loads the notifications and opens the SignalR connection (called when the doctor's shell opens).
  Future<void> connect() async {
    await disconnect(); // never keep a connection/timer from a previous session
    final token = AuthStore.token;
    if (token == null) return;
    try {
      await load();
    } catch (e) {
      debugPrint('Loading notifications failed: $e');
    }
    final url = '${ApiConfig.baseUrl}/hubs/notifications?access_token=$token';
    final hub = HubConnectionBuilder().withUrl(url).withAutomaticReconnect().build();
    _hub = hub;
    hub.on('notification:new', (args) {
      if (args != null && args.isNotEmpty) load().catchError((e) => debugPrint('Reloading notifications failed: $e'));
    });
    hub.on('consultation:message', (args) {
      if (args != null && args.isNotEmpty && args.first is Map) {
        _consultation.add(ConsultationMessage.fromJson(Map<String, dynamic>.from(args.first as Map)));
      }
    });
    // Automatic reconnect gave up: keep the list fresh by polling.
    hub.onclose(({Exception? error}) {
      if (identical(_hub, hub)) _startPolling();
    });
    try {
      await hub.start();
    } catch (e) {
      debugPrint('SignalR connection failed, falling back to polling every ${_pollInterval.inSeconds}s: $e');
      _startPolling();
    }
  }

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
    if (_items.isNotEmpty) {
      _items = [];
      notifyListeners();
    }
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
