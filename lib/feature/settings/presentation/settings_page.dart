import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/providers.dart';
import '../../../core/constants.dart';

const _privacyUrl = 'https://mscanner.net/IR/privacy_policy_ko.html';

Future<void> _openPrivacy(BuildContext context) async {
  final uri = Uri.parse(_privacyUrl);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('개인정보처리방침 페이지를 열 수 없어요.')),
    );
  }
}

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    // 앱 버전 정보
    final versionFuture = useMemoized(PackageInfo.fromPlatform);
    final versionSnap = useFuture(versionFuture);

    final versionText = () {
      final p = versionSnap.data;
      if (p == null) return '버전 정보를 불러오는 중...';
      return 'v${p.version}+${p.buildNumber}';
    }();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('에러: $e')),
        data: (s) {
          return ListView(
            children: [
              // 앱 정보 (Ratelens + 앱 아이콘, 버전만 표시)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app_icon.png', // 앱 아이콘 자산
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                title: const Text('Ratelens'),
                subtitle: Text('버전 $versionText'),
                // onTap 제거 → 아무 동작 없음
              ),
              const Divider(height: 1),

              // 개인정보처리방침
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('개인정보처리방침'),
                subtitle: Text(
                  _privacyUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openPrivacy(context),
              ),
              const Divider(height: 1),

              // $ 기본 해석 통화
              ListTile(
                title: const Text(r'$ 기본 해석'),
                subtitle: Text(s.dollarDefault),
                trailing: DropdownButton<String>(
                  value: s.dollarDefault,
                  items: kDollarDefaultOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(settingsProvider.notifier).setDollarDefault(v);
                  },
                ),
              ),

              // 원문 통화 자동 추정
              SwitchListTile(
                title: const Text('원문 통화 자동 추정'),
                value: s.autoInferSourceCurrency,
                onChanged: (v) {
                  ref.read(settingsProvider.notifier).setAutoInferSourceCurrency(v);
                },
              ),

              // 결과(표시) 통화
              ListTile(
                title: const Text('결과(표시) 통화'),
                subtitle: Text(s.displayCurrency),
                trailing: DropdownButton<String>(
                  value: s.displayCurrency,
                  items: kSupportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(settingsProvider.notifier).setDisplayCurrency(v);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
