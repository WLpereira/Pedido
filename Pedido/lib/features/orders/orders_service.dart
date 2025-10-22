import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class OrdersService {
  final SupabaseClient _client = AppSupabase.client;

  Future<String> placeOrder({
    required String token,
    String? customerName,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _client.rpc(
      'place_order',
      params: {
        'p_token': token,
        'p_customer_name': customerName ?? '',
        'p_items': items,
      },
    );
    return res as String;
  }

  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final res = await _client.rpc('get_active_orders');
    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _client.rpc(
      'update_order_status',
      params: {'p_order_id': orderId, 'p_status': status},
    );
  }

  /// Busca pedidos por status diretamente nas tabelas (fallback quando RPC não existir)
  Future<List<Map<String, dynamic>>> getOrdersByStatus(String status) async {
    try {
      final rows = await _client
          .from('orders')
          .select('id, status, table_id, tables(label), order_items(quantity, menu_item_name, custom_text)')
          .eq('status', status)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => {
                'order_id': r['id'],
                'status': r['status'],
                'table_id': r['table_id'],
                'table_label': (r['tables']?['label']) ?? '',
                'items': (r['order_items'] as List?)?.map((it) => {
                      'quantity': it['quantity'] ?? 1,
                      'menu_item_name': it['menu_item_name'],
                      'custom_text': it['custom_text'],
                    }).toList() ?? <Map<String, dynamic>>[],
              })
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
