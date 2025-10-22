import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'package:uuid/uuid.dart';

class TableTokenService {
  final SupabaseClient _client = AppSupabase.client;

  Future<String> getOrCreateTableToken(String tableId) async {
    // Buscar existente
    try {
      // Preferir token ativo (usa índice parcial)
      final existing = await _client
          .from('table_tokens')
          .select('token')
          .eq('table_id', tableId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      if (existing != null && existing['token'] is String) {
        final t = existing['token'] as String;
        if (t.isNotEmpty) return t;
      }
    } catch (e) {
      // Fallback: se der erro (ex.: coluna não existe), pegar o mais recente
      try {
        final existing = await _client
            .from('table_tokens')
            .select('token, created_at')
            .eq('table_id', tableId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (existing != null && existing['token'] is String) {
          final t = existing['token'] as String;
          if (t.isNotEmpty) return t;
        }
      } catch (_) {}
    }

    // Criar novo
    final token = const Uuid().v4();
    try {
      await _client.from('table_tokens').insert({
        'id': const Uuid().v4(),
        'table_id': tableId,
        'token': token,
        'is_active': true,
      });
      return token;
    } catch (_) {
      // Como fallback, retorna o token gerado (backend pode aceitar diretamente)
      return token;
    }
  }

  /// Regenera o token da mesa: desativa os atuais e cria um novo ativo
  Future<String> regenerateTableToken(String tableId) async {
    final newToken = const Uuid().v4();
    try {
      // Desativar tokens atuais (se a coluna existir)
      try {
        await _client
            .from('table_tokens')
            .update({'is_active': false})
            .eq('table_id', tableId)
            .eq('is_active', true);
      } catch (_) {
        // Se a coluna não existir, apenas segue para inserir novo
      }

      // Inserir novo ativo
      try {
        await _client.from('table_tokens').insert({
          'id': const Uuid().v4(),
          'table_id': tableId,
          'token': newToken,
          'is_active': true,
        });
      } catch (_) {
        // Tentativa sem is_active (caso a coluna não exista)
        await _client.from('table_tokens').insert({
          'id': const Uuid().v4(),
          'table_id': tableId,
          'token': newToken,
        });
      }

      return newToken;
    } catch (e) {
      // Falha inesperada: retorna o token gerado mesmo assim
      return newToken;
    }
  }

  /// Resolve mesa a partir do token (retorna {table_id, table_label})
  Future<Map<String, dynamic>?> resolveTableByToken(String token) async {
    try {
      final tok = await _client
          .from('table_tokens')
          .select('table_id')
          .eq('token', token)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (tok == null || tok['table_id'] == null) return null;
      final tableId = tok['table_id'] as String;
      final table = await _client
          .from('tables')
          .select('id, label, description')
          .eq('id', tableId)
          .maybeSingle();
      if (table == null) return {'table_id': tableId};
      return {
        'table_id': table['id'] ?? tableId,
        'table_label': table['label'],
        'table_description': table['description'],
      };
    } catch (_) {
      return null;
    }
  }
}
