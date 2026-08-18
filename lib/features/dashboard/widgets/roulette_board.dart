import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/roulette_number_badge.dart';
import '../../../core/widgets/section_card.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/roulette_number_meta.dart';
import '../../../domain/entities/spin.dart';
import '../../../domain/services/analytics/roulette_analytics.dart';

class RouletteBoard extends ConsumerStatefulWidget {
  const RouletteBoard({required this.spins, super.key});

  final List<Spin> spins;

  @override
  ConsumerState<RouletteBoard> createState() => _RouletteBoardState();
}

class _RouletteBoardState extends ConsumerState<RouletteBoard> {
  static const Duration _spinFeedbackDuration = Duration(seconds: 4);

  final TextEditingController _numberController = TextEditingController();
  final FocusNode _numberFocus = FocusNode();
  Timer? _spinFeedbackTimer;
  int _spinFeedbackGeneration = 0;

  @override
  void dispose() {
    _spinFeedbackTimer?.cancel();
    _numberController.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings =
        ref.watch(settingsProvider).value ?? const AppSettings();
    final int? selected = ref.watch(selectedNumberProvider);
    final int window = settings.analysisWindow;
    final int start = window <= 0
        ? 0
        : (widget.spins.length - window).clamp(0, widget.spins.length);
    final Map<int, int> frequencies = <int, int>{};
    for (final Spin spin in widget.spins.skip(start)) {
      frequencies[spin.number] = (frequencies[spin.number] ?? 0) + 1;
    }
    return SectionCard(
      title: AppStrings.appName,
      subtitle: settings.boardMode == BoardMode.input
          ? AppStrings.tapToAdd
          : AppStrings.tapForDetails,
      trailing: const Chip(
        avatar: Icon(Icons.lock_outline, size: 16),
        label: Text(AppStrings.offline),
      ),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SegmentedButton<BoardMode>(
              key: const Key('board-mode-selector'),
              segments: const <ButtonSegment<BoardMode>>[
                ButtonSegment<BoardMode>(
                  value: BoardMode.input,
                  icon: Icon(Icons.add_circle_outline),
                  label: Text(AppStrings.input),
                ),
                ButtonSegment<BoardMode>(
                  value: BoardMode.analyze,
                  icon: Icon(Icons.search),
                  label: Text(AppStrings.analyze),
                ),
              ],
              selected: <BoardMode>{settings.boardMode},
              onSelectionChanged: (Set<BoardMode> value) {
                ref
                    .read(settingsProvider.notifier)
                    .save(settings.copyWith(boardMode: value.first));
              },
            ),
            const SizedBox(height: 12),
            if (settings.boardMode == BoardMode.input) ...<Widget>[
              Container(
                key: const Key('quick-spin-input-card'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.quickInput,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.quickInputHelp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFieldTapRegion(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              key: const Key('numeric-spin-input'),
                              controller: _numberController,
                              focusNode: _numberFocus,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: AppStrings.numberHint,
                                prefixIcon: Icon(Icons.keyboard_rounded),
                              ),
                              onEditingComplete: _submitNumber,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            key: const Key('quick-spin-submit'),
                            onPressed: _submitNumber,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(AppStrings.addNumber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _NumberTile(
              number: 0,
              selected: selected == 0,
              frequency: frequencies[0] ?? 0,
              onTap: () => _activate(0, settings),
              onLongPress: () => _inspect(0),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 36,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                mainAxisExtent: 50,
              ),
              itemBuilder: (BuildContext context, int index) {
                final int number = index + 1;
                return _NumberTile(
                  number: number,
                  selected: selected == number,
                  frequency: frequencies[number] ?? 0,
                  onTap: () => _activate(number, settings),
                  onLongPress: () => _inspect(number),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitNumber() async {
    final String input = _numberController.text.trim();
    final int? number = int.tryParse(input);
    if (number == null || number < 0 || number > 36) {
      _dismissSpinFeedback();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.invalidNumber)));
      _keepQuickInputFocused(selectAll: input.isNotEmpty);
      return;
    }
    // Clear before persistence so a fast next entry is never erased when the
    // previous asynchronous write completes.
    _numberController.clear();
    _keepQuickInputFocused();
    final AppSettings settings =
        ref.read(settingsProvider).value ?? const AppSettings();
    await _add(number, settings);
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _keepQuickInputFocused();
        }
      });
    }
  }

  void _keepQuickInputFocused({bool selectAll = false}) {
    if (!mounted) {
      return;
    }
    _numberFocus.requestFocus();
    if (selectAll) {
      _numberController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _numberController.text.length,
      );
    }
  }

  Future<void> _activate(int number, AppSettings settings) async {
    if (settings.boardMode == BoardMode.analyze) {
      _inspect(number);
      return;
    }
    await _add(number, settings);
  }

  Future<void> _add(int number, AppSettings settings) async {
    if (settings.hapticsEnabled) {
      unawaited(
        HapticFeedback.selectionClick().onError(
          (Object error, StackTrace stackTrace) {},
        ),
      );
    }
    try {
      await ref.read(appControllerProvider.notifier).addSpin(number);
      if (!mounted) {
        return;
      }
      final List<Spin> updatedSpins =
          ref.read(appControllerProvider).value?.spins ?? widget.spins;
      final List<int> recentSuccessors = numberDetails(
        updatedSpins,
        number,
      ).recentSuccessors;
      final List<int> visibleSuccessors = recentSuccessors.take(4).toList();
      _showSpinFeedback(
        number,
        visibleSuccessors,
        hasMore: recentSuccessors.length > visibleSuccessors.length,
      );
    } on Object catch (error) {
      if (mounted) {
        _dismissSpinFeedback();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(AppStrings.error(error))));
      }
    }
  }

  void _showSpinFeedback(
    int number,
    List<int> visibleSuccessors, {
    required bool hasMore,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    _spinFeedbackTimer?.cancel();
    final int generation = ++_spinFeedbackGeneration;
    messenger
      ..hideCurrentSnackBar()
      ..removeCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          key: const Key('spin-added-banner'),
          leading: const Icon(Icons.check_circle_outline_rounded),
          content: Semantics(
            liveRegion: true,
            child: Text(
              AppStrings.spinAddedSuccessors(
                number,
                visibleSuccessors,
                hasMore: hasMore,
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('spin-added-undo'),
              onPressed: () {
                _dismissSpinFeedback();
                unawaited(
                  ref.read(appControllerProvider.notifier).undoLastSpin(),
                );
              },
              child: const Text(AppStrings.undo),
            ),
          ],
        ),
      );
    _spinFeedbackTimer = Timer(_spinFeedbackDuration, () {
      if (!mounted || generation != _spinFeedbackGeneration) {
        return;
      }
      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      _spinFeedbackTimer = null;
    });
  }

  void _dismissSpinFeedback() {
    _spinFeedbackTimer?.cancel();
    _spinFeedbackTimer = null;
    _spinFeedbackGeneration++;
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentMaterialBanner();
    }
  }

  void _inspect(int number) {
    ref.read(selectedNumberProvider.notifier).select(number);
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.number,
    required this.selected,
    required this.frequency,
    required this.onTap,
    required this.onLongPress,
  });

  final int number;
  final bool selected;
  final int frequency;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final RouletteNumberMeta meta = RouletteNumberMeta.of(number);
    final Color color = rouletteColor(number);
    return SizedBox(
      height: 50,
      child: Semantics(
        button: true,
        selected: selected,
        label: AppStrings.numberLabel(
          number,
          meta.colorLabel,
          selected: selected,
        ),
        child: Tooltip(
          message: AppStrings.numberLabel(number, meta.colorLabel),
          child: Material(
            key: Key('number-tile-$number'),
            color: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.secondary
                    : number == 0
                    ? Colors.white.withValues(alpha: 0.42)
                    : color == AppTheme.rouletteBlack
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.transparent,
                width: selected ? 3 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              focusColor: Colors.white.withValues(alpha: 0.18),
              hoverColor: Colors.white.withValues(alpha: 0.11),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Center(
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (frequency > 0)
                    Positioned(
                      top: 4,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$frequency',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
