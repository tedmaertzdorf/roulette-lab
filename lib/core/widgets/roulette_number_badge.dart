import 'package:flutter/material.dart';

import '../../domain/entities/roulette_number_meta.dart';
import '../theme/app_theme.dart';

Color rouletteColor(int number) =>
    switch (RouletteNumberMeta.of(number).color) {
      RouletteColor.green => AppTheme.rouletteGreen,
      RouletteColor.red => AppTheme.rouletteRed,
      RouletteColor.black => AppTheme.rouletteBlack,
    };

class RouletteNumberBadge extends StatelessWidget {
  const RouletteNumberBadge({
    required this.number,
    this.size = 42,
    this.selected = false,
    super.key,
  });

  final int number;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final RouletteNumberMeta meta = RouletteNumberMeta.of(number);
    return Semantics(
      label: '$number, ${meta.colorLabel}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: rouletteColor(number),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.secondary
                : Colors.white.withValues(alpha: 0.35),
            width: selected ? 3 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
