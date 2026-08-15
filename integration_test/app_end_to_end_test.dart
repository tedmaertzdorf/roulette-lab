import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:roulette_lab/app/app.dart';
import 'package:roulette_lab/app/providers.dart';
import 'package:roulette_lab/data/import_export/import_export_service.dart';
import 'package:roulette_lab/domain/entities/app_settings.dart';
import 'package:roulette_lab/domain/entities/prediction.dart';
import 'package:roulette_lab/domain/repositories/app_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('invoer, voorspelling, evaluatie, herstart en back-up', (
    WidgetTester tester,
  ) async {
    ProviderContainer container = await _startApp(tester);
    await container.read(appControllerProvider.notifier).clearAllData();
    await container
        .read(settingsProvider.notifier)
        .save(
          const AppSettings(animationsEnabled: false, hapticsEnabled: false),
        );
    await _settle(tester);

    for (final int number in const <int>[0, 21, 30, 24]) {
      await _tapNumber(tester, number);
      await _settle(tester);
    }
    AppSnapshot snapshot = container.read(appControllerProvider).requireValue;
    expect(snapshot.spins.map((spin) => spin.number), <int>[0, 21, 30, 24]);

    final Finder predict = find.byKey(const Key('predict-next-button'));
    await tester.ensureVisible(predict);
    await tester.tap(predict);
    await _settle(tester, cycles: 20);
    snapshot = container.read(appControllerProvider).requireValue;
    expect(
      snapshot.predictions.where(
        (PredictionRecord record) => record.status == PredictionStatus.active,
      ),
      hasLength(2),
    );

    await _tapNumber(tester, 29);
    await _settle(tester);
    snapshot = container.read(appControllerProvider).requireValue;
    expect(snapshot.spins, hasLength(5));
    expect(
      snapshot.predictions.where(
        (PredictionRecord record) =>
            record.status == PredictionStatus.evaluated,
      ),
      hasLength(2),
    );

    const ImportExportService importExport = ImportExportService();
    final String backup = importExport.exportJson(
      snapshot,
      await container.read(settingsProvider.future),
    );
    final preview = importExport.parse(backup);
    expect(preview.spins.map((spin) => spin.number), <int>[0, 21, 30, 24, 29]);
    expect(preview.issues, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    container = await _startApp(tester);
    snapshot = await container.read(appControllerProvider.future);
    expect(snapshot.spins.map((spin) => spin.number), <int>[0, 21, 30, 24, 29]);
    expect(
      snapshot.predictions.where(
        (PredictionRecord record) =>
            record.status == PredictionStatus.evaluated,
      ),
      hasLength(2),
    );
    await container.read(appControllerProvider.notifier).clearAllData();
  });
}

Future<ProviderContainer> _startApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: RouletteLabApp()));
  await _settle(tester);
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(RouletteLabApp)),
  );
  await container.read(appControllerProvider.future);
  await container.read(settingsProvider.future);
  await _settle(tester);
  return container;
}

Future<void> _tapNumber(WidgetTester tester, int number) async {
  final Finder tile = find.byKey(Key('number-tile-$number'));
  await tester.ensureVisible(tile);
  await tester.pump();
  await tester.tap(find.descendant(of: tile, matching: find.byType(InkWell)));
}

Future<void> _settle(WidgetTester tester, {int cycles = 10}) async {
  for (int i = 0; i < cycles; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
