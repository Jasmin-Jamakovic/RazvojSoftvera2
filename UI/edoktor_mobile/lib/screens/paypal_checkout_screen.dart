import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/payment_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// In-app PayPal checkout. PayPal redirects to the order's return/cancel URL after the payer decides;
/// the WebView intercepts those URLs, so the result is detected reliably and the app takes over again.
/// The payment itself is finalised on the server (capture), never in the app.
class PaypalCheckoutScreen extends StatefulWidget {
  final int appointmentId;
  final double price;
  const PaypalCheckoutScreen({super.key, required this.appointmentId, required this.price});
  @override
  State<PaypalCheckoutScreen> createState() => _PaypalCheckoutScreenState();
}

enum _Stage { creating, approving, capturing, failed }

class _PaypalCheckoutScreenState extends State<PaypalCheckoutScreen> {
  _Stage _stage = _Stage.creating;
  String? _error;
  String? _orderId;
  String? _returnUrl;
  String? _cancelUrl;
  WebViewController? _ctrl;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  Future<void> _createOrder() async {
    setState(() { _stage = _Stage.creating; _error = null; });
    try {
      final order = await context.read<PaymentProvider>().createOrder(widget.appointmentId);
      final approveUrl = order['approveUrl'] as String?;
      _orderId = order['orderId'] as String?;
      _returnUrl = order['returnUrl'] as String?;
      _cancelUrl = order['cancelUrl'] as String?;
      if (approveUrl == null || _orderId == null || _returnUrl == null || _cancelUrl == null) {
        throw Exception('PayPal nije vratio adresu za plaćanje.');
      }
      _ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onProgress: (p) { if (mounted) setState(() => _progress = p); },
          onNavigationRequest: _onNavigation,
        ))
        ..loadRequest(Uri.parse(approveUrl));
      if (mounted) setState(() => _stage = _Stage.approving);
    } catch (e) {
      if (mounted) setState(() { _stage = _Stage.failed; _error = 'Plaćanje nije moguće pokrenuti: $e'; });
    }
  }

  NavigationDecision _onNavigation(NavigationRequest req) {
    if (req.url.startsWith(_returnUrl!)) {
      _capture();
      return NavigationDecision.prevent;
    }
    if (req.url.startsWith(_cancelUrl!)) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaćanje je otkazano. Termin možete platiti kasnije.')));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _capture() async {
    setState(() { _stage = _Stage.capturing; _error = null; });
    try {
      await context.read<PaymentProvider>().capture(_orderId!);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plaćanje uspješno. Termin je potvrđen.')));
    } catch (e) {
      if (mounted) setState(() { _stage = _Stage.failed; _error = 'Naplata nije uspjela: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Plaćanje ${widget.price.toStringAsFixed(2)} EUR')),
      body: switch (_stage) {
        _Stage.creating => const Center(child: CircularProgressIndicator()),
        _Stage.capturing => const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Potvrđujemo uplatu…', style: TextStyle(color: AppColors.muted)),
            ]),
          ),
        _Stage.approving => Column(children: [
            if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
            Expanded(child: WebViewWidget(controller: _ctrl!)),
          ]),
        _Stage.failed => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 24),
              const IconSquare(Icons.error_outline, size: 64, iconSize: 30, color: Color(0xFFC62828), background: Color(0xFFFDECEA)),
              const SizedBox(height: 16),
              Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC62828))),
              const SizedBox(height: 24),
              GradientButton(label: 'Pokušaj ponovo', icon: Icons.refresh, onPressed: _createOrder),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Nazad na termine')),
            ]),
          ),
      },
    );
  }
}
