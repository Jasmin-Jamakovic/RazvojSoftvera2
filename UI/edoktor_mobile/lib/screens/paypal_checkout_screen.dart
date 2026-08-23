import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/payment_provider.dart';

class PaypalCheckoutScreen extends StatefulWidget {
  final int appointmentId;
  final double price;
  const PaypalCheckoutScreen({super.key, required this.appointmentId, required this.price});
  @override
  State<PaypalCheckoutScreen> createState() => _PaypalCheckoutScreenState();
}

class _PaypalCheckoutScreenState extends State<PaypalCheckoutScreen> {
  bool _busy = false;
  String? _error;
  String? _approveUrl;
  String? _orderId;
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  Future<void> _createOrder() async {
    setState(() { _busy = true; _error = null; });
    try {
      final order = await context.read<PaymentProvider>().createOrder(widget.appointmentId);
      _orderId = order['orderId'];
      _approveUrl = order['approveUrl'];
      if (_approveUrl != null) {
        _ctrl = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(NavigationDelegate(
            onNavigationRequest: (req) async {
              if (req.url.contains('return') || req.url.contains('success') || req.url.contains('approved')) {
                await _capture();
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ))
          ..loadRequest(Uri.parse(_approveUrl!));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() async {
    if (_orderId == null) return;
    try {
      await context.read<PaymentProvider>().capture(_orderId!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaćanje uspješno. Termin je potvrđen.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Greška pri naplati: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plaćanje ${widget.price.toStringAsFixed(2)} EUR')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Plaćanje nije moguće pokrenuti: $_error', style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _createOrder, child: const Text('Pokušaj ponovo')),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Nazad')),
                ]))
              : _ctrl != null
                  ? WebViewWidget(controller: _ctrl!)
                  : const Center(child: Text('Učitavanje PayPal stranice...')),
    );
  }
}
