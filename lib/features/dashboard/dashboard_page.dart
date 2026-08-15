import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_repository.dart';
import '../analysis/number_details_card.dart';
import '../analysis/recent_statistics_cards.dart';
import '../history/history_panel.dart';
import '../prediction/prediction_cards.dart';
import 'widgets/roulette_board.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AppSnapshot> state = ref.watch(appControllerProvider);
    return state.when(
      loading: () => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(AppStrings.loading),
          ],
        ),
      ),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.storage_outlined, size: 48),
              const SizedBox(height: 12),
              Text(AppStrings.error(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(appControllerProvider),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
      data: (AppSnapshot snapshot) => _DashboardContent(snapshot: snapshot),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.snapshot});

  final AppSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final int? selected = ref.watch(selectedNumberProvider);
    final int? lastN = settings.analysisWindow <= 0
        ? null
        : settings.analysisWindow;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget disclaimer = Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text(AppStrings.disclaimer)),
            ],
          ),
        );
        final Widget board = RouletteBoard(spins: snapshot.spins);
        final Widget history = HistoryPanel(
          spins: snapshot.spins,
          height: constraints.maxWidth >= 1200 ? 720 : 360,
        );
        final List<Widget> insights = <Widget>[
          PredictionSection(predictions: snapshot.predictions),
          RecentDistributionCard(
            spins: snapshot.spins,
            windows: settings.recentWindows,
          ),
          BasicStatisticsCard(spins: snapshot.spins),
          NumberDetailsCard(
            spins: snapshot.spins,
            number: selected,
            lastN: lastN,
          ),
        ];
        if (constraints.maxWidth >= 1200) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              children: <Widget>[
                disclaimer,
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 300, child: history),
                    const SizedBox(width: 14),
                    SizedBox(width: 430, child: board),
                    const SizedBox(width: 14),
                    Expanded(child: _SpacedColumn(children: insights)),
                  ],
                ),
              ],
            ),
          );
        }
        if (constraints.maxWidth >= 720) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            child: Column(
              children: <Widget>[
                disclaimer,
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: board),
                    const SizedBox(width: 14),
                    SizedBox(width: 290, child: history),
                  ],
                ),
                const SizedBox(height: 14),
                _SpacedColumn(children: insights),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: _SpacedColumn(
            children: <Widget>[disclaimer, board, ...insights, history],
          ),
        );
      },
    );
  }
}

class _SpacedColumn extends StatelessWidget {
  const _SpacedColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        children[i],
        if (i != children.length - 1) const SizedBox(height: 14),
      ],
    ],
  );
}
