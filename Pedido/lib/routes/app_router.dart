import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/painel_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/map_editor_screen.dart';
import '../screens/order_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/painel',
        builder: (context, state) => const PainelScreen(),
      ),
      GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
      GoRoute(
        path: '/map-editor',
        builder: (context, state) => MapEditorScreen(
          floorplanId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/pedido',
        builder: (context, state) => OrderPage(
          token: state.uri.queryParameters['t'],
        ),
      ),
    ],
  );
}
