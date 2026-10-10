import 'package:flutter/foundation.dart';
import '../models/payment.dart';
import '../services/api_client.dart';

class PaymentProvider extends ChangeNotifier {
  /// The patient's own payments and refunds, newest first (the API scopes the list to the caller).
  Future<(List<Payment>, int)> history({int page = 0, int pageSize = 20}) async {
    final res = await ApiClient.get('/api/payments', query: {'page': page, 'pageSize': pageSize});
    final items = (res['items'] as List? ?? []).map((e) => Payment.fromJson(e)).toList();
    return (items, (res['totalCount'] as int?) ?? items.length);
  }

  Future<PaymentSummary> summary() async => PaymentSummary.fromJson(await ApiClient.get('/api/payments/summary'));

  Future<Map<String, dynamic>> createOrder(int appointmentId) async {
    final res = await ApiClient.post('/api/payments/paypal/orders', {'appointmentId': appointmentId});
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> capture(String orderId) async {
    final res = await ApiClient.post('/api/payments/paypal/orders/$orderId/capture');
    return res as Map<String, dynamic>;
  }
}
