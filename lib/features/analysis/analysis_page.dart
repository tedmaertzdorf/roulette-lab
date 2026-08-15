import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/roulette_number_badge.dart';
import '../../core/widgets/section_card.dart';
import '../../domain/repositories/app_repository.dart';
import 'number_details_card.dart';
import 'recent_statistics_cards.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  int? _lastN;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSnapshot> state = ref.watch(appControllerProvider);
    final int? selected = ref.watch(selectedNumberProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stack) =>
          Center(child: Text(AppStrings.error(error))),
      data: (AppSnapshot snapshot) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget picker = _NumberPicker(selected: selected);
          final Widget details = NumberDetailsCard(
            spins: snapshot.spins,
            number: selected,
            lastN: _lastN,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _FilterBar(
                  selected: _lastN,
                  onChanged: (int? value) => setState(() => _lastN = value),
                ),
                const SizedBox(height: 14),
                if (constraints.maxWidth >= 900)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(width: 330, child: picker),
                      const SizedBox(width: 14),
                      Expanded(child: details),
                    ],
                  )
                else ...<Widget>[picker, const SizedBox(height: 14), details],
                const SizedBox(height: 14),
                RecentDistributionCard(
                  spins: snapshot.spins,
                  windows: const <int>[5, 10, 20, 30],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: AppStrings.analysisWindow,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        ChoiceChip(
          label: const Text(AppStrings.all),
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        ChoiceChip(
          label: const Text(AppStrings.last30),
          selected: selected == 30,
          onSelected: (_) => onChanged(30),
        ),
        ChoiceChip(
          label: const Text(AppStrings.last100),
          selected: selected == 100,
          onSelected: (_) => onChanged(100),
        ),
        ActionChip(
          avatar: const Icon(Icons.tune, size: 18),
          label: Text(
            selected != null && selected != 30 && selected != 100
                ? '${AppStrings.custom}: $selected'
                : AppStrings.custom,
          ),
          onPressed: () async {
            final int? value = await _customWindow(context, selected ?? 200);
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    ),
  );
}

class _NumberPicker extends ConsumerWidget {
  const _NumberPicker({required this.selected});

  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    title: AppStrings.analyze,
    subtitle: AppStrings.europeanNumbers,
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 37,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisExtent: 56,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (BuildContext context, int number) => InkWell(
        key: Key('analysis-number-$number'),
        borderRadius: BorderRadius.circular(28),
        onTap: () => ref.read(selectedNumberProvider.notifier).select(number),
        child: Center(
          child: RouletteNumberBadge(
            number: number,
            size: 46,
            selected: selected == number,
          ),
        ),
      ),
    ),
  );
}

Future<int?> _customWindow(BuildContext context, int initial) async {
  final TextEditingController controller = TextEditingController(
    text: '$initial',
  );
  final int? value = await showDialog<int>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text(AppStrings.custom),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        decoration: const InputDecoration(labelText: AppStrings.lastSpinCount),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final int? parsed = int.tryParse(controller.text);
            if (parsed != null && parsed > 0 && parsed <= 10000) {
              Navigator.pop(context, parsed);
            }
          },
          child: const Text(AppStrings.save),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
