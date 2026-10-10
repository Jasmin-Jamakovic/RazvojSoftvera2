/// Bosnian display labels for backend status codes.
String paymentStatusLabel(String status) => switch (status) {
      'Captured' => 'Naplaćeno',
      'Created' => 'Na čekanju',
      'Refunded' => 'Vraćeno',
      _ => status,
    };

String appointmentStatusLabel(String? status) => switch (status) {
      'Pending' => 'Na čekanju',
      'Confirmed' => 'Potvrđen',
      'Completed' => 'Završen',
      'Cancelled' => 'Otkazan',
      _ => status ?? '-',
    };
