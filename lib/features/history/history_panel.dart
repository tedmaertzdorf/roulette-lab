import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/roulette_number_badge.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/roulette_number_meta.dart';
import '../../domain/entities/spin.dart';
import '../settings/data_actions.dart';

class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({required this.spins, this.height = 650, super.key});

  final List<Spin> spins;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final List<Spin> ordered = settings.historyOrder == HistoryOrder.newestFirst
        ? spins.reversed.toList()
        : spins;
    return SectionCard(
      title: AppStrings.history,
      subtitle: AppStrings.count(spins.length),
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 12),
      trailing: spins.isEmpty
          ? null
          : Tooltip(
              message: AppStrings.clearHistory,
              child: IconButton(
                onPressed: () => _clear(context, ref),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ),
      child: SizedBox(
        height: height,
        child: ordered.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    AppStrings.noHistory,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Scrollbar(
                child: ListView.builder(
                  key: const Key('history-list'),
                  itemCount: ordered.length,
                  itemExtent: 76,
                  itemBuilder: (BuildContext context, int index) =>
                      _HistoryItem(spin: ordered[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showConfirmation(
          context,
          title: AppStrings.clearHistory,
          message: AppStrings.clearHistoryQuestion(spins.length),
        ) ??
        false;
    if (confirmed) {
      await ref.read(appControllerProvider.notifier).clearSpins();
    }
  }
}

class _HistoryItem extends ConsumerWidget {
  const _HistoryItem({required this.spin});

  final Spin spin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouletteNumberMeta meta = RouletteNumberMeta.of(spin.number);
    final DateTime localTime = (spin.occurredAtUtc ?? spin.createdAtUtc)
        .toLocal();
    return Semantics(
      key: Key('history-item-${spin.position}'),
      container: true,
      label: AppStrings.spinLabel(spin.position, spin.number, meta.colorLabel),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          children: <Widget>[
            RouletteNumberBadge(number: spin.number, size: 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.spinTitle(spin.position),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    DateFormat('dd-MM HH:mm').format(localTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: AppStrings.edit,
              child: IconButton(
                key: Key('edit-spin-${spin.position}'),
                onPressed: () => _edit(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
            Tooltip(
              message: AppStrings.delete,
              child: IconButton(
                key: Key('delete-spin-${spin.position}'),
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(
      text: '${spin.number}',
    );
    final int? number = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(AppStrings.editSpinTitle(spin.position)),
        content: TextField(
          key: const Key('edit-spin-input'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: const InputDecoration(labelText: AppStrings.numberHint),
          onSubmitted: (String value) {
            final int? parsed = int.tryParse(value);
            if (parsed != null && parsed >= 0 && parsed <= 36) {
              Navigator.pop(context, parsed);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final int? parsed = int.tryParse(controller.text);
              if (parsed != null && parsed >= 0 && parsed <= 36) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (number != null && spin.id != null) {
      await ref.read(appControllerProvider.notifier).editSpin(spin.id!, number);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showConfirmation(
          context,
          title: AppStrings.delete,
          message: AppStrings.deleteSpinQuestion(spin.position),
        ) ??
        false;
    if (confirmed && spin.id != null) {
      await ref.read(appControllerProvider.notifier).deleteSpin(spin.id!);
    }
  }
}
