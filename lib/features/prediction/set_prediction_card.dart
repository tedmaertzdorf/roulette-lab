import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/widgets/roulette_number_badge.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/prediction.dart';
import '../../domain/entities/roulette_bet_set.dart';
import '../../domain/entities/spin.dart';
import '../../domain/services/analytics/bet_set_analyzer.dart';

class SetPredictionCard extends StatelessWidget {
  const SetPredictionCard({
    required this.spins,
    required this.predictions,
    super.key,
  });

  final List<Spin> spins;
  final List<PredictionRecord> predictions;

  @override
  Widget build(BuildContext context) {
    final BetSetAnalysisReport report = const BetSetAnalyzer().analyze(
      history: spins,
      predictions: predictions,
    );
    return SectionCard(
      key: const Key('set-prediction-card'),
      title: AppStrings.setPrediction,
      subtitle: AppStrings.setPredictionSubtitle,
      trailing: const Icon(Icons.hub_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget model = _RecommendationPanel(
                key: const Key('set-recommendation-model'),
                method: _SetMethod.model,
                assessment: report.modelRecommendation,
                alternatives: report.modelAssessments.skip(1).take(2).toList(),
                source: AppStrings.modelSetSource(report.modelCount),
              );
              final Widget pattern = _RecommendationPanel(
                key: const Key('set-recommendation-pattern'),
                method: _SetMethod.pattern,
                assessment: report.patternRecommendation,
                alternatives: report.patternAssessments
                    .skip(1)
                    .take(2)
                    .toList(),
                source: AppStrings.patternSetSource(report.spinsAnalyzed),
              );
              if (constraints.maxWidth >= 600) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: model),
                    const SizedBox(width: 12),
                    Expanded(child: pattern),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[model, const SizedBox(height: 12), pattern],
              );
            },
          ),
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
                  AppStrings.setAnalysisDisclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SetMethod { model, pattern }

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({
    required this.method,
    required this.assessment,
    required this.alternatives,
    required this.source,
    super.key,
  });

  final _SetMethod method;
  final BetSetAssessment? assessment;
  final List<BetSetAssessment> alternatives;
  final String source;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isModel = method == _SetMethod.model;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isModel
            ? colors.primaryContainer.withValues(alpha: 0.48)
            : colors.tertiaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: assessment == null
          ? _EmptyRecommendation(method: method)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      isModel
                          ? Icons.calculate_outlined
                          : Icons.auto_graph_rounded,
                      size: 20,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        isModel
                            ? AppStrings.probabilityCalculation
                            : AppStrings.patternCalculation,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isModel
                      ? AppStrings.highestModelCoverage
                      : AppStrings.strongestPatternFit,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  _setName(assessment!.set),
                  key: Key('set-${method.name}-winner-${assessment!.set.id}'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Metric(
                        label: isModel
                            ? AppStrings.estimatedCoverage
                            : AppStrings.patternWeightedCoverage,
                        value: AppStrings.percentage(
                          assessment!.estimatedCoverage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Metric(
                        label: AppStrings.comparedWithFair,
                        value: AppStrings.signedPercentage(
                          assessment!.relativeLift,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${AppStrings.fairCoverage}: '
                  '${AppStrings.setCoverageReference(assessment!.set.numbers.length, assessment!.set.fairCoverage)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.coveredNumbers,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: <Widget>[
                    for (final int number in assessment!.set.numbers)
                      RouletteNumberBadge(number: number, size: 28),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${AppStrings.setEvidence} · $source',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Text(
                      AppStrings.percentage(assessment!.evidenceStrength),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: assessment!.evidenceStrength,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (alternatives.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 11),
                  Text(
                    AppStrings.alternatives,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final BetSetAssessment alternative in alternatives)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${_setName(alternative.set)} · '
                            '${isModel ? AppStrings.percentage(alternative.estimatedCoverage) : AppStrings.signedPercentage(alternative.relativeLift)}',
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _EmptyRecommendation extends StatelessWidget {
  const _EmptyRecommendation({required this.method});

  final _SetMethod method;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(
        method == _SetMethod.model
            ? Icons.calculate_outlined
            : Icons.auto_graph_rounded,
      ),
      const SizedBox(height: 8),
      Text(
        method == _SetMethod.model
            ? AppStrings.probabilityCalculation
            : AppStrings.patternCalculation,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        method == _SetMethod.model
            ? AppStrings.noSetModel
            : AppStrings.insufficientSetPattern,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 2),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    ],
  );
}

String _setName(RouletteBetSet set) => switch (set.kind) {
  RouletteBetSetKind.color =>
    set.id == 'red' ? AppStrings.red : AppStrings.black,
  RouletteBetSetKind.parity =>
    set.id == 'even' ? AppStrings.even : AppStrings.odd,
  RouletteBetSetKind.range => set.id == 'low' ? '1–18' : '19–36',
  RouletteBetSetKind.dozen => '${set.index}e dozijn',
  RouletteBetSetKind.column => '${set.index}e kolom',
  RouletteBetSetKind.voisins => AppStrings.voisinsDuZero,
  RouletteBetSetKind.tiers => AppStrings.tiersDuCylindre,
  RouletteBetSetKind.orphelins => AppStrings.orphelins,
  RouletteBetSetKind.jeuZero => AppStrings.jeuZero,
};
