import 'package:go_router/go_router.dart';
import '../feature/ocr_capture/presentation/camera_page.dart'; // ✅ presentation (철자 주의)
import '../feature/settings/presentation/settings_page.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const CameraPage()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
  ],
);
