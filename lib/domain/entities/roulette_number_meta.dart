import '../../core/constants/roulette_constants.dart';
import '../../core/localization/app_strings.dart';

enum RouletteColor { green, red, black }

enum RouletteParity { neutral, even, odd }

enum RouletteRange { neutral, low, high }

class RouletteNumberMeta {
  const RouletteNumberMeta({
    required this.number,
    required this.color,
    required this.dozen,
    required this.column,
    required this.parity,
    required this.range,
    required this.wheelIndex,
  });

  factory RouletteNumberMeta.of(int number) {
    requireRouletteNumber(number);
    if (number == 0) {
      return const RouletteNumberMeta(
        number: 0,
        color: RouletteColor.green,
        dozen: null,
        column: null,
        parity: RouletteParity.neutral,
        range: RouletteRange.neutral,
        wheelIndex: 0,
      );
    }
    return RouletteNumberMeta(
      number: number,
      color: redNumbers.contains(number)
          ? RouletteColor.red
          : RouletteColor.black,
      dozen: ((number - 1) ~/ 12) + 1,
      column: ((number - 1) % 3) + 1,
      parity: number.isEven ? RouletteParity.even : RouletteParity.odd,
      range: number <= 18 ? RouletteRange.low : RouletteRange.high,
      wheelIndex: europeanWheelOrder.indexOf(number),
    );
  }

  final int number;
  final RouletteColor color;
  final int? dozen;
  final int? column;
  final RouletteParity parity;
  final RouletteRange range;
  final int wheelIndex;

  String get colorLabel => switch (color) {
    RouletteColor.green => AppStrings.greenLower,
    RouletteColor.red => AppStrings.redLower,
    RouletteColor.black => AppStrings.blackLower,
  };

  String get parityLabel => switch (parity) {
    RouletteParity.neutral => AppStrings.neutralLower,
    RouletteParity.even => AppStrings.evenLower,
    RouletteParity.odd => AppStrings.oddLower,
  };

  String get rangeLabel => switch (range) {
    RouletteRange.neutral => AppStrings.neutralLower,
    RouletteRange.low => AppStrings.lowLower,
    RouletteRange.high => AppStrings.highLower,
  };

  List<int> get wheelNeighbors {
    final List<int> values = <int>[];
    for (final int offset in const <int>[-2, -1, 1, 2]) {
      values.add(
        europeanWheelOrder[(wheelIndex + offset) % rouletteNumberCount],
      );
    }
    return values;
  }
}
