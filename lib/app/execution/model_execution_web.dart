import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../domain/entities/prediction.dart';
import '../../domain/entities/spin.dart';
import '../../domain/services/evaluation/walk_forward_evaluator.dart';
import '../../domain/services/prediction/prediction_engine.dart';

const int backgroundHistoryThreshold = 500;

Future<PredictionResult> executePrediction(
  PredictionEngine engine,
  List<Spin> history, {
  required bool inBackground,
}) async {
  if (!inBackground) {
    return engine.predict(history);
  }
  try {
    final Map<String, Object?> response = await _runWorker(<String, Object?>{
      'operation': 'prediction',
      'engineId': engine.id,
      'numbers': history.map((Spin spin) => spin.number).toList(),
    });
    return PredictionResult(
      engineId: response['engineId']! as String,
      engineName: response['engineName']! as String,
      modelVersion: (response['modelVersion']! as num).toInt(),
      probabilities: _doubles(response['probabilities']),
      historyFingerprint: response['historyFingerprint']! as String,
      sampleCount: (response['sampleCount']! as num).toInt(),
      diagnostics: _objectMap(response['diagnostics']),
      expertWeights: _doubleMap(response['expertWeights']),
      modelStrength: (response['modelStrength']! as num).toDouble(),
    );
  } on Object {
    // A missing worker during an unbuilt `flutter run` session must not make
    // the feature unavailable. Production builds always include the worker.
    return engine.predict(history);
  }
}

Future<BacktestReport> executeBacktest(
  WalkForwardEvaluator evaluator,
  PredictionEngine engine,
  List<Spin> history, {
  required bool inBackground,
}) async {
  if (!inBackground) {
    return evaluator.evaluate(engine, history);
  }
  try {
    final Map<String, Object?> response = await _runWorker(<String, Object?>{
      'operation': 'backtest',
      'engineId': engine.id,
      'minimumTrainingLength': evaluator.minimumTrainingLength,
      'numbers': history.map((Spin spin) => spin.number).toList(),
    });
    final Object? rawPoints = response['points'];
    final List<BacktestPoint> points = <BacktestPoint>[
      if (rawPoints is List<Object?>)
        for (final Object? value in rawPoints)
          if (value is Map<String, Object?>)
            BacktestPoint(
              targetPosition: (value['targetPosition']! as num).toInt(),
              actualNumber: (value['actualNumber']! as num).toInt(),
              predictedNumber: (value['predictedNumber']! as num).toInt(),
              top3: _ints(value['top3']),
              exactHit: value['exactHit']! as bool,
              top3Hit: value['top3Hit']! as bool,
              dozenHit: value['dozenHit']! as bool,
              logLoss: (value['logLoss']! as num).toDouble(),
              brierScore: (value['brierScore']! as num).toDouble(),
              uniformImprovement: (value['uniformImprovement']! as num)
                  .toDouble(),
            ),
    ];
    return BacktestReport.fromPoints(response['engineId']! as String, points);
  } on Object {
    return evaluator.evaluate(engine, history);
  }
}

Future<Map<String, Object?>> _runWorker(Map<String, Object?> request) {
  final Completer<Map<String, Object?>> completer =
      Completer<Map<String, Object?>>();
  final web.Worker worker = web.Worker('model_worker.js'.toJS);
  Timer? timeout;

  void fail(Object error) {
    if (!completer.isCompleted) {
      worker.terminate();
      timeout?.cancel();
      completer.completeError(error);
    }
  }

  worker.onmessage = ((web.Event event) {
    try {
      final web.MessageEvent message = event as web.MessageEvent;
      final Object? decoded = jsonDecode((message.data as JSString).toDart);
      if (decoded is! Map<String, Object?>) {
        fail(const FormatException('Ongeldig antwoord van modelworker.'));
        return;
      }
      if (decoded['error'] case final String error) {
        fail(StateError(error));
        return;
      }
      if (!completer.isCompleted) {
        worker.terminate();
        timeout?.cancel();
        completer.complete(decoded);
      }
    } on Object catch (error) {
      fail(error);
    }
  }).toJS;
  worker.onerror = ((web.Event event) {
    fail(StateError('De modelworker kon niet worden gestart.'));
  }).toJS;
  timeout = Timer(
    const Duration(minutes: 5),
    () => fail(TimeoutException('De modelberekening duurde te lang.')),
  );
  worker.postMessage(jsonEncode(request).toJS);
  return completer.future;
}

List<int> _ints(Object? value) => value is List<Object?>
    ? value.whereType<num>().map((num item) => item.toInt()).toList()
    : <int>[];

List<double> _doubles(Object? value) => value is List<Object?>
    ? value.whereType<num>().map((num item) => item.toDouble()).toList()
    : <double>[];

Map<String, Object?> _objectMap(Object? value) =>
    value is Map<String, Object?> ? value : <String, Object?>{};

Map<String, double> _doubleMap(Object? value) => value is Map<String, Object?>
    ? <String, double>{
        for (final MapEntry<String, Object?> entry in value.entries)
          if (entry.value is num) entry.key: (entry.value! as num).toDouble(),
      }
    : <String, double>{};
