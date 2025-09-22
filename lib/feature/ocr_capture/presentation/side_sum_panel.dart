import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../calc/application/calc_notifier.dart';
import '../../rates/application/rates_notifier.dart';
import '../../settings/application/settings_notifier.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/di/providers.dart';        // calcProvider, ratesProvider, settingsProvider
import '../../ocr_capture/domain/entities.dart'; // (간혹 필요)

class SideSumPanel extends HookConsumerWidget {
  const SideSumPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(calcProvider);
    final rates = ref.watch(ratesProvider);
    final settings = ref.watch(settingsProvider);

    final display = settings.value?.displayCurrency ?? 'KRW';
    final sum = (rates.value==null)
        ? 0.0
        : calc.sumInDisplay(rates.value!, display);

    return Container(
      width: 180,
      color: Colors.black.withOpacity(.45),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('합계 ($display)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(formatDisplay(sum, display), style: const TextStyle(color: Colors.white, fontSize: 22)),
          const Spacer(),
          ElevatedButton(
            onPressed: ()=>ref.read(calcProvider.notifier).clear(),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}
