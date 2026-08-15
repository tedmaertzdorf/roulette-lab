import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/math/hashing.dart';
import '../data/database/app_database.dart';
import '../data/import_export/import_export_service.dart';
import '../data/import_export/local_file_service.dart';
import '../data/preferences/settings_store.dart';
import '../data/repositories/sqlite_app_repository.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/prediction.dart';
import '../domain/entities/spin.dart';
import '../domain/repositories/app_repository.dart';
import '../domain/services/evaluation/walk_forward_evaluator.dart';
import '../domain/services/prediction/adaptive_ensemble_engine.dart';
import '../domain/services/prediction/prediction_engine.dart';
import '../domain/services/prediction/wheel_distance_engine.dart';
import 'execution/model_execution.dart';

final FutureProvider<AppDatabase> appDatabaseProvider =
    FutureProvider<AppDatabase>((Ref ref) async {
      final AppDatabase database = await AppDatabase.production();
      ref.onDispose(database.close);
      return database;
    });

final FutureProvider<AppRepository> appRepositoryProvider =
    FutureProvider<AppRepository>((Ref ref) async {
      final AppDatabase database = await ref.watch(appDatabaseProvider.future);
      return SqliteAppRepository(database);
    });

final FutureProvider<SettingsStore> settingsStoreProvider =
    FutureProvider<SettingsStore>((Ref ref) => SettingsStore.create());

final Provider<ImportExportService> importExportServiceProvider =
    Provider<ImportExportService>((Ref ref) => const ImportExportService());

final Provider<LocalFileService> localFileServiceProvider =
    Provider<LocalFileService>((Ref ref) => const LocalFileService());

final AsyncNotifierProvider<AppController, AppSnapshot> appControllerProvider =
    AsyncNotifierProvider<AppController, AppSnapshot>(AppController.new);

class AppController extends AsyncNotifier<AppSnapshot> {
  Future<void> _mutationQueue = Future<void>.value();
  int _generation = 0;

  @override
  Future<AppSnapshot> build() async {
    final AppRepository repository = await ref.watch(
      appRepositoryProvider.future,
    );
    return repository.loadSnapshot();
  }

  Future<void> addSpin(int number, {DateTime? occurredAtUtc}) => _enqueue(
    (AppRepository repository) =>
        repository.addSpin(number, occurredAtUtc: occurredAtUtc),
  );

  Future<void> editSpin(int id, int number, {DateTime? occurredAtUtc}) =>
      _enqueue(
        (AppRepository repository) =>
            repository.editSpin(id, number, occurredAtUtc: occurredAtUtc),
      );

  Future<void> deleteSpin(int id) =>
      _enqueue((AppRepository repository) => repository.deleteSpin(id));

  Future<void> undoLastSpin() async {
    final Spin? last = state.value?.spins.lastOrNull;
    if (last?.id != null) {
      await deleteSpin(last!.id!);
    }
  }

  Future<void> clearSpins() =>
      _enqueue((AppRepository repository) => repository.clearSpins());

  Future<void> clearAllData() =>
      _enqueue((AppRepository repository) => repository.clearAllData());

  Future<void> clearPredictions() => _enqueue(
    (AppRepository repository) => repository.clearPredictionEvaluations(),
  );

  Future<void> importPreview(ImportPreview preview, {required bool replace}) =>
      _enqueue(
        (AppRepository repository) => repository.importSpins(
          preview.spins,
          replace: replace,
          predictions: replace
              ? preview.predictions
              : const <PredictionRecord>[],
        ),
      );

  Future<void> predictNext() async {
    final AppSnapshot? snapshot = state.value;
    if (snapshot == null) {
      return;
    }
    final List<int> immutableNumbers = List<int>.unmodifiable(
      snapshot.spins.map((Spin spin) => spin.number),
    );
    final String sourceFingerprint = historyFingerprint(immutableNumbers);
    final int generation = _generation;
    final List<PredictionRecord> existing = snapshot.predictions
        .where(
          (PredictionRecord record) =>
              record.status == PredictionStatus.active &&
              record.targetPosition == snapshot.spins.length + 1,
        )
        .toList();
    if (existing
            .map((PredictionRecord record) => record.engineId)
            .toSet()
            .length ==
        2) {
      return;
    }
    final List<PredictionResult> results = await Future.wait(
      const <PredictionEngine>[
        WheelDistanceEngine(),
        AdaptiveEnsembleEngine(),
      ].map(
        (PredictionEngine engine) => executePrediction(
          engine,
          snapshot.spins,
          inBackground: snapshot.spins.length >= backgroundHistoryThreshold,
        ),
      ),
    );
    final AppSnapshot? current = state.value;
    if (generation != _generation ||
        current == null ||
        historyFingerprint(current.spins.map((Spin spin) => spin.number)) !=
            sourceFingerprint) {
      return;
    }
    final AppRepository repository = await ref.read(
      appRepositoryProvider.future,
    );
    await repository.saveActivePredictions(<PredictionRecord>[
      for (final PredictionResult result in results)
        PredictionRecord.fromResult(
          result: result,
          targetPosition: snapshot.spins.length + 1,
        ),
    ]);
    if (generation == _generation) {
      state = AsyncData<AppSnapshot>(await repository.loadSnapshot());
    }
  }

  Future<void> rebuildModels() async {
    final int targetPosition = (state.value?.spins.length ?? 0) + 1;
    await _enqueue(
      (AppRepository repository) =>
          repository.invalidatePredictionsFrom(targetPosition),
    );
    await predictNext();
  }

  Future<void> _enqueue(
    Future<void> Function(AppRepository repository) mutation,
  ) {
    final Completer<void> completer = Completer<void>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        _generation++;
        final AppRepository repository = await ref.read(
          appRepositoryProvider.future,
        );
        await mutation(repository);
        state = AsyncData<AppSnapshot>(await repository.loadSnapshot());
        completer.complete();
      } on Object catch (error, stackTrace) {
        state = AsyncError<AppSnapshot>(error, stackTrace);
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final SettingsStore store = await ref.watch(settingsStoreProvider.future);
    return store.load();
  }

  Future<void> save(AppSettings settings) async {
    state = AsyncData<AppSettings>(settings);
    final SettingsStore store = await ref.read(settingsStoreProvider.future);
    await store.save(settings);
  }
}

final NotifierProvider<NavigationController, int> navigationProvider =
    NotifierProvider<NavigationController, int>(NavigationController.new);

class NavigationController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final NotifierProvider<SelectedNumberController, int?> selectedNumberProvider =
    NotifierProvider<SelectedNumberController, int?>(
      SelectedNumberController.new,
    );

class SelectedNumberController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int number) => state = number;

  void clear() => state = null;
}

final FutureProvider<List<BacktestReport>> backtestProvider =
    FutureProvider<List<BacktestReport>>((Ref ref) async {
      final AppSnapshot snapshot = await ref.watch(
        appControllerProvider.future,
      );
      const WalkForwardEvaluator evaluator = WalkForwardEvaluator();
      Future<BacktestReport> run(PredictionEngine engine) => executeBacktest(
        evaluator,
        engine,
        snapshot.spins,
        inBackground: snapshot.spins.length >= backgroundHistoryThreshold,
      );
      return Future.wait(<Future<BacktestReport>>[
        run(const WheelDistanceEngine()),
        run(const AdaptiveEnsembleEngine()),
      ]);
    });
