import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../features/orders/orders_service.dart';
import '../features/map/map_service.dart';

class PainelScreen extends StatefulWidget {
  const PainelScreen({super.key});

  @override
  State<PainelScreen> createState() => _PainelScreenState();
}

class _PainelScreenState extends State<PainelScreen>
    with SingleTickerProviderStateMixin {
  final OrdersService _service = OrdersService();
  final MapService _mapService = MapService();

  String? _floorplanImageUrl;
  String? _floorplanId;
  List<Map<String, dynamic>> _tables = [];
  bool _showMap = true; // exibir mapa por padrão
  double _rotation = 0.0; // rotação do mapa em radianos
  List<Map<String, dynamic>> _activeOrders = [];
  Timer? _ordersTimer;
  late final AnimationController _blinkController;
  RealtimeChannel? _ordersChannel;

  // Removido: _load() não é mais usado; usamos loaders específicos por aba

  @override
  void initState() {
    super.initState();
    _blinkController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    // Carregar dados iniciais
    _loadMapData();
    _loadActiveOrders();
  // Realtime de pedidos
  _setupRealtime();
  }

  @override
  void dispose() {
    _ordersTimer?.cancel();
    _blinkController.dispose();
    _ordersChannel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final client = Supabase.instance.client;
    final channel = client.channel('realtime-orders');
    void _cb(PostgresChangePayload _) {
      _loadActiveOrders();
    }
    channel
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'orders',
        callback: _cb,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'orders',
        callback: _cb,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'orders',
        callback: _cb,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'order_items',
        callback: _cb,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'order_items',
        callback: _cb,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'order_items',
        callback: _cb,
      )
      .subscribe();
    _ordersChannel = channel;
  }

  Future<void> _loadMapData() async {
    try {
      final floorplans = await _mapService.getFloorplans();
      if (floorplans.isNotEmpty) {
        final floorplan = floorplans.first;
        final imagePath = floorplan['image_path'] as String?;
        final tables = await _mapService.getTables(floorplan['id']);
        if (mounted) {
          setState(() {
            _floorplanId = floorplan['id']?.toString();
            _floorplanImageUrl = imagePath;
            _tables = tables;
          });
        } else {
          _floorplanId = floorplan['id']?.toString();
          _floorplanImageUrl = imagePath;
          _tables = tables;
        }
      }
    } catch (e) {
      // Ignorar erro se não houver dados
    }
  }

  Future<void> _loadActiveOrders() async {
    try {
      final orders = await _service.getActiveOrders();
      if (mounted) {
        setState(() => _activeOrders = orders);
      } else {
        _activeOrders = orders;
      }
    } catch (_) {
      // Silenciar em DEV
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _rotation -= math.pi / 2;
              });
            },
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            tooltip: 'Girar 90° anti-horário',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _rotation += math.pi / 2;
              });
            },
            icon: const Icon(Icons.rotate_90_degrees_cw),
            tooltip: 'Girar 90° horário',
          ),
          IconButton(
            onPressed: () async {
              await _loadMapData();
              await _loadActiveOrders();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
                if (_showMap) {
                  _loadMapData();
                }
              });
            },
            icon: Icon(_showMap ? Icons.list : Icons.map),
            tooltip: _showMap ? 'Ver Lista' : 'Ver Mapa',
          ),
          IconButton(
            onPressed: () async {
              // Abrir editor e esperar retorno; se salvar, mostrar mapa
              final path = _floorplanId == null
                  ? '/map-editor'
                  : '/map-editor?id=${Uri.encodeComponent(_floorplanId!)}';
              final saved = await context.push<bool>(path);
              if (saved == true && mounted) {
                setState(() {
                  _showMap = true;
                });
                await _loadMapData();
                if (mounted) setState(() {});
              }
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Editor de Mapa',
          ),
          IconButton(
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Escanear QR',
          ),
        ],
      ),
      body: _showMap ? _buildMapView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Pendentes'),
            Tab(text: 'Atendidos'),
          ]),
          Expanded(
            child: TabBarView(
              children: [
                _OrdersList(
                  loader: _service.getActiveOrders,
                  onMarkServed: (id) async {
                    await _service.updateOrderStatus(orderId: id, status: 'served');
                    await _loadActiveOrders();
                    if (mounted) setState(() {});
                  },
                  emptyText: 'Sem pedidos pendentes',
                ),
                _OrdersList(
                  loader: () => _service.getOrdersByStatus('served'),
                  onMarkServed: null,
                  emptyText: 'Sem pedidos atendidos',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_floorplanImageUrl == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum mapa configurado'),
            SizedBox(height: 8),
            Text('Use o Editor de Mapa para criar um layout do salão'),
          ],
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 3.0,
      child: Transform.rotate(
        angle: _rotation,
        child: Stack(
        children: [
          // Imagem de fundo
          _buildFloorplanImage(_floorplanImageUrl!),
          // Mesas posicionadas
          ..._tables.map((table) => _buildTableWidget(table)),
        ],
        ),
      ),
    );
  }

  Widget _buildFloorplanImage(String src) {
    if (src.trim().startsWith('data:image')) {
      final comma = src.indexOf('base64,');
      if (comma != -1) {
        final b64 = src.substring(comma + 7);
        try {
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Center(
              child: Text('Erro ao carregar imagem'),
            ),
          );
        } catch (_) {
          return const Center(child: Text('Imagem inválida'));
        }
      }
    }
    return Image.network(
      src,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          const Center(child: Text('Erro ao carregar imagem')),
    );
  }

  bool _hasActiveOrderForTable(String tableId) {
    return _activeOrders.any((o) => o['table_id'] == tableId && o['status'] != 'served');
  }

  Map<String, dynamic>? _firstOrderForTable(String tableId) {
    try {
      return _activeOrders.firstWhere((o) => o['table_id'] == tableId);
    } catch (_) {
      return null;
    }
  }

  int _countOrdersForTable(String tableId) {
    return _activeOrders
        .where((o) => o['table_id'] == tableId && o['status'] != 'served')
        .length;
  }

  Widget _buildTableWidget(Map<String, dynamic> table) {
    final hasOrder = _hasActiveOrderForTable(table['id']);
    final count = _countOrdersForTable(table['id']);
    final content = _TableMarker(
      label: table['label']?.toString() ?? '',
      highlighted: hasOrder,
      animation: _blinkController,
      count: count,
    );

    return Positioned(
      left: (table['x'] as num).toDouble(),
      top: (table['y'] as num).toDouble(),
      child: GestureDetector(
        onTap: () {
          final order = _firstOrderForTable(table['id']);
          if (order != null) {
            _showOrderDetails(order, table);
          } else {
            _showTableInfo(table);
          }
        },
        child: content,
      ),
    );
  }

  void _showTableInfo(Map<String, dynamic> table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mesa ${table['label']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((table['description']?.toString().trim() ?? '').isNotEmpty)
              Text(table['description']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order, Map<String, dynamic> table) {
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mesa ${table['label']} — Pedido'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (items.isEmpty) const Text('Sem itens'),
              if (items.isNotEmpty)
                ...items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('x${it['quantity'] ?? 1}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              it['menu_item_name'] ?? it['custom_text'] ?? 'Item',
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _service.updateOrderStatus(
                  orderId: order['order_id'],
                  status: 'served',
                );
                await _loadActiveOrders();
                if (mounted) setState(() {});
                // manter no mapa
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro ao atualizar: $e')),
                );
              }
            },
            child: const Text('Marcar atendido'),
          ),
        ],
      ),
    );
  }

}

class _OrdersList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> Function() loader;
  final Future<void> Function(String orderId)? onMarkServed;
  final String emptyText;

  const _OrdersList({
    required this.loader,
    required this.onMarkServed,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: loader(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data ?? [];
        if (data.isEmpty) {
          return Center(child: Text(emptyText));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemBuilder: (c, i) {
            final o = data[i];
            final items = (o['items'] as List?) ?? [];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${o['table_label']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Chip(label: Text('${o['status']}')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final it in items)
                      Row(
                        children: [
                          Text('x${it['quantity']}'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              it['menu_item_name'] ?? it['custom_text'] ?? 'Item',
                            ),
                          ),
                        ],
                      ),
                    if (onMarkServed != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => onMarkServed!(o['order_id']),
                            child: const Text('Marcar atendido'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          separatorBuilder: (c, _) => const SizedBox(height: 8),
          itemCount: data.length,
        );
      },
    );
  }
}

class _TableMarker extends StatelessWidget {
  final String label;
  final bool highlighted;
  final Animation<double> animation;
  final int count;

  const _TableMarker({
    required this.label,
    required this.highlighted,
    required this.animation,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final base = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: highlighted ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      blurRadius: 12,
                      color: Colors.greenAccent.withOpacity(0.5),
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );

    if (!highlighted) return base;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(animation),
      child: base,
    );
  }
}
