import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class PaymentProvider extends ChangeNotifier {
  Future<Map<String, dynamic>> createOrder(int appointmentId) async {
    final res = await ApiClient.post('/api/payments/paypal/orders', {'appointmentId': appointmentId});
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> capture(String orderId) async {
    final res = await ApiClient.post('/api/payments/paypal/orders/$orderId/capture');
    return res as Map<String, dynamic>;
  }
}
