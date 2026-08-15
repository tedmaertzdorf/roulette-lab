import 'dart:convert';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/prediction.dart';
import '../../domain/entities/spin.dart';
import '../../domain/repositories/app_repository.dart';

class ImportIssue {
  const ImportIssue({required this.line, required this.message});

  final int line;
  final String message;
}

class ImportPreview {
  const ImportPreview({
    required this.spins,
    required this.issues,
    this.predictions = const <PredictionRecord>[],
    this.settings,
    this.fatalError,
  });

  final List<Spin> spins;
  final List<ImportIssue> issues;
  final List<PredictionRecord> predictions;
  final AppSettings? settings;
  final String? fatalError;

  bool get canImport => fatalError == null && spins.isNotEmpty;
}

class ImportExportService {
  const ImportExportService();

  static const int schemaVersion = 1;
  static const String appVersion = '1.0.0';

  String exportJson(AppSnapshot snapshot, AppSettings settings) {
    final Map<String, Object?> data = <String, Object?>{
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'modelVersions': const <String, int>{
        'wheel_distance': 1,
        'adaptive_ensemble': 1,
      },
      'settings': settings.toJson(),
      'spins': <Map<String, Object?>>[
        for (final Spin spin in snapshot.spins)
          <String, Object?>{
            'position': spin.position,
            'number': spin.number,
            'occurredAtUtc': spin.occurredAtUtc?.toUtc().toIso8601String(),
            'createdAtUtc': spin.createdAtUtc.toUtc().toIso8601String(),
            'updatedAtUtc': spin.updatedAtUtc.toUtc().toIso8601String(),
          },
      ],
      'predictions': <Map<String, Object?>>[
        for (final PredictionRecord record in snapshot.predictions)
          _predictionToJson(record),
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String exportCsv(List<Spin> spins) {
    final StringBuffer output = StringBuffer(
      'position,number,occurred_at_utc\r\n',
    );
    for (final Spin spin in spins) {
      output
        ..write(spin.position)
        ..write(',')
        ..write(spin.number)
        ..write(',')
        ..write(spin.occurredAtUtc?.toUtc().toIso8601String() ?? '')
        ..write('\r\n');
    }
    return output.toString();
  }

  ImportPreview parse(String content) {
    final String normalized = content.replaceFirst('\ufeff', '').trim();
    if (normalized.isEmpty) {
      return const ImportPreview(
        spins: <Spin>[],
        issues: <ImportIssue>[],
        fatalError: 'Het bestand is leeg.',
      );
    }
    return normalized.startsWith('{')
        ? _parseJson(normalized)
        : _parseDelimited(normalized);
  }

  ImportPreview _parseJson(String content) {
    try {
      final Object? decoded = jsonDecode(content);
      if (decoded is! Map<String, Object?>) {
        return const ImportPreview(
          spins: <Spin>[],
          issues: <ImportIssue>[],
          fatalError: 'De JSON-back-up heeft geen geldig hoofdobject.',
        );
      }
      final Object? versionValue = decoded['schemaVersion'];
      if (versionValue is num && versionValue.toInt() > schemaVersion) {
        return ImportPreview(
          spins: const <Spin>[],
          issues: const <ImportIssue>[],
          fatalError:
              'Deze back-up gebruikt schema ${versionValue.toInt()}, maar deze app ondersteunt maximaal schema $schemaVersion.',
        );
      }
      final Object? rawSpins = decoded['spins'];
      if (rawSpins is! List<Object?>) {
        return const ImportPreview(
          spins: <Spin>[],
          issues: <ImportIssue>[],
          fatalError: 'De JSON-back-up bevat geen lijst met draaien.',
        );
      }
      final DateTime now = DateTime.now().toUtc();
      final List<Spin> spins = <Spin>[];
      final List<ImportIssue> issues = <ImportIssue>[];
      for (int i = 0; i < rawSpins.length; i++) {
        final Object? value = rawSpins[i];
        if (value is! Map<String, Object?>) {
          issues.add(
            ImportIssue(line: i + 1, message: 'Draai is geen object.'),
          );
          continue;
        }
        final int? number = _integer(value['number']);
        if (number == null || number < 0 || number > 36) {
          issues.add(
            ImportIssue(
              line: i + 1,
              message: 'Ongeldig nummer; verwacht 0–36.',
            ),
          );
          continue;
        }
        spins.add(
          Spin(
            id: null,
            position: spins.length + 1,
            number: number,
            occurredAtUtc: _date(
              value['occurredAtUtc'] ?? value['occurred_at_utc'],
            ),
            createdAtUtc: _date(value['createdAtUtc']) ?? now,
            updatedAtUtc: _date(value['updatedAtUtc']) ?? now,
          ),
        );
      }
      final List<PredictionRecord> predictions = _parsePredictions(
        decoded['predictions'],
      );
      final Object? settingsValue = decoded['settings'];
      return ImportPreview(
        spins: List<Spin>.unmodifiable(spins),
        issues: List<ImportIssue>.unmodifiable(issues),
        predictions: predictions,
        settings: settingsValue is Map<String, Object?>
            ? AppSettings.fromJson(settingsValue)
            : null,
      );
    } on FormatException catch (error) {
      return ImportPreview(
        spins: const <Spin>[],
        issues: const <ImportIssue>[],
        fatalError: 'Ongeldige JSON: ${error.message}',
      );
    }
  }

  ImportPreview _parseDelimited(String content) {
    final List<String> lines = const LineSplitter().convert(content);
    final List<Spin> spins = <Spin>[];
    final List<ImportIssue> issues = <ImportIssue>[];
    final DateTime now = DateTime.now().toUtc();
    final String first = lines.first.toLowerCase();
    final String delimiter = _detectDelimiter(lines.first);
    final List<String> firstCells = _split(lines.first, delimiter);
    final int numberColumn = firstCells.indexWhere(
      (String value) =>
          value.toLowerCase() == 'number' || value.toLowerCase() == 'nummer',
    );
    final int occurredColumn = firstCells.indexWhere(
      (String value) => value.toLowerCase().contains('occurred'),
    );
    final bool hasHeader = numberColumn >= 0 || first.contains('position');
    for (
      int lineIndex = hasHeader ? 1 : 0;
      lineIndex < lines.length;
      lineIndex++
    ) {
      final String line = lines[lineIndex].trim();
      if (line.isEmpty) {
        continue;
      }
      final List<String> cells = _split(
        line,
        hasHeader ? delimiter : _detectDelimiter(line),
      );
      if (hasHeader) {
        final int column = numberColumn >= 0 ? numberColumn : 1;
        if (column >= cells.length) {
          issues.add(
            ImportIssue(
              line: lineIndex + 1,
              message: 'Kolom met nummer ontbreekt.',
            ),
          );
          continue;
        }
        _appendParsedSpin(
          cells[column],
          lineIndex + 1,
          spins,
          issues,
          now,
          occurredAtUtc: occurredColumn >= 0 && occurredColumn < cells.length
              ? _date(cells[occurredColumn])
              : null,
        );
      } else {
        for (final String cell in cells.where(
          (String value) => value.isNotEmpty,
        )) {
          _appendParsedSpin(cell, lineIndex + 1, spins, issues, now);
        }
      }
    }
    return ImportPreview(
      spins: List<Spin>.unmodifiable(spins),
      issues: List<ImportIssue>.unmodifiable(issues),
    );
  }

  void _appendParsedSpin(
    String raw,
    int line,
    List<Spin> spins,
    List<ImportIssue> issues,
    DateTime now, {
    DateTime? occurredAtUtc,
  }) {
    final int? number = int.tryParse(raw.trim());
    if (number == null || number < 0 || number > 36) {
      issues.add(
        ImportIssue(line: line, message: '“$raw” is geen nummer van 0–36.'),
      );
      return;
    }
    spins.add(
      Spin(
        id: null,
        position: spins.length + 1,
        number: number,
        occurredAtUtc: occurredAtUtc,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
  }
}

String _detectDelimiter(String line) {
  if (line.contains('\t')) {
    return '\t';
  }
  if (line.contains(';')) {
    return ';';
  }
  return line.contains(',') ? ',' : '';
}

List<String> _split(String line, String delimiter) => delimiter.isEmpty
    ? <String>[line.trim()]
    : line.split(delimiter).map((String value) => value.trim()).toList();

int? _integer(Object? value) => value is num
    ? value.toInt()
    : value is String
    ? int.tryParse(value)
    : null;

DateTime? _date(Object? value) => value is String && value.isNotEmpty
    ? DateTime.tryParse(value)?.toUtc()
    : null;

Map<String, Object?> _predictionToJson(PredictionRecord record) =>
    <String, Object?>{
      'engineId': record.engineId,
      'engineName': record.engineName,
      'modelVersion': record.modelVersion,
      'historyFingerprint': record.historyFingerprint,
      'basedOnSpinCount': record.basedOnSpinCount,
      'targetPosition': record.targetPosition,
      'status': record.status.name,
      'predictedNumber': record.predictedNumber,
      'predictedDozen': record.predictedDozen,
      'top3': record.top3,
      'probabilities': record.probabilities,
      'dozenProbabilities': record.dozenProbabilities,
      'diagnostics': record.diagnostics,
      'expertWeights': record.expertWeights,
      'modelStrength': record.modelStrength,
      'actualNumber': record.actualNumber,
      'exactHit': record.exactHit,
      'top3Hit': record.top3Hit,
      'dozenHit': record.dozenHit,
      'logLoss': record.logLoss,
      'brierScore': record.brierScore,
      'createdAtUtc': record.createdAtUtc.toUtc().toIso8601String(),
      'evaluatedAtUtc': record.evaluatedAtUtc?.toUtc().toIso8601String(),
    };

List<PredictionRecord> _parsePredictions(Object? value) {
  if (value is! List<Object?>) {
    return const <PredictionRecord>[];
  }
  final List<PredictionRecord> records = <PredictionRecord>[];
  for (final Object? item in value) {
    if (item is! Map<String, Object?>) {
      continue;
    }
    try {
      final Object? probabilities = item['probabilities'];
      final Object? dozenProbabilities = item['dozenProbabilities'];
      final Object? top3 = item['top3'];
      final Object? diagnostics = item['diagnostics'];
      final Object? weights = item['expertWeights'];
      if (probabilities is! List<Object?> ||
          dozenProbabilities is! List<Object?> ||
          top3 is! List<Object?>) {
        continue;
      }
      records.add(
        PredictionRecord(
          id: null,
          engineId: item['engineId'] as String,
          engineName:
              item['engineName'] as String? ?? item['engineId'] as String,
          modelVersion: (item['modelVersion'] as num).toInt(),
          historyFingerprint: item['historyFingerprint'] as String,
          basedOnSpinCount: (item['basedOnSpinCount'] as num).toInt(),
          targetPosition: (item['targetPosition'] as num).toInt(),
          status: PredictionStatus.values.byName(item['status'] as String),
          predictedNumber: (item['predictedNumber'] as num).toInt(),
          predictedDozen: (item['predictedDozen'] as num?)?.toInt(),
          top3: top3.whereType<num>().map((num n) => n.toInt()).toList(),
          probabilities: probabilities
              .whereType<num>()
              .map((num n) => n.toDouble())
              .toList(),
          dozenProbabilities: dozenProbabilities
              .whereType<num>()
              .map((num n) => n.toDouble())
              .toList(),
          diagnostics: diagnostics is Map<String, Object?>
              ? diagnostics
              : const <String, Object?>{},
          expertWeights: weights is Map<String, Object?>
              ? <String, double>{
                  for (final MapEntry<String, Object?> entry in weights.entries)
                    if (entry.value is num)
                      entry.key: (entry.value! as num).toDouble(),
                }
              : const <String, double>{},
          modelStrength: (item['modelStrength'] as num).toDouble(),
          actualNumber: (item['actualNumber'] as num?)?.toInt(),
          exactHit: item['exactHit'] as bool?,
          top3Hit: item['top3Hit'] as bool?,
          dozenHit: item['dozenHit'] as bool?,
          logLoss: (item['logLoss'] as num?)?.toDouble(),
          brierScore: (item['brierScore'] as num?)?.toDouble(),
          createdAtUtc: _date(item['createdAtUtc']) ?? DateTime.now().toUtc(),
          evaluatedAtUtc: _date(item['evaluatedAtUtc']),
        ),
      );
    } on Object {
      continue;
    }
  }
  return List<PredictionRecord>.unmodifiable(records);
}
