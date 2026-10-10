class ConsultationMessage {
  final int id;
  final int appointmentId;
  final int senderId;
  final String senderName;
  final String? text;
  final bool hasImage;
  final DateTime createdAt;

  ConsultationMessage({
    required this.id, required this.appointmentId, required this.senderId, required this.senderName,
    this.text, required this.hasImage, required this.createdAt,
  });

  factory ConsultationMessage.fromJson(Map<String, dynamic> j) => ConsultationMessage(
        id: j['id'],
        appointmentId: j['appointmentId'],
        senderId: j['senderId'],
        senderName: j['senderName'] ?? '',
        text: j['text'],
        hasImage: j['hasImage'] ?? false,
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}
