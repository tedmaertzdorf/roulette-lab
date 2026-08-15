import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_repository.dart';
import 'data_actions.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSettings> settingsState = ref.watch(settingsProvider);
    final AsyncValue<AppSnapshot> appState = ref.watch(appControllerProvider);
    return settingsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) =>
          Center(child: Text(AppStrings.error(error))),
      data: (AppSettings settings) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SectionCard(
                  title: AppStrings.settings,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        AppStrings.theme,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AppThemeMode>(
                        segments: const <ButtonSegment<AppThemeMode>>[
                          ButtonSegment<AppThemeMode>(
                            value: AppThemeMode.system,
                            label: Text(AppStrings.system),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment<AppThemeMode>(
                            value: AppThemeMode.light,
                            label: Text(AppStrings.light),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<AppThemeMode>(
                            value: AppThemeMode.dark,
                            label: Text(AppStrings.dark),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: <AppThemeMode>{settings.themeMode},
                        onSelectionChanged: (Set<AppThemeMode> value) => _save(
                          ref,
                          settings.copyWith(themeMode: value.first),
                        ),
                      ),
                      const Divider(height: 28),
                      DropdownButtonFormField<HistoryOrder>(
                        initialValue: settings.historyOrder,
                        decoration: const InputDecoration(
                          labelText: AppStrings.historyOrder,
                        ),
                        items: const <DropdownMenuItem<HistoryOrder>>[
                          DropdownMenuItem<HistoryOrder>(
                            value: HistoryOrder.newestFirst,
                            child: Text(AppStrings.newestFirst),
                          ),
                          DropdownMenuItem<HistoryOrder>(
                            value: HistoryOrder.oldestFirst,
                            child: Text(AppStrings.oldestFirst),
                          ),
                        ],
                        onChanged: (HistoryOrder? value) {
                          if (value != null) {
                            _save(ref, settings.copyWith(historyOrder: value));
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue:
                            <int>[0, 30, 100].contains(settings.analysisWindow)
                            ? settings.analysisWindow
                            : 0,
                        decoration: const InputDecoration(
                          labelText: AppStrings.analysisWindow,
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(AppStrings.all),
                          ),
                          DropdownMenuItem<int>(
                            value: 30,
                            child: Text(AppStrings.last30),
                          ),
                          DropdownMenuItem<int>(
                            value: 100,
                            child: Text(AppStrings.last100),
                          ),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            _save(
                              ref,
                              settings.copyWith(analysisWindow: value),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(AppStrings.recentWindows),
                        subtitle: Text(settings.recentWindows.join(' · ')),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _editWindows(context, ref, settings),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(AppStrings.animations),
                        value: settings.animationsEnabled,
                        onChanged: (bool value) => _save(
                          ref,
                          settings.copyWith(animationsEnabled: value),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(AppStrings.haptics),
                        value: settings.hapticsEnabled,
                        onChanged: (bool value) => _save(
                          ref,
                          settings.copyWith(hapticsEnabled: value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: AppStrings.dataManagement,
                  child: Column(
                    children: <Widget>[
                      _ActionTile(
                        icon: Icons.upload_file_outlined,
                        title: AppStrings.exportJson,
                        onTap: () => exportJsonBackup(context, ref),
                      ),
                      _ActionTile(
                        icon: Icons.table_view_outlined,
                        title: AppStrings.exportCsv,
                        onTap: () => exportCsvData(context, ref),
                      ),
                      _ActionTile(
                        icon: Icons.download_for_offline_outlined,
                        title: AppStrings.importData,
                        onTap: () => importLocalData(context, ref),
                      ),
                      _ActionTile(
                        icon: Icons.model_training_outlined,
                        title: AppStrings.rebuildModels,
                        onTap: () => _rebuild(context, ref),
                      ),
                      _ActionTile(
                        icon: Icons.cleaning_services_outlined,
                        title: AppStrings.clearEvaluations,
                        onTap: () => _clearPredictions(context, ref),
                      ),
                      _ActionTile(
                        icon: Icons.delete_forever_outlined,
                        title: AppStrings.clearAllData,
                        destructive: true,
                        onTap: () => _clearAllData(
                          context,
                          ref,
                          appState.value?.spins.length ?? 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: AppStrings.privacyOffline,
                  subtitle: AppStrings.versionInfo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(AppStrings.localPrivacyExplanation),
                      const SizedBox(height: 12),
                      const Text(AppStrings.disclaimer),
                      const SizedBox(height: 12),
                      Text(
                        AppStrings.modelLimitationExplanation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, AppSettings settings) =>
      ref.read(settingsProvider.notifier).save(settings);

  Future<void> _editWindows(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: settings.recentWindows.join(', '),
    );
    final List<int>? windows = await showDialog<List<int>>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.recentWindows),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.text,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[0-9,; ]')),
          ],
          decoration: const InputDecoration(
            labelText: AppStrings.windowExample,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final List<int> parsed =
                  controller.text
                      .split(RegExp('[,; ]+'))
                      .map(int.tryParse)
                      .whereType<int>()
                      .where((int value) => value > 0 && value <= 10000)
                      .toSet()
                      .toList()
                    ..sort();
              if (parsed.isNotEmpty && parsed.length <= 8) {
                Navigator.pop(context, parsed);
              }
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (windows != null) {
      await _save(ref, settings.copyWith(recentWindows: windows));
    }
  }

  Future<void> _rebuild(BuildContext context, WidgetRef ref) async {
    await ref.read(appControllerProvider.notifier).rebuildModels();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.savedLocally)));
    }
  }

  Future<void> _clearPredictions(BuildContext context, WidgetRef ref) async {
    final bool confirmed =
        await showConfirmation(
          context,
          title: AppStrings.clearEvaluations,
          message: AppStrings.clearPredictionQuestion,
        ) ??
        false;
    if (confirmed) {
      await ref.read(appControllerProvider.notifier).clearPredictions();
    }
  }

  Future<void> _clearAllData(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final bool confirmed =
        await showConfirmation(
          context,
          title: AppStrings.clearAllData,
          message: AppStrings.clearHistoryQuestion(count),
        ) ??
        false;
    if (confirmed) {
      await ref.read(appControllerProvider.notifier).clearAllData();
      await ref.read(settingsProvider.notifier).save(const AppSettings());
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color? color = destructive
        ? Theme.of(context).colorScheme.error
        : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
