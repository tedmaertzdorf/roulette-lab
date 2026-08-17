import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/roulette_number_badge.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/entities/roulette_number_meta.dart';
import '../../../domain/entities/spin.dart';
import '../../../domain/services/analytics/pattern_recognizer.dart';

class PatternRecognizerCard extends StatelessWidget {
  const PatternRecognizerCard({
    required this.spins,
    required this.animationsEnabled,
    super.key,
  });

  final List<Spin> spins;
  final bool animationsEnabled;

  @override
  Widget build(BuildContext context) {
    final PatternReport report = const PatternRecognizer().analyze(spins);
    return SectionCard(
      key: const Key('pattern-recognizer-card'),
      title: AppStrings.patternRecognizer,
      subtitle: AppStrings.patternAnalyzedSpins(
        report.spinsAnalyzed,
        report.totalSpinCount,
      ),
      trailing: _PatternStatus(report: report),
      child: Semantics(
        liveRegion: true,
        container: true,
        label: AppStrings.patternRecognizerSubtitle,
        child: AnimatedSwitcher(
          duration: animationsEnabled
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          child: Column(
            key: ValueKey<String>(
              '${report.totalSpinCount}-'
              '${report.signals.map((PatternSignal signal) => '${signal.kind.index}:${signal.feature.index}:${signal.span}').join(',')}',
            ),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!report.hasEnoughData)
                _EmptyPatternState(
                  icon: Icons.manage_search_rounded,
                  message: AppStrings.patternNeedsMoreSpins(
                    PatternReport.minimumSpinCount - report.totalSpinCount,
                  ),
                )
              else if (report.signals.isEmpty)
                const _EmptyPatternState(
                  icon: Icons.blur_on_rounded,
                  message: AppStrings.noStablePattern,
                )
              else
                for (
                  int index = 0;
                  index < report.signals.length;
                  index++
                ) ...<Widget>[
                  _PatternSignalTile(signal: report.signals[index]),
                  if (index != report.signals.length - 1)
                    const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      AppStrings.patternDisclaimer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternStatus extends StatelessWidget {
  const _PatternStatus({required this.report});

  final PatternReport report;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool active = report.signals.isNotEmpty;
    return Tooltip(
      message: active
          ? AppStrings.patternRecognizerSubtitle
          : AppStrings.noStablePattern,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              active ? Icons.auto_graph_rounded : Icons.radar_rounded,
              size: 18,
              color: active ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              active ? '${report.signals.length}' : '—',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPatternState extends StatelessWidget {
  const _EmptyPatternState({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _PatternSignalTile extends StatelessWidget {
  const _PatternSignalTile({required this.signal});

  final PatternSignal signal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('pattern-signal-${signal.kind.name}-${signal.feature.name}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_iconFor(signal.kind), size: 21, color: colors.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title(signal),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              _StrengthLabel(strength: signal.strength),
            ],
          ),
          const SizedBox(height: 10),
          _PatternSequence(signal: signal),
          const SizedBox(height: 9),
          Text(_description(signal)),
          const SizedBox(height: 10),
          Semantics(
            label:
                '${AppStrings.patternEvidenceStrength}: '
                '${AppStrings.percentage(signal.strength)}, '
                '${AppStrings.patternEvidence(signal.span, signal.repeats)}',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          AppStrings.patternEvidenceStrength,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Text(
                        AppStrings.patternEvidence(signal.span, signal.repeats),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: signal.strength,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrengthLabel extends StatelessWidget {
  const _StrengthLabel({required this.strength});

  final double strength;

  @override
  Widget build(BuildContext context) {
    final String label = strength >= 0.75
        ? AppStrings.patternStrong
        : strength >= 0.6
        ? AppStrings.patternClear
        : AppStrings.patternEmerging;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PatternSequence extends StatelessWidget {
  const _PatternSequence({required this.signal});

  final PatternSignal signal;

  @override
  Widget build(BuildContext context) {
    if (signal.feature == PatternFeature.number) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final int number in signal.sequence)
            RouletteNumberBadge(number: number, size: 32),
          const Icon(Icons.repeat_rounded, size: 18),
        ],
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (
          int index = 0;
          index < signal.sequence.length;
          index++
        ) ...<Widget>[
          _ValueChip(
            label: _featureValue(signal.feature, signal.sequence[index]),
          ),
          if (index != signal.sequence.length - 1)
            const Icon(Icons.arrow_forward_rounded, size: 16),
        ],
        const Icon(Icons.repeat_rounded, size: 18),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

String _title(PatternSignal signal) => switch (signal.kind) {
  PatternKind.exactCycle => AppStrings.exactCycleTitle(signal.sequence.length),
  PatternKind.categoryAlternation => AppStrings.categoryAlternationTitle(
    _featureLabel(signal.feature),
  ),
  PatternKind.categoryStreak => AppStrings.categoryStreakTitle(
    _featureLabel(signal.feature),
  ),
  PatternKind.wheelCycle => AppStrings.wheelCycleTitle(signal.sequence.length),
};

String _description(PatternSignal signal) => switch (signal.kind) {
  PatternKind.exactCycle => AppStrings.exactCycleDescription(
    signal.span,
    signal.repeats,
  ),
  PatternKind.categoryAlternation => AppStrings.categoryAlternationDescription(
    _featureValue(signal.feature, signal.sequence.first),
    _featureValue(signal.feature, signal.sequence.last),
    signal.span,
  ),
  PatternKind.categoryStreak => AppStrings.categoryStreakDescription(
    _featureValue(signal.feature, signal.sequence.single),
    signal.span,
    _featureLabel(signal.feature),
  ),
  PatternKind.wheelCycle => AppStrings.wheelCycleDescription(
    signal.span - 1,
    signal.repeats,
  ),
};

IconData _iconFor(PatternKind kind) => switch (kind) {
  PatternKind.exactCycle => Icons.repeat_on_rounded,
  PatternKind.categoryAlternation => Icons.swap_horiz_rounded,
  PatternKind.categoryStreak => Icons.stacked_line_chart_rounded,
  PatternKind.wheelCycle => Icons.rotate_right_rounded,
};

String _featureLabel(PatternFeature feature) => switch (feature) {
  PatternFeature.number => 'getal',
  PatternFeature.color => 'kleur',
  PatternFeature.parity => 'even/oneven',
  PatternFeature.range => 'laag/hoog',
  PatternFeature.dozen => 'dozijn',
  PatternFeature.column => 'kolom',
  PatternFeature.wheelStep => 'wielstap',
};

String _featureValue(PatternFeature feature, int value) => switch (feature) {
  PatternFeature.color => switch (RouletteColor.values[value]) {
    RouletteColor.green => AppStrings.greenLower,
    RouletteColor.red => AppStrings.redLower,
    RouletteColor.black => AppStrings.blackLower,
  },
  PatternFeature.parity => switch (RouletteParity.values[value]) {
    RouletteParity.neutral => AppStrings.neutralLower,
    RouletteParity.even => AppStrings.evenLower,
    RouletteParity.odd => AppStrings.oddLower,
  },
  PatternFeature.range => switch (RouletteRange.values[value]) {
    RouletteRange.neutral => AppStrings.neutralLower,
    RouletteRange.low => AppStrings.lowLower,
    RouletteRange.high => AppStrings.highLower,
  },
  PatternFeature.dozen => '${value}e dozijn',
  PatternFeature.column => '${value}e kolom',
  PatternFeature.wheelStep =>
    value == 0
        ? '0'
        : value > 0
        ? '+$value ↻'
        : '${value.abs()} ↺',
  PatternFeature.number => '$value',
};
