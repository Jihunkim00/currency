import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'router/app_router.dart';
import 'package:firebase_core/firebase_core.dart';

/// 전역 Provider 로거
class LogObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
      ProviderBase provider,
      Object? previousValue,
      Object? newValue,
      ProviderContainer container,
      ) {
    if (!kDebugMode) return;
    final name = provider.name ?? provider.runtimeType;
    debugPrint('[Provider] $name updated: $previousValue -> $newValue');
  }

  @override
  void providerDidFail(
      ProviderBase provider,
      Object error,
      StackTrace stackTrace,
      ProviderContainer container,
      ) {
    final name = provider.name ?? provider.runtimeType;
    debugPrint('[Provider][ERROR] $name: $error\n$stackTrace');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase initialize
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // 있으면 사용
  );

  // Flutter 프레임워크 에러도 로깅(옵션)
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(
    ProviderScope(
      observers: [LogObserver()], // ← 여기!
      child: const AppRoot(),
    ),
  );
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});
  @override
  Widget build(BuildContext context) {
    final router = buildRouter();
    return MaterialApp.router(
      title: 'Currency OCR',
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      routerConfig: router,
    );
  }
}
