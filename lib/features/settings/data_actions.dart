import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../data/import_export/import_export_service.dart';
import '../../data/import_export/local_file_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_repository.dart';

enum _ImportChoice { append, replace }

Future<void> exportJsonBackup(BuildContext context, WidgetRef ref) async {
  try {
    final AppSnapshot snapshot = await ref.read(appControllerProvider.future);
    final AppSettings settings = await ref.read(settingsProvider.future);
    final String content = ref
        .read(importExportServiceProvider)
        .exportJson(snapshot, settings);
    final bool saved = await ref
        .read(localFileServiceProvider)
        .saveText(
          suggestedName:
              'roulette_lab_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
          content: content,
          mimeType: 'application/json',
        );
    if (context.mounted) {
      _message(
        context,
        saved ? AppStrings.savedLocally : AppStrings.operationCancelled,
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _message(context, AppStrings.error(error));
    }
  }
}

Future<void> exportCsvData(BuildContext context, WidgetRef ref) async {
  try {
    final AppSnapshot snapshot = await ref.read(appControllerProvider.future);
    final String content = ref
        .read(importExportServiceProvider)
        .exportCsv(snapshot.spins);
    final bool saved = await ref
        .read(localFileServiceProvider)
        .saveText(
          suggestedName:
              'roulette_spins_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
          content: content,
          mimeType: 'text/csv',
        );
    if (context.mounted) {
      _message(
        context,
        saved ? AppStrings.savedLocally : AppStrings.operationCancelled,
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      _message(context, AppStrings.error(error));
    }
  }
}

Future<void> importLocalData(BuildContext context, WidgetRef ref) async {
  try {
    final LocalFileService fileService = ref.read(localFileServiceProvider);
    final ({String name, String content})? opened = await fileService
        .openImportFile();
    if (opened == null || !context.mounted) {
      return;
    }
    final ImportPreview preview = ref
        .read(importExportServiceProvider)
        .parse(opened.content);
    if (preview.fatalError != null) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text(AppStrings.importData),
          content: Text(preview.fatalError!),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.close),
            ),
          ],
        ),
      );
      return;
    }
    final _ImportChoice? choice = await showDialog<_ImportChoice>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(opened.name),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.importSummary(
                    preview.spins.length,
                    preview.issues.length,
                  ),
                ),
                if (preview.issues.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  for (final ImportIssue issue in preview.issues.take(8))
                    Text(AppStrings.issueLine(issue.line, issue.message)),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton.tonal(
            onPressed: preview.canImport
                ? () => Navigator.pop(context, _ImportChoice.append)
                : null,
            child: const Text(AppStrings.appendHistory),
          ),
          FilledButton(
            onPressed: preview.canImport
                ? () => Navigator.pop(context, _ImportChoice.replace)
                : null,
            child: const Text(AppStrings.replaceHistory),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) {
      return;
    }
    if (choice == _ImportChoice.replace) {
      final int currentCount = (await ref.read(
        appControllerProvider.future,
      )).spins.length;
      if (!context.mounted) {
        return;
      }
      final bool confirmed =
          await showConfirmation(
            context,
            title: AppStrings.replaceHistory,
            message: AppStrings.clearHistoryQuestion(currentCount),
          ) ??
          false;
      if (!confirmed) {
        return;
      }
    }
    await ref
        .read(appControllerProvider.notifier)
        .importPreview(preview, replace: choice == _ImportChoice.replace);
    if (choice == _ImportChoice.replace && preview.settings != null) {
      await ref.read(settingsProvider.notifier).save(preview.settings!);
    }
    if (context.mounted) {
      _message(context, AppStrings.savedLocally);
    }
  } on Object catch (error) {
    if (context.mounted) {
      _message(context, AppStrings.error(error));
    }
  }
}

Future<bool?> showConfirmation(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<bool>(
  context: context,
  builder: (BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text(AppStrings.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text(AppStrings.confirm),
      ),
    ],
  ),
);

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
