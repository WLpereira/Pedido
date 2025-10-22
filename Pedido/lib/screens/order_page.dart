import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/orders/orders_service.dart';
import '../features/map/table_token_service.dart';

class OrderPage extends StatefulWidget {
  final String? token;
  const OrderPage({super.key, this.token});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _nameCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  final _orders = OrdersService();
  final _tokens = TableTokenService();
  String? _tableLabel;
  String? _tableId; // reservado para futuras validações
  bool _loading = true;
  bool _submitting = false;
  String? _resultMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final raw = widget.token ?? GoRouterState.of(context).uri.queryParameters['t'];
    final token = (raw ?? '').trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _resultMessage = 'QR inválido: token ausente';
      });
      return;
    }
    try {
      final table = await _tokens.resolveTableByToken(token);
      setState(() {
        _tableLabel = table?['table_label']?.toString();
        _tableId = table?['table_id']?.toString();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _resultMessage = 'Não foi possível identificar a mesa';
      });
    }
  }

  Future<void> _submit() async {
    final raw = widget.token ?? GoRouterState.of(context).uri.queryParameters['t'];
    final token = (raw ?? '').trim();
    if (token.isEmpty) return;
    final text = _orderCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu pedido')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final id = await _orders.placeOrder(
        token: token,
        customerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        items: [
          {
            'quantity': 1,
            'custom_text': text,
          }
        ],
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = 'Pedido enviado! Código: $id';
      });
      _orderCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fazer Pedido')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_tableLabel != null)
                    Text(
                      'Mesa: ${_tableLabel!}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seu nome (opcional)'
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seu pedido',
                      hintText: 'Ex.: 2x Coca lata, 1x X-burguer sem cebola',
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.send),
                    label: Text(_submitting ? 'Enviando...' : 'Enviar pedido'),
                  ),
                  const SizedBox(height: 16),
                  if (_resultMessage != null)
                    Text(
                      _resultMessage!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
    );
  }
}
