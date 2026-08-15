import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/data/import_export/import_export_service.dart';
import 'package:roulette_lab/domain/entities/app_settings.dart';
import 'package:roulette_lab/domain/entities/spin.dart';
import 'package:roulette_lab/domain/repositories/app_repository.dart';

void main() {
  const ImportExportService service = ImportExportService();

  test(
    'JSON-back-up round-trip bewaart chronologische nummers en instellingen',
    () {
      final AppSnapshot snapshot = AppSnapshot(
        spins: spins(<int>[8, 8, 0, 36, 12]),
        predictions: const [],
      );
      const AppSettings settings = AppSettings(
        themeMode: AppThemeMode.light,
        historyOrder: HistoryOrder.oldestFirst,
        analysisWindow: 100,
      );
      final String encoded = service.exportJson(snapshot, settings);
      final ImportPreview preview = service.parse(encoded);
      expect(preview.fatalError, isNull);
      expect(preview.issues, isEmpty);
      expect(preview.spins.map((Spin spin) => spin.number), <int>[
        8,
        8,
        0,
        36,
        12,
      ]);
      expect(preview.settings?.themeMode, AppThemeMode.light);
      expect(preview.settings?.analysisWindow, 100);
    },
  );

  test('CSV round-trip bewaart nummers en datums', () {
    final List<Spin> original = spins(<int>[1, 13, 25, 0]);
    final ImportPreview preview = service.parse(service.exportCsv(original));
    expect(preview.issues, isEmpty);
    expect(preview.spins.map((Spin spin) => spin.number), <int>[1, 13, 25, 0]);
    expect(preview.spins.first.occurredAtUtc, original.first.occurredAtUtc);
  });

  test(
    'tekstformaten, delimiters, lege regels en fouten worden afgehandeld',
    () {
      final ImportPreview preview = service.parse('8\n\n4;10;3\n37\nonzin\n0');
      expect(preview.spins.map((Spin spin) => spin.number), <int>[
        8,
        4,
        10,
        3,
        0,
      ]);
      expect(preview.issues, hasLength(2));
      expect(preview.issues.map((ImportIssue issue) => issue.line), <int>[
        4,
        5,
      ]);
    },
  );

  test('foutieve JSON is fataal en levert geen gedeeltelijke data', () {
    final ImportPreview preview = service.parse('{"spins": [');
    expect(preview.canImport, isFalse);
    expect(preview.spins, isEmpty);
    expect(preview.fatalError, isNotNull);
  });
}

List<Spin> spins(List<int> numbers) {
  final DateTime now = DateTime.utc(2026, 2);
  return <Spin>[
    for (int i = 0; i < numbers.length; i++)
      Spin(
        id: i + 1,
        position: i + 1,
        number: numbers[i],
        occurredAtUtc: now.add(Duration(minutes: i)),
        createdAtUtc: now.add(Duration(minutes: i)),
        updatedAtUtc: now.add(Duration(minutes: i)),
      ),
  ];
}
