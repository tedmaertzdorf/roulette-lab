import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/roulette_number_badge.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/entities/spin.dart';
import '../../../domain/services/analytics/roulette_analytics.dart';

class AutomaticSuccessorsCard extends ConsumerWidget {
  const AutomaticSuccessorsCard({
    required this.spins,
    required this.animationsEnabled,
    super.key,
  });

  final List<Spin> spins;
  final bool animationsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (spins.isEmpty) {
      return const SizedBox.shrink();
    }
    final Spin latest = spins.last;
    final NumberDetails details = numberDetails(spins, latest.number);
    final int transitionCount = details.successors.fold<int>(
      0,
      (int total, TransitionStat transition) => total + transition.count,
    );
    final List<TransitionStat> topSuccessors = details.successors
        .take(5)
        .toList();
    final int hiddenSuccessorCount =
        details.successors.length - topSuccessors.length;

    return AnimatedSwitcher(
      duration: animationsEnabled
          ? const Duration(milliseconds: 220)
          : Duration.zero,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
      child: SectionCard(
        key: ValueKey<String>(
          'automatic-successors-${latest.position}-${latest.number}',
        ),
        title: AppStrings.automaticSuccessors,
        subtitle: AppStrings.automaticSuccessorSubtitle(latest.number),
        trailing: RouletteNumberBadge(
          number: latest.number,
          size: 48,
          selected: true,
        ),
        child: Semantics(
          key: Key('automatic-successors-${latest.number}'),
          liveRegion: true,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (transitionCount == 0)
                _EmptySuccessors(number: latest.number)
              else ...<Widget>[
                Text(
                  AppStrings.automaticSuccessorSummary(
                    transitionCount,
                    details.successors.length,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.recentSuccessorOrder,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (
                      int index = 0;
                      index < details.recentSuccessors.length;
                      index++
                    )
                      Tooltip(
                        message:
                            '${index + 1}. '
                            '${details.recentSuccessors[index]}',
                        child: RouletteNumberBadge(
                          key: Key(
                            'automatic-successor-recent-'
                            '${latest.number}-$index-'
                            '${details.recentSuccessors[index]}',
                          ),
                          number: details.recentSuccessors[index],
                          size: 38,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.mostCommonSuccessors,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final TransitionStat transition in topSuccessors)
                      _SuccessorStatChip(
                        sourceNumber: latest.number,
                        transition: transition,
                      ),
                  ],
                ),
                if (hiddenSuccessorCount > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.otherSuccessors(hiddenSuccessorCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                AppStrings.currentSuccessorPending(latest.number),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('automatic-successors-details-${latest.number}'),
                  onPressed: () {
                    ref
                        .read(selectedNumberProvider.notifier)
                        .select(latest.number);
                    ref.read(navigationProvider.notifier).select(1);
                  },
                  icon: const Icon(Icons.query_stats, size: 18),
                  label: const Text(AppStrings.viewFullNumberDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySuccessors extends StatelessWidget {
  const _EmptySuccessors({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.hourglass_top_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(AppStrings.noAutomaticSuccessors(number))),
      ],
    ),
  );
}

class _SuccessorStatChip extends StatelessWidget {
  const _SuccessorStatChip({
    required this.sourceNumber,
    required this.transition,
  });

  final int sourceNumber;
  final TransitionStat transition;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppStrings.successorStatLabel(
      transition.number,
      transition.count,
      transition.percentage,
    ),
    child: Container(
      key: Key('automatic-successor-stat-$sourceNumber-${transition.number}'),
      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RouletteNumberBadge(number: transition.number, size: 30),
          const SizedBox(width: 6),
          Text(
            '${transition.count}× · '
            '${AppStrings.percentage(transition.percentage)}',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
