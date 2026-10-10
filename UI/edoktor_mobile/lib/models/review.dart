class Review {
  final int id;
  final String? patientName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  Review({required this.id, this.patientName, required this.rating, this.comment, required this.createdAt});

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'],
        patientName: j['patientName'],
        rating: j['rating'] ?? 0,
        comment: j['comment'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}
