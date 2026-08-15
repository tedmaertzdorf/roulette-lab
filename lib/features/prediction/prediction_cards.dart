import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/roulette_number_badge.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/prediction.dart';

class PredictionSection extends ConsumerStatefulWidget {
  const PredictionSection({required this.predictions, super.key});

  final List<PredictionRecord> predictions;

  @override
  ConsumerState<PredictionSection> createState() => _PredictionSectionState();
}

class _PredictionSectionState extends ConsumerState<PredictionSection> {
  bool _calculating = false;

  @override
  Widget build(BuildContext context) {
    final List<PredictionRecord> visible = <PredictionRecord>[];
    for (final String engineId in const <String>[
      'wheel_distance',
      'adaptive_ensemble',
    ]) {
      final List<PredictionRecord> records = widget.predictions
          .where(
            (PredictionRecord record) =>
                record.engineId == engineId &&
                record.status != PredictionStatus.invalidated,
          )
          .toList();
      if (records.isNotEmpty) {
        visible.add(records.last);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          key: const Key('predict-next-button'),
          onPressed: _calculating ? null : _predict,
          icon: _calculating
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.science_outlined),
          label: Text(
            _calculating ? AppStrings.predicting : AppStrings.predictNext,
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const SectionCard(
            title: AppStrings.experimentalSignal,
            child: Text(AppStrings.noPrediction),
          )
        else
          for (int i = 0; i < visible.length; i++) ...<Widget>[
            PredictionCard(record: visible[i]),
            if (i != visible.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _predict() async {
    setState(() => _calculating = true);
    try {
      await ref.read(appControllerProvider.notifier).predictNext();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.error(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _calculating = false);
      }
    }
  }
}

class PredictionCard extends StatelessWidget {
  const PredictionCard({required this.record, super.key});

  final PredictionRecord record;

  @override
  Widget build(BuildContext context) {
    final double topProbability = record.probabilities[record.predictedNumber];
    final String quality = record.basedOnSpinCount < 10
        ? AppStrings.veryLittleData
        : record.basedOnSpinCount < 30
        ? AppStrings.littleData
        : AppStrings.moreHistoryAvailable;
    return SectionCard(
      key: Key('prediction-${record.engineId}'),
      title: record.engineName,
      subtitle: AppStrings.modelVersion(
        record.modelVersion,
        record.basedOnSpinCount,
      ),
      trailing: Chip(
        avatar: Icon(
          record.status == PredictionStatus.active
              ? Icons.schedule
              : Icons.fact_check_outlined,
          size: 17,
        ),
        label: Text(
          record.status == PredictionStatus.active
              ? AppStrings.active
              : AppStrings.evaluated,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              RouletteNumberBadge(number: record.predictedNumber, size: 68),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.modelEstimate,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      AppStrings.percentage(topProbability),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      AppStrings.estimateReference(topProbability),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(AppStrings.top3, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              for (final int number in record.top3)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    RouletteNumberBadge(number: number, size: 34),
                    const SizedBox(width: 5),
                    Text(AppStrings.percentage(record.probabilities[number])),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.topDozenLabel(
              record.predictedDozen ?? 0,
              record.dozenProbabilities[record.predictedDozen ?? 0],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              for (int dozen = 1; dozen <= 3; dozen++)
                Chip(
                  label: Text(
                    AppStrings.dozenScore(
                      dozen,
                      record.dozenProbabilities[dozen],
                    ),
                  ),
                ),
              Chip(
                label: Text(AppStrings.zeroScore(record.dozenProbabilities[0])),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${AppStrings.zeroHasNoDozen} ${AppStrings.topNumberDozenNote}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: Text(AppStrings.qualityStrength(quality))),
              Text(AppStrings.percentage(record.modelStrength)),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: record.modelStrength, minHeight: 7),
          if (record.status == PredictionStatus.evaluated) ...<Widget>[
            const Divider(height: 28),
            _Evaluation(record: record),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _showExplanation(context),
                icon: const Icon(Icons.help_outline),
                label: const Text(AppStrings.whyThisResult),
              ),
              TextButton.icon(
                onPressed: () => _showDistribution(context),
                icon: const Icon(Icons.grid_view),
                label: const Text(AppStrings.fullDistribution),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showExplanation(BuildContext context) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(
        AppStrings.modelDialogTitle(
          record.engineName,
          AppStrings.whyThisResult,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final MapEntry<String, Object?> entry
                  in record.diagnostics.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${_readable(entry.key)}: ${entry.value}'),
                ),
              const Divider(),
              Text(
                AppStrings.expertWeights,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final MapEntry<String, double> entry
                  in record.expertWeights.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(entry.key)),
                      Text(AppStrings.percentage(entry.value)),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              const Text(AppStrings.disclaimer),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.close),
        ),
      ],
    ),
  );

  Future<void> _showDistribution(BuildContext context) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(
        AppStrings.modelDialogTitle(
          record.engineName,
          AppStrings.fullDistribution,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: GridView.builder(
          shrinkWrap: true,
          itemCount: 37,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisExtent: 54,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (BuildContext context, int number) => Row(
            children: <Widget>[
              RouletteNumberBadge(number: number, size: 34),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  AppStrings.percentage(record.probabilities[number]),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.close),
        ),
      ],
    ),
  );
}

class _Evaluation extends StatelessWidget {
  const _Evaluation({required this.record});

  final PredictionRecord record;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        AppStrings.actualOutcome,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Row(
        children: <Widget>[
          RouletteNumberBadge(number: record.actualNumber ?? 0),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _ResultChip(
                  label: AppStrings.exactHit,
                  hit: record.exactHit ?? false,
                ),
                _ResultChip(
                  label: AppStrings.top3Hit,
                  hit: record.top3Hit ?? false,
                ),
                _ResultChip(
                  label: AppStrings.dozenHit,
                  hit: record.dozenHit ?? false,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(AppStrings.metricPair(record.logLoss, record.brierScore)),
    ],
  );
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label, required this.hit});

  final String label;
  final bool hit;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      hit ? Icons.check_circle_outline : Icons.cancel_outlined,
      size: 18,
    ),
    label: Text(AppStrings.resultLabel(label, hit)),
  );
}

String _readable(String key) {
  final String spaced = key.replaceAllMapped(
    RegExp('([a-z])([A-Z])'),
    (Match match) => '${match.group(1)} ${match.group(2)}',
  );
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
