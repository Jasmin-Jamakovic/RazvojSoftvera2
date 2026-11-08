class NotificationItem {
  final int id;
  final String title, body, type;
  final bool isRead;
  final DateTime createdAt;
  NotificationItem({required this.id, required this.title, required this.body, required this.type, required this.isRead, required this.createdAt});
  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'], title: j['title'] ?? '', body: j['body'] ?? '', type: j['type'] ?? 'general',
        isRead: j['isRead'] ?? false, createdAt: DateTime.parse(j['createdAt']).toLocal());
}

/// A chat message of an online consultation.
class ConsultationMessage {
  final int id, appointmentId, senderId;
  final String senderName;
  final String? text;
  final bool hasImage;
  final DateTime createdAt;
  ConsultationMessage({required this.id, required this.appointmentId, required this.senderId, required this.senderName, this.text, required this.hasImage, required this.createdAt});
  factory ConsultationMessage.fromJson(Map<String, dynamic> j) => ConsultationMessage(
        id: j['id'], appointmentId: j['appointmentId'], senderId: j['senderId'], senderName: j['senderName'] ?? '',
        text: j['text'], hasImage: j['hasImage'] ?? false, createdAt: DateTime.parse(j['createdAt']).toLocal());
}
