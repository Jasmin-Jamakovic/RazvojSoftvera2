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
    try { await _hub!.start(); } catch (_) {}
  }

  Future<void> disconnect() async {
    await _hub?.stop();
    _hub = null;
  }
}
