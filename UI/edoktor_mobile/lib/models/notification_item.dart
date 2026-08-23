class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  NotificationItem({required this.id, required this.title, required this.body, required this.type, required this.isRead, required this.createdAt});
  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'],
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        type: j['type'] ?? 'general',
        isRead: j['isRead'] ?? false,
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}
