import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_strings.dart';
import '../features/analysis/analysis_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/performance/performance_page.dart';
import '../features/settings/data_actions.dart';
import '../features/settings/settings_page.dart';
import 'providers.dart';

enum _DataMenuAction { importData, exportJson, exportCsv }

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static List<NavigationDestination> _destinations({
    required bool compact,
  }) => <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: AppStrings.dashboard,
    ),
    NavigationDestination(
      icon: Icon(Icons.query_stats_outlined),
      selectedIcon: Icon(Icons.query_stats),
      label: AppStrings.analysis,
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: compact ? AppStrings.performanceCompact : AppStrings.performance,
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: compact ? AppStrings.settingsCompact : AppStrings.settings,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selected = ref.watch(navigationProvider);
    final bool canUndo =
        ref.watch(appControllerProvider).value?.spins.isNotEmpty ?? false;
    final List<Widget> pages = const <Widget>[
      DashboardPage(),
      AnalysisPage(),
      PerformancePage(),
      SettingsPage(),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final bool compact = constraints.maxWidth < 430;
        final List<NavigationDestination> destinations = _destinations(
          compact: compact,
        );
        final Widget content = Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.blur_circular,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(child: Text(AppStrings.appName)),
              ],
            ),
            actions: <Widget>[
              if (constraints.maxWidth >= 520)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Chip(
                    avatar: Icon(Icons.lock_outline, size: 15),
                    label: Text(AppStrings.offline),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              IconButton(
                key: const Key('undo-last-spin'),
                tooltip: AppStrings.undo,
                onPressed: canUndo
                    ? () => ref
                          .read(appControllerProvider.notifier)
                          .undoLastSpin()
                    : null,
                icon: const Icon(Icons.undo),
              ),
              PopupMenuButton<_DataMenuAction>(
                tooltip: AppStrings.dataManagement,
                icon: const Icon(Icons.more_vert),
                onSelected: (_DataMenuAction action) =>
                    _handleMenu(context, ref, action),
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<_DataMenuAction>>[
                      PopupMenuItem<_DataMenuAction>(
                        value: _DataMenuAction.importData,
                        child: ListTile(
                          leading: Icon(Icons.download_for_offline_outlined),
                          title: Text(AppStrings.importData),
                        ),
                      ),
                      PopupMenuItem<_DataMenuAction>(
                        value: _DataMenuAction.exportJson,
                        child: ListTile(
                          leading: Icon(Icons.upload_file_outlined),
                          title: Text(AppStrings.exportJson),
                        ),
                      ),
                      PopupMenuItem<_DataMenuAction>(
                        value: _DataMenuAction.exportCsv,
                        child: ListTile(
                          leading: Icon(Icons.table_view_outlined),
                          title: Text(AppStrings.exportCsv),
                        ),
                      ),
                    ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(child: pages[selected]),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selected,
                  labelBehavior: compact
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: destinations,
                  onDestinationSelected: ref
                      .read(navigationProvider.notifier)
                      .select,
                ),
        );
        if (!wide) {
          return content;
        }
        return Row(
          children: <Widget>[
            SafeArea(
              child: NavigationRail(
                selectedIndex: selected,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: ref
                    .read(navigationProvider.notifier)
                    .select,
                destinations: <NavigationRailDestination>[
                  for (final NavigationDestination destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    _DataMenuAction action,
  ) => switch (action) {
    _DataMenuAction.importData => importLocalData(context, ref),
    _DataMenuAction.exportJson => exportJsonBackup(context, ref),
    _DataMenuAction.exportCsv => exportCsvData(context, ref),
  };
}
