import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/roulette_number_badge.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/roulette_number_meta.dart';
import '../../domain/entities/spin.dart';
import '../../domain/services/analytics/roulette_analytics.dart';

class NumberDetailsCard extends ConsumerWidget {
  const NumberDetailsCard({
    required this.spins,
    required this.number,
    this.lastN,
    super.key,
  });

  final List<Spin> spins;
  final int? number;
  final int? lastN;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (number == null) {
      return const SectionCard(
        title: AppStrings.numberDetails,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(AppStrings.noSelection, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final RouletteNumberMeta meta = RouletteNumberMeta.of(number!);
    final NumberDetails details = numberDetails(spins, number!, lastN: lastN);
    final double overallPercentage = spins.isEmpty
        ? 0
        : details.totalOccurrences / spins.length;
    return SectionCard(
      key: Key('number-details-${number!}'),
      title: AppStrings.numberDetails,
      subtitle: lastN == null ? AppStrings.all : AppStrings.windowTitle(lastN!),
      trailing: RouletteNumberBadge(number: number!, size: 48, selected: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text(meta.colorLabel)),
              Chip(
                label: Text(
                  meta.dozen == null
                      ? AppStrings.noDozen
                      : AppStrings.dozenLabel(meta.dozen!),
                ),
              ),
              Chip(
                label: Text(
                  meta.column == null
                      ? AppStrings.noColumn
                      : AppStrings.columnLabel(meta.column!),
                ),
              ),
              Chip(label: Text(meta.parityLabel)),
              Chip(label: Text(meta.rangeLabel)),
            ],
          ),
          const SizedBox(height: 14),
          _KeyValues(
            values: <String, String>{
              AppStrings.totalFallen: '${details.totalOccurrences}',
              AppStrings.inWindow:
                  '${details.windowOccurrences} · ${AppStrings.percentage(details.percentageInWindow)}',
              AppStrings.inAllData: AppStrings.percentage(overallPercentage),
              AppStrings.uniformBaseline: '2,70%',
              AppStrings.lastSeen: details.lastSeenSpinsAgo == null
                  ? AppStrings.notSeen
                  : AppStrings.lastSeenAgo(details.lastSeenSpinsAgo!),
              if (details.lastSeenAtUtc != null)
                AppStrings.localTime: DateFormat(
                  'dd-MM-yyyy HH:mm',
                ).format(details.lastSeenAtUtc!.toLocal()),
            },
          ),
          const Divider(height: 28),
          Text(AppStrings.gaps, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            details.gaps.isEmpty
                ? AppStrings.minimumTwoOccurrences
                : AppStrings.gapSummary(
                    details.averageGap,
                    details.medianGap,
                    details.minimumGap!,
                    details.maximumGap!,
                  ),
          ),
          if (details.positions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(AppStrings.positionsLabel(details.positions)),
          ],
          const Divider(height: 28),
          _Transitions(
            title: AppStrings.directSuccessors,
            transitions: details.successors.take(5).toList(),
            onSelected: (int value) =>
                ref.read(selectedNumberProvider.notifier).select(value),
          ),
          if (details.pendingSuccessor) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              AppStrings.pendingSuccessor,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (details.recentSuccessors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(AppStrings.successorsLabel(details.recentSuccessors)),
          ],
          const SizedBox(height: 16),
          _Transitions(
            title: AppStrings.directPredecessors,
            transitions: details.predecessors.take(5).toList(),
            onSelected: (int value) =>
                ref.read(selectedNumberProvider.notifier).select(value),
          ),
          const Divider(height: 28),
          Text(
            AppStrings.wheelNeighbors,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final int neighbor in meta.wheelNeighbors)
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => ref
                      .read(selectedNumberProvider.notifier)
                      .select(neighbor),
                  child: RouletteNumberBadge(number: neighbor, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyValues extends StatelessWidget {
  const _KeyValues({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 10,
    children: <Widget>[
      for (final MapEntry<String, String> entry in values.entries)
        SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.key,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                entry.value,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Transitions extends StatelessWidget {
  const _Transitions({
    required this.title,
    required this.transitions,
    required this.onSelected,
  });

  final String title;
  final List<TransitionStat> transitions;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (transitions.isEmpty)
        const Text(AppStrings.noTransition)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final TransitionStat transition in transitions)
              ActionChip(
                avatar: RouletteNumberBadge(
                  number: transition.number,
                  size: 28,
                ),
                label: Text(
                  '${transition.count} · ${AppStrings.percentage(transition.percentage)}',
                ),
                onPressed: () => onSelected(transition.number),
              ),
          ],
        ),
    ],
  );
}
