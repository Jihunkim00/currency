import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/currency_format.dart';
import '../../ocr_capture/domain/entities.dart';

class SideSumPanel extends ConsumerStatefulWidget {
  const SideSumPanel({
    super.key,
    required this.displayCurrency,
    required this.selected,
  });

  final String displayCurrency;
  final List<MoneyCandidate> selected;

  @override
  ConsumerState<SideSumPanel> createState() => _SideSumPanelState();
}

class _SideSumPanelState extends ConsumerState<SideSumPanel> {
  MoneyCandidate? _undoItem;


  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(ratesProvider);
    final calc = ref.watch(calcProvider);

    final total = rates.maybeWhen(
      data: (r) => calc.sumInDisplay(r, widget.displayCurrency),
      orElse: () => 0.0,
    );

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected ${widget.selected.length} • ${formatDisplay(total, widget.displayCurrency)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: widget.selected.isEmpty
                      ? null
                      : () {
                    HapticFeedback.selectionClick();
                    ref.read(calcProvider.notifier).clear();
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.selected.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('No items yet. Tap a highlighted amount to add it.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.selected.length,
                  itemBuilder: (context, index) {
                    final item = widget.selected[index];
                    final converted = rates.asData?.value
                        .convert(item.sourceCurrency, widget.displayCurrency, item.amount);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.sourceCurrency} ${item.amount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(converted == null
                          ? 'Rate unavailable'
                          : formatDisplay(converted, widget.displayCurrency)),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Edit amount',
                            onPressed: () => _editAmount(context, index, item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _undoItem = item;

                              ref.read(calcProvider.notifier).removeAt(index);
                              _showUndo(context);
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAmount(BuildContext context, int index, MoneyCandidate item) async {
    final controller = TextEditingController(text: item.amount.toStringAsFixed(2));
    final updated = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correct amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != null && updated > 0) {
      ref.read(calcProvider.notifier).updateAmount(index, updated);
    }
  }

  void _showUndo(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Item removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              final item = _undoItem;
              if (item == null) return;
              ref.read(calcProvider.notifier).add(item);
            },
          ),
        ),
      );
  }
}