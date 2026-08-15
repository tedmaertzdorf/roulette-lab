import 'dart:isolate';

import '../../domain/entities/prediction.dart';
import '../../domain/entities/spin.dart';
import '../../domain/services/evaluation/walk_forward_evaluator.dart';
import '../../domain/services/prediction/prediction_engine.dart';

const int backgroundHistoryThreshold = 500;

Future<PredictionResult> executePrediction(
  PredictionEngine engine,
  List<Spin> history, {
  required bool inBackground,
}) => inBackground
    ? Isolate.run<PredictionResult>(() => engine.predict(history))
    : Future<PredictionResult>.sync(() => engine.predict(history));

Future<BacktestReport> executeBacktest(
  WalkForwardEvaluator evaluator,
  PredictionEngine engine,
  List<Spin> history, {
  required bool inBackground,
}) => inBackground
    ? Isolate.run<BacktestReport>(() => evaluator.evaluate(engine, history))
    : Future<BacktestReport>.sync(() => evaluator.evaluate(engine, history));
