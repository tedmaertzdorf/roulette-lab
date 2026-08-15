import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/math/statistics.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/prediction.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/services/evaluation/prediction_scorer.dart';
import '../../domain/services/evaluation/walk_forward_evaluator.dart';

class PerformancePage extends ConsumerWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> app = ref.watch(appControllerProvider);
    final AsyncValue<List<BacktestReport>> backtests = ref.watch(
      backtestProvider,
    );
    return app.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) =>
          Center(child: Text(AppStrings.error(error))),
      data: (AppSnapshot snapshot) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _BaselineCard(),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final List<Widget> cards = <Widget>[
                  _OfficialCard(
                    name: AppStrings.wheelModel,
                    records: snapshot.predictions
                        .where(
                          (PredictionRecord record) =>
                              record.engineId == 'wheel_distance',
                        )
                        .toList(),
                  ),
                  _OfficialCard(
                    name: AppStrings.adaptiveModel,
                    records: snapshot.predictions
                        .where(
                          (PredictionRecord record) =>
                              record.engineId == 'adaptive_ensemble',
                        )
                        .toList(),
                  ),
                ];
                return constraints.maxWidth >= 850
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: cards[0]),
                          const SizedBox(width: 14),
                          Expanded(child: cards[1]),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          cards[0],
                          const SizedBox(height: 14),
                          cards[1],
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
            backtests.when(
              loading: () => const SectionCard(
                title: AppStrings.walkForward,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace stack) => SectionCard(
                title: AppStrings.walkForward,
                child: Text(AppStrings.error(error)),
              ),
              data: (List<BacktestReport> reports) => Column(
                children: <Widget>[
                  for (int i = 0; i < reports.length; i++) ...<Widget>[
                    _BacktestCard(report: reports[i]),
                    if (i != reports.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  const _BaselineCard();

  @override
  Widget build(BuildContext context) => const SectionCard(
    title: AppStrings.uniformBaseline,
    subtitle: AppStrings.fairBaselineDescription,
    child: Wrap(
      spacing: 20,
      runSpacing: 10,
      children: <Widget>[
        _Metric(label: AppStrings.exact, value: '2,70%'),
        _Metric(label: AppStrings.top3Short, value: '8,11%'),
        _Metric(label: AppStrings.dozen, value: '32,43%'),
        _Metric(label: AppStrings.logLoss, value: '3,611'),
        _Metric(label: AppStrings.brierScore, value: '0,973'),
      ],
    ),
  );
}

class _OfficialCard extends StatelessWidget {
  const _OfficialCard({required this.name, required this.records});

  final String name;
  final List<PredictionRecord> records;

  @override
  Widget build(BuildContext context) {
    final PerformanceSummary summary = PerformanceSummary.fromRecords(records);
    final PerformanceSummary rolling50 = PerformanceSummary.fromRecords(
      records.length <= 50 ? records : records.sublist(records.length - 50),
      rollingWindow: 50,
    );
    final PerformanceSummary rolling100 = PerformanceSummary.fromRecords(
      records.length <= 100 ? records : records.sublist(records.length - 100),
      rollingWindow: 100,
    );
    final ({double lower, double upper}) interval = wilsonInterval(
      summary.exactHits,
      summary.evaluationCount,
    );
    final PredictionRecord? latest = records.lastOrNull;
    return SectionCard(
      title: name,
      subtitle: AppStrings.officialPredictions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (summary.evaluationCount == 0)
            const Text(AppStrings.noOfficialEvaluation)
          else ...<Widget>[
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: <Widget>[
                _Metric(
                  label: AppStrings.evaluations,
                  value: '${summary.evaluationCount}',
                ),
                _Metric(
                  label: AppStrings.exact,
                  value: AppStrings.percentage(summary.exactRate),
                ),
                _Metric(
                  label: AppStrings.top3Short,
                  value: AppStrings.percentage(summary.top3Rate),
                ),
                _Metric(
                  label: AppStrings.dozen,
                  value: AppStrings.percentage(summary.dozenRate),
                ),
                _Metric(
                  label: AppStrings.logLoss,
                  value: summary.averageLogLoss.toStringAsFixed(3),
                ),
                _Metric(
                  label: AppStrings.brierScore,
                  value: summary.averageBrierScore.toStringAsFixed(3),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.wilson(interval.lower, interval.upper),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              AppStrings.rollingMetrics(
                summary.rollingLogLoss.last,
                rolling50.averageLogLoss,
                rolling100.averageLogLoss,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (latest != null && latest.expertWeights.isNotEmpty) ...<Widget>[
            const Divider(height: 26),
            Text(
              AppStrings.currentExpertWeights,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final MapEntry<String, double> entry
                in latest.expertWeights.entries)
              Row(
                children: <Widget>[
                  Expanded(child: Text(entry.key)),
                  Text(AppStrings.percentage(entry.value)),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _BacktestCard extends StatelessWidget {
  const _BacktestCard({required this.report});

  final BacktestReport report;

  @override
  Widget build(BuildContext context) {
    final String name = report.engineId == 'wheel_distance'
        ? AppStrings.wheelModel
        : AppStrings.adaptiveModel;
    final String conclusion = report.points.length < 20
        ? AppStrings.insufficientConclusion
        : report.averageLogLoss < 3.61091791264
        ? AppStrings.betterThanUniform
        : AppStrings.worseThanUniform;
    return SectionCard(
      title: AppStrings.backtestTitle(name),
      subtitle: AppStrings.evaluationCount(report.points.length),
      child: report.points.isEmpty
          ? const Text(AppStrings.insufficientBacktest)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: <Widget>[
                    _Metric(
                      label: AppStrings.exact,
                      value: AppStrings.percentage(report.exactRate),
                    ),
                    _Metric(
                      label: AppStrings.top3Short,
                      value: AppStrings.percentage(report.top3Rate),
                    ),
                    _Metric(
                      label: AppStrings.dozen,
                      value: AppStrings.percentage(report.dozenRate),
                    ),
                    _Metric(
                      label: AppStrings.logLoss,
                      value: report.averageLogLoss.toStringAsFixed(3),
                    ),
                    _Metric(
                      label: AppStrings.brierScore,
                      value: report.averageBrierScore.toStringAsFixed(3),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: AppStrings.improvementSemantics(
                    report.cumulativeImprovement,
                  ),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ImprovementPainter(points: report.points),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(conclusion),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 105,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ImprovementPainter extends CustomPainter {
  const _ImprovementPainter({required this.points});

  final List<BacktestPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axis = Paint()
      ..color = Colors.grey.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      axis,
    );
    final List<double> cumulative = <double>[];
    double total = 0;
    for (final BacktestPoint point in points) {
      total += point.uniformImprovement;
      cumulative.add(total);
    }
    final double maximum = cumulative.fold<double>(
      0.1,
      (double value, double next) => value > next.abs() ? value : next.abs(),
    );
    final Path path = Path();
    for (int i = 0; i < cumulative.length; i++) {
      final double x = cumulative.length == 1
          ? 0
          : i / (cumulative.length - 1) * size.width;
      final double y =
          size.height / 2 - cumulative[i] / maximum * size.height * 0.44;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2E9B68)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_ImprovementPainter oldDelegate) =>
      oldDelegate.points != points;
}
