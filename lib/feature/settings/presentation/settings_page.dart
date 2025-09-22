import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/constants.dart'; // kDollarDefaultOptions, kSupportedCurrencies

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: settings.when(
        loading: ()=>const Center(child:CircularProgressIndicator()),
        error: (e, _)=>Center(child: Text('에러: $e')),
        data: (s){
          return ListView(
            children: [
              const ListTile(title: Text('앱 정보'), subtitle: Text('Currency OCR / v0.1.0')),
              const Divider(),

              // $ 기본 해석 통화
              ListTile(
                title: const Text(r'$ 기본 해석'),
                subtitle: Text(s.dollarDefault),
                trailing: DropdownButton<String>(
                  value: s.dollarDefault,
                  items: kDollarDefaultOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v){
                    if (v == null) return;
                    // ✅ 부분 저장 + 상태 갱신 (setter 사용)
                    ref.read(settingsProvider.notifier).setDollarDefault(v);
                  },
                ),
              ),

              // 자동 추론 스위치
              SwitchListTile(
                title: const Text('원문 통화 자동 추정'),
                value: s.autoInferSourceCurrency,
                onChanged: (v){
                  // ✅ 부분 저장 + 상태 갱신 (setter 사용)
                  ref.read(settingsProvider.notifier).setAutoInferSourceCurrency(v);
                },
              ),

              // 표시 통화
              ListTile(
                title: const Text('결과(표시) 통화'),
                subtitle: Text(s.displayCurrency),
                trailing: DropdownButton<String>(
                  value: s.displayCurrency,
                  items: kSupportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v){
                    if (v == null) return;
                    // ✅ 부분 저장 + 상태 갱신 (setter 사용)
                    ref.read(settingsProvider.notifier).setDisplayCurrency(v);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
