class AppEnv {
  AppEnv._();

  static const String supabaseUrl = 'https://degsxoyvgofwbbckvbll.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlZ3N4b3l2Z29md2JiY2t2YmxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2OTUzMzAsImV4cCI6MjA3NjI3MTMzMH0.uPaZyoWGKfYVDdJmgmQV2Rj0OtDGSoAQvrpo2Eu0J_U';

  // Opcional: defina o UUID do venue para associar floorplans/tables quando não há usuário autenticado.
  // Ex.: '3a8d6b58-1234-4f6c-9a01-abcdefabcdef'
  static const String venueId = '';

  // Base URL para montar o payload do QR. Se vazio, o QR conterá apenas o token.
  // Exemplo recomendado: 'https://seu-dominio/scan' e o app/website lê o parâmetro 't'.
  // Produção (GitHub Pages)
  static const String qrBaseUrl = 'https://wlpereira.github.io/Pedido/#/pedido';
}
