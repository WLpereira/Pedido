import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await AppSupabase.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pedido',
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
