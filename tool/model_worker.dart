import 'dart:convert';
import 'dart:js_interop';

import 'package:roulette_lab/domain/entities/prediction.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/services/evaluation/walk_forward_evaluator.dart';
import 'package:roulette_lab/domain/services/prediction/adaptive_ensemble_engine.dart';
import 'package:roulette_lab/domain/services/prediction/prediction_engine.dart';
import 'package:roulette_lab/domain/services/prediction/wheel_distance_engine.dart';
import 'package:web/web.dart' as web;

@JS('self')
external web.DedicatedWorkerGlobalScope get _workerScope;

void main() {
  _workerScope.onmessage = ((web.Event event) {
    try {
      final web.MessageEvent message = event as web.MessageEvent;
      final Object? decoded = jsonDecode((message.data as JSString).toDart);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Ongeldig modelworkerverzoek.');
      }
      _workerScope.postMessage(jsonEncode(_execute(decoded)).toJS);
    } on Object catch (error, stackTrace) {
      _workerScope.postMessage(
        jsonEncode(<String, Object?>{
          'error': '$error',
          'stack': '$stackTrace',
        }).toJS,
      );
    }
  }).toJS;
}

Map<String, Object?> _execute(Map<String, Object?> request) {
  final PredictionEngine engine = switch (request['engineId']) {
    'wheel_distance' => const WheelDistanceEngine(),
    'adaptive_ensemble' => const AdaptiveEnsembleEngine(),
    _ => throw ArgumentError.value(request['engineId'], 'engineId'),
  };
  final List<int> numbers = (request['numbers']! as List<Object?>)
      .whereType<num>()
      .map((num value) => value.toInt())
      .toList(growable: false);
  final DateTime epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final List<Spin> history = <Spin>[
    for (int index = 0; index < numbers.length; index++)
      Spin(
        id: index + 1,
        position: index + 1,
        number: numbers[index],
        createdAtUtc: epoch,
        updatedAtUtc: epoch,
      ),
  ];

  if (request['operation'] == 'prediction') {
    return _predictionToMap(engine.predict(history));
  }
  if (request['operation'] == 'backtest') {
    final int minimumTrainingLength =
        (request['minimumTrainingLength'] as num?)?.toInt() ?? 20;
    return _backtestToMap(
      WalkForwardEvaluator(
        minimumTrainingLength: minimumTrainingLength,
      ).evaluate(engine, history),
    );
  }
  throw ArgumentError.value(request['operation'], 'operation');
}

Map<String, Object?> _predictionToMap(PredictionResult result) =>
    <String, Object?>{
      'engineId': result.engineId,
      'engineName': result.engineName,
      'modelVersion': result.modelVersion,
      'probabilities': result.probabilities,
      'historyFingerprint': result.historyFingerprint,
      'sampleCount': result.sampleCount,
      'diagnostics': result.diagnostics,
      'expertWeights': result.expertWeights,
      'modelStrength': result.modelStrength,
    };

Map<String, Object?> _backtestToMap(BacktestReport report) => <String, Object?>{
  'engineId': report.engineId,
  'points': <Map<String, Object?>>[
    for (final BacktestPoint point in report.points)
      <String, Object?>{
        'targetPosition': point.targetPosition,
        'actualNumber': point.actualNumber,
        'predictedNumber': point.predictedNumber,
        'top3': point.top3,
        'exactHit': point.exactHit,
        'top3Hit': point.top3Hit,
        'dozenHit': point.dozenHit,
        'logLoss': point.logLoss,
        'brierScore': point.brierScore,
        'uniformImprovement': point.uniformImprovement,
      },
  ],
};
