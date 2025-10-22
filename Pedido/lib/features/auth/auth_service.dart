import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';

class AuthService {
  final SupabaseClient _client = AppSupabase.client;

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _client.rpc(
      'login_usuario',
      params: {'p_username': username, 'p_password': password},
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<void> logout() async {
    await _client.rpc('logout_usuario');
  }
}
