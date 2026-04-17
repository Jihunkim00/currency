import 'package:go_router/go_router.dart';

import '../feature/ocr_capture/presentation/camera_page.dart';
import '../feature/settings/presentation/settings_page.dart';

abstract final class AppRoutes {
  static const homePath = '/';
  static const settingsPath = '/settings';
  static const homeName = 'home';
  static const settingsName = 'settings';
}

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.homePath,
      name: AppRoutes.homeName,
      builder: (context, state) => const CameraPage(),
    ),
    GoRoute(
      path: AppRoutes.settingsPath,
      name: AppRoutes.settingsName,
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);