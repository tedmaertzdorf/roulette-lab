import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/app/app.dart';
import 'package:roulette_lab/app/providers.dart';
import 'package:roulette_lab/data/preferences/settings_store.dart';
import 'package:roulette_lab/domain/entities/app_settings.dart';
import 'package:roulette_lab/domain/entities/prediction.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/repositories/app_repository.dart';
import 'package:roulette_lab/domain/services/evaluation/prediction_scorer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('invoermodus, herhaling, analysemodus en undo werken', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(tester, const Size(1440, 900));

    await _tapNumber(tester, 8);
    await _settle(tester);
    await _tapNumber(tester, 8);
    await _settle(tester);
    AppSnapshot snapshot = harness.container
        .read(appControllerProvider)
        .requireValue;
    expect(
      snapshot.spins.map((spin) => spin.number),
      <int>[8, 8],
      reason:
          'modus=${harness.container.read(settingsProvider).value?.boardMode}, '
          'selectie=${harness.container.read(selectedNumberProvider)}, '
          'snackbars=${find.byType(SnackBar).evaluate().length}',
    );

    final Finder analyzeMode = find.text('Analyseren').first;
    await tester.ensureVisible(analyzeMode);
    await tester.pump();
    await tester.tap(analyzeMode);
    await _settle(tester);
    await _tapNumber(tester, 8);
    await _settle(tester);
    snapshot = harness.container.read(appControllerProvider).requireValue;
    expect(snapshot.spins, hasLength(2));
    expect(harness.container.read(selectedNumberProvider), 8);

    await tester.tap(find.byKey(const Key('undo-last-spin')));
    await _settle(tester);
    snapshot = harness.container.read(appControllerProvider).requireValue;
    expect(snapshot.spins, hasLength(1));
    await harness.dispose(tester);
  });

  testWidgets(
    'beide actieve voorspellingen worden op de volgende draai geëvalueerd',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpApp(
        tester,
        const Size(1440, 900),
        seed: const <int>[0, 21, 30, 24],
      );
      final Finder predict = find.byKey(const Key('predict-next-button'));
      await tester.ensureVisible(predict);
      await tester.tap(predict);
      await _settle(tester, cycles: 20);
      AppSnapshot snapshot = harness.container
          .read(appControllerProvider)
          .requireValue;
      expect(
        snapshot.predictions.where(
          (PredictionRecord record) => record.status == PredictionStatus.active,
        ),
        hasLength(2),
      );

      await _tapNumber(tester, 29);
      await _settle(tester);
      snapshot = harness.container.read(appControllerProvider).requireValue;
      final List<PredictionRecord> evaluated = snapshot.predictions
          .where(
            (PredictionRecord record) =>
                record.status == PredictionStatus.evaluated,
          )
          .toList();
      expect(evaluated, hasLength(2));
      expect(
        evaluated.every((PredictionRecord record) => record.actualNumber == 29),
        isTrue,
      );
      expect(find.textContaining('Log-loss'), findsWidgets);
      await harness.dispose(tester);
    },
  );

  testWidgets(
    'dashboard rendert zonder exceptions op telefoon, tablet en desktop',
    (WidgetTester tester) async {
      final _Harness harness = await _pumpApp(
        tester,
        const Size(360, 800),
        seed: const <int>[1, 2, 3, 0, 36],
      );
      for (final Size size in const <Size>[
        Size(360, 800),
        Size(800, 600),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'Doelgrootte $size');
        expect(find.text('Roulette Lab'), findsWidgets);
      }
      await harness.dispose(tester);
    },
  );

  testWidgets('historie kan worden bewerkt en verwijderd', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(
      tester,
      const Size(1440, 900),
      seed: const <int>[8, 4],
    );
    final Finder edit = find.byKey(const Key('edit-spin-2'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pump();
    await tester.enterText(find.byKey(const Key('edit-spin-input')), '10');
    await tester.tap(find.text('Opslaan').last);
    await _settle(tester);
    AppSnapshot snapshot = harness.container
        .read(appControllerProvider)
        .requireValue;
    expect(snapshot.spins.map((Spin spin) => spin.number), <int>[8, 10]);

    final Finder remove = find.byKey(const Key('delete-spin-1'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    await tester.tap(find.text('Bevestigen').last);
    await _settle(tester);
    snapshot = harness.container.read(appControllerProvider).requireValue;
    expect(snapshot.spins.map((Spin spin) => spin.number), <int>[10]);
    expect(snapshot.spins.single.position, 1);
    await harness.dispose(tester);
  });

  testWidgets('snelle invoer bewaart getallen en houdt toetsenbordfocus', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(tester, const Size(390, 1200));
    final Finder input = find.byKey(const Key('numeric-spin-input'));
    final Finder submit = find.byKey(const Key('quick-spin-submit'));
    await tester.ensureVisible(input);
    await tester.tap(input);
    await tester.enterText(input, '12');
    expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNotNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    EditableText editable = tester.widget<EditableText>(
      find.descendant(of: input, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, isEmpty);
    expect(
      harness.container
          .read(appControllerProvider)
          .requireValue
          .spins
          .map((Spin spin) => spin.number),
      <int>[12],
    );

    await tester.enterText(input, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    editable = tester.widget<EditableText>(
      find.descendant(of: input, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.text, isEmpty);
    expect(
      harness.container
          .read(appControllerProvider)
          .requireValue
          .spins
          .map((Spin spin) => spin.number),
      <int>[12, 7],
    );

    await tester.enterText(input, '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);
    editable = tester.widget<EditableText>(
      find.descendant(of: input, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(
      find.text('Voer een geheel getal van 0 tot en met 36 in.'),
      findsOneWidget,
    );
    expect(
      harness.container.read(appControllerProvider).requireValue.spins,
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets('setanalyse toont kansmodel en patroon naast voorspellingen', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(
      tester,
      const Size(1440, 1100),
      seed: const <int>[1, 2, 3, 1, 2, 3, 1, 2, 3],
    );
    expect(find.byKey(const Key('set-prediction-card')), findsOneWidget);
    expect(find.byKey(const Key('set-recommendation-model')), findsOneWidget);
    expect(find.byKey(const Key('set-recommendation-pattern')), findsOneWidget);
    expect(
      find.text(
        'Bereken eerst de volgende draai om de twee bestaande kansmodellen samen te voegen.',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'set-pattern-winner-',
            ),
      ),
      findsOneWidget,
    );

    final Finder predict = find.byKey(const Key('predict-next-button'));
    await tester.ensureVisible(predict);
    await tester.tap(predict);
    await _settle(tester, cycles: 25);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'set-model-winner-',
            ),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 actieve modellen gecombineerd'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets('geselecteerd getal toont echte opvolgers zonder invoer', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(
      tester,
      const Size(1440, 900),
      seed: const <int>[8, 4, 8, 10, 3],
    );
    await tester.tap(find.text('Analyse').first);
    await _settle(tester);
    final Finder number = find.byKey(const Key('analysis-number-8'));
    await tester.ensureVisible(number);
    await tester.tap(number);
    await _settle(tester);
    expect(find.byKey(const Key('number-details-8')), findsOneWidget);
    expect(find.text('Wat kwam erna?'), findsOneWidget);
    expect(find.textContaining('Laatste opvolgers: 10, 4'), findsOneWidget);
    final AppSnapshot snapshot = harness.container
        .read(appControllerProvider)
        .requireValue;
    expect(snapshot.spins, hasLength(5));
    await harness.dispose(tester);
  });

  testWidgets('nieuwe invoer toont automatisch de eerdere opvolgers', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(
      tester,
      const Size(1440, 1000),
      seed: const <int>[8, 4, 8, 10, 3],
    );

    await _tapNumber(tester, 8);
    await _settle(tester);

    expect(find.byKey(const Key('automatic-successors-8')), findsOneWidget);
    expect(find.text('Na eerdere keren dat 8 viel'), findsOneWidget);
    expect(
      find.text('8 toegevoegd. Eerder direct erna: 10, 4.'),
      findsOneWidget,
    );
    expect(
      find.text('2 bekende overgangen · 2 verschillende getallen'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('automatic-successor-recent-8-0-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('automatic-successor-recent-8-1-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('automatic-successor-stat-8-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('automatic-successor-stat-8-4')),
      findsOneWidget,
    );
    expect(
      find.text('De zojuist ingevoerde 8 wacht nu op zijn eigen opvolger.'),
      findsOneWidget,
    );
    final Finder fullDetails = find.byKey(
      const Key('automatic-successors-details-8'),
    );
    await tester.ensureVisible(fullDetails);
    await tester.tap(fullDetails);
    await _settle(tester);
    expect(harness.container.read(navigationProvider), 1);
    expect(harness.container.read(selectedNumberProvider), 8);
    expect(find.byKey(const Key('number-details-8')), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('eerste voorkomen toont automatisch een nette lege staat', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(tester, const Size(360, 800));

    await _tapNumber(tester, 17);
    await _settle(tester);

    expect(find.byKey(const Key('automatic-successors-17')), findsOneWidget);
    expect(
      find.text('17 toegevoegd. Nog geen eerdere opvolger.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('eerste geregistreerde voorkomen van 17'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets('patroonkaart herberekent direct en wist een verbroken cyclus', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpApp(
      tester,
      const Size(1440, 1000),
      seed: const <int>[1, 2, 3, 1, 2, 3],
    );

    expect(find.byKey(const Key('pattern-recognizer-card')), findsOneWidget);
    expect(
      find.byKey(const Key('pattern-signal-exactCycle-number')),
      findsOneWidget,
    );
    expect(find.text('Herhalende getalcyclus'), findsOneWidget);

    await _tapNumber(tester, 4);
    await _settle(tester);

    expect(
      find.byKey(const Key('pattern-signal-exactCycle-number')),
      findsNothing,
    );
    expect(find.text('7 draaien onderzocht'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets('200% tekstschaal en gelabelde tapdoelen blijven bruikbaar', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    final _Harness harness = await _pumpApp(tester, const Size(800, 900));
    final SemanticsHandle semantics = tester.ensureSemantics();
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await harness.dispose(tester);
  });
}

class _Harness {
  const _Harness({required this.container});

  final ProviderContainer container;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
}

Future<_Harness> _pumpApp(
  WidgetTester tester,
  Size size, {
  List<int> seed = const <int>[],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SettingsStore settingsStore = await SettingsStore.create();
  await settingsStore.save(
    const AppSettings(animationsEnabled: false, hapticsEnabled: false),
  );
  final _MemoryRepository repository = _MemoryRepository(seed);
  final container = ProviderContainer(
    overrides: [
      appRepositoryProvider.overrideWith((Ref ref) async => repository),
      settingsStoreProvider.overrideWith((Ref ref) async => settingsStore),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RouletteLabApp(),
    ),
  );
  await container.read(settingsProvider.future);
  await container.read(appControllerProvider.future);
  await _settle(tester);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    container.dispose();
  });
  return _Harness(container: container);
}

Future<void> _settle(WidgetTester tester, {int cycles = 8}) async {
  for (int i = 0; i < cycles; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapNumber(WidgetTester tester, int number) async {
  final Finder tile = find.byKey(Key('number-tile-$number'));
  await tester.ensureVisible(tile);
  await tester.pump();
  final Finder inkWell = find.descendant(
    of: tile,
    matching: find.byType(InkWell),
  );
  await tester.tap(inkWell);
}

class _MemoryRepository implements AppRepository {
  _MemoryRepository(List<int> numbers) {
    final DateTime now = DateTime.utc(2026);
    _spins = <Spin>[
      for (int i = 0; i < numbers.length; i++)
        Spin(
          id: i + 1,
          position: i + 1,
          number: numbers[i],
          createdAtUtc: now.add(Duration(seconds: i)),
          updatedAtUtc: now.add(Duration(seconds: i)),
        ),
    ];
    _nextId = _spins.length + 1;
  }

  late List<Spin> _spins;
  final List<PredictionRecord> _predictions = <PredictionRecord>[];
  int _nextId = 1;

  @override
  Future<void> addSpin(int number, {DateTime? occurredAtUtc}) async {
    final int position = _spins.length + 1;
    for (int i = 0; i < _predictions.length; i++) {
      final PredictionRecord record = _predictions[i];
      if (record.status == PredictionStatus.active &&
          record.targetPosition == position) {
        _predictions[i] = evaluatePrediction(record, number);
      }
    }
    final DateTime now = DateTime.now().toUtc();
    _spins.add(
      Spin(
        id: _nextId++,
        position: position,
        number: number,
        occurredAtUtc: occurredAtUtc,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
  }

  @override
  Future<void> clearAllData() async {
    _spins.clear();
    _predictions.clear();
  }

  @override
  Future<void> clearPredictionEvaluations() async => _predictions.clear();

  @override
  Future<void> clearSpins() async {
    _spins.clear();
    await invalidatePredictionsFrom(1);
  }

  @override
  Future<void> deleteSpin(int id) async {
    final int index = _spins.indexWhere((Spin spin) => spin.id == id);
    if (index < 0) {
      return;
    }
    final int position = _spins[index].position;
    _spins.removeAt(index);
    _spins = <Spin>[
      for (int i = 0; i < _spins.length; i++)
        _spins[i].copyWith(position: i + 1),
    ];
    await invalidatePredictionsFrom(position);
  }

  @override
  Future<void> editSpin(int id, int number, {DateTime? occurredAtUtc}) async {
    final int index = _spins.indexWhere((Spin spin) => spin.id == id);
    if (index >= 0) {
      _spins[index] = _spins[index].copyWith(
        number: number,
        occurredAtUtc: occurredAtUtc,
      );
      await invalidatePredictionsFrom(index + 1);
    }
  }

  @override
  Future<void> importSpins(
    List<Spin> spins, {
    required bool replace,
    List<PredictionRecord> predictions = const <PredictionRecord>[],
  }) async {
    if (replace) {
      _spins.clear();
      _predictions
        ..clear()
        ..addAll(predictions);
    }
    for (final Spin spin in spins) {
      await addSpin(spin.number, occurredAtUtc: spin.occurredAtUtc);
    }
  }

  @override
  Future<void> invalidatePredictionsFrom(int targetPosition) async {
    for (int i = 0; i < _predictions.length; i++) {
      final PredictionRecord record = _predictions[i];
      if (record.targetPosition >= targetPosition &&
          record.status != PredictionStatus.invalidated) {
        _predictions[i] = PredictionRecord(
          id: record.id,
          engineId: record.engineId,
          engineName: record.engineName,
          modelVersion: record.modelVersion,
          historyFingerprint: record.historyFingerprint,
          basedOnSpinCount: record.basedOnSpinCount,
          targetPosition: record.targetPosition,
          status: PredictionStatus.invalidated,
          predictedNumber: record.predictedNumber,
          predictedDozen: record.predictedDozen,
          top3: record.top3,
          probabilities: record.probabilities,
          dozenProbabilities: record.dozenProbabilities,
          diagnostics: record.diagnostics,
          expertWeights: record.expertWeights,
          modelStrength: record.modelStrength,
          actualNumber: record.actualNumber,
          exactHit: record.exactHit,
          top3Hit: record.top3Hit,
          dozenHit: record.dozenHit,
          logLoss: record.logLoss,
          brierScore: record.brierScore,
          createdAtUtc: record.createdAtUtc,
          evaluatedAtUtc: record.evaluatedAtUtc,
        );
      }
    }
  }

  @override
  Future<AppSnapshot> loadSnapshot() async => AppSnapshot(
    spins: List<Spin>.unmodifiable(_spins),
    predictions: List<PredictionRecord>.unmodifiable(_predictions),
  );

  @override
  Future<List<PredictionRecord>> saveActivePredictions(
    List<PredictionRecord> predictions,
  ) async {
    for (final PredictionRecord prediction in predictions) {
      _predictions.removeWhere(
        (PredictionRecord current) =>
            current.engineId == prediction.engineId &&
            current.status == PredictionStatus.active,
      );
      _predictions.add(prediction);
    }
    return predictions;
  }
}
