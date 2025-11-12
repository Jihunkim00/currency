import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/di/providers.dart';        // calcProvider, ratesProvider, settingsProvider
import '../../ocr_capture/domain/entities.dart'; // MoneyCandidate

class SideSumPanel extends HookConsumerWidget {
  const SideSumPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(calcProvider);
    final ratesAsync = ref.watch(ratesProvider);        // AsyncValue<RatesTable>
    final settingsAsync = ref.watch(settingsProvider);  // AsyncValue<AppSettings>

    // 표시 통화: 설정 로딩 전엔 KRW로 대체
    final display = settingsAsync.maybeWhen(
      data: (s) => s.displayCurrency,
      orElse: () => 'KRW',
    );

    // 합계: 환율/설정 둘 다 준비되면 계산, 아니면 0
    final sum = ratesAsync.maybeWhen(
      data: (t) => calc.sumInDisplay(t, display),
      orElse: () => 0.0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      width: 360,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1F2937), // gray-800
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 합계 + 초기화
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '합계 ($display)',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDisplay(sum, display),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => ref.read(calcProvider.notifier).clear(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                child: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),

          // 리스트 타이틀
          Text(
            '항목 상세',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 전부 표시 + 스크롤 가능
          Expanded(
            child: ratesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text('환율 로딩 실패: $e', style: const TextStyle(color: Colors.white70)),
              ),
              data: (rates) {
                if (calc.selected.isEmpty) {
                  return Center(
                    child: Text(
                      '추가된 항목이 없습니다',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  );
                }
                return Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    itemCount: calc.selected.length,
                    separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final MoneyCandidate m = calc.selected[index];
                      final converted = rates.convert(
                        m.sourceCurrency,
                        display,
                        m.amount,
                      );

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white12,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(
                          converted != null
                              ? formatDisplay(converted, display)
                              : '환율 없음',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${m.sourceCurrency} ${m.amount}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        // trailing: IconButton(
                        //   tooltip: '이 항목 제거',
                        //   onPressed: () { /* 필요시 개별 삭제 구현 */ },
                        //   icon: const Icon(Icons.remove_circle_outline, color: Colors.white24),
                        // ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
