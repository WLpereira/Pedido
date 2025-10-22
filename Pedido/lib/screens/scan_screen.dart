import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../features/orders/orders_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  final OrdersService _service = OrdersService();
  bool _handling = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    _handling = true;
    try {
      final uri = Uri.tryParse(code);
      final token = uri?.queryParameters['t'] ?? code;
      if (token.isEmpty) return;

      final orderId = await _service.placeOrder(
        token: token,
        customerName: null,
        items: const [],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pedido criado: $orderId')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
