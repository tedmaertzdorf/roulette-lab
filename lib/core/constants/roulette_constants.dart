const List<int> europeanWheelOrder = <int>[
  0,
  32,
  15,
  19,
  4,
  21,
  2,
  25,
  17,
  34,
  6,
  27,
  13,
  36,
  11,
  30,
  8,
  23,
  10,
  5,
  24,
  16,
  33,
  1,
  20,
  14,
  31,
  9,
  22,
  18,
  29,
  7,
  28,
  12,
  35,
  3,
  26,
];

const Set<int> redNumbers = <int>{
  1,
  3,
  5,
  7,
  9,
  12,
  14,
  16,
  18,
  19,
  21,
  23,
  25,
  27,
  30,
  32,
  34,
  36,
};

const int rouletteNumberCount = 37;
const double uniformRouletteProbability = 1 / rouletteNumberCount;

int requireRouletteNumber(int number) {
  if (number < 0 || number >= rouletteNumberCount) {
    throw RangeError.range(number, 0, 36, 'number');
  }
  return number;
}

int wheelIndex(int number) =>
    europeanWheelOrder.indexOf(requireRouletteNumber(number));

int clockwiseDistance(int from, int to) =>
    (wheelIndex(to) - wheelIndex(from)) % rouletteNumberCount;

int counterClockwiseDistance(int from, int to) =>
    (wheelIndex(from) - wheelIndex(to)) % rouletteNumberCount;

int signedWheelDistance(int from, int to) {
  final int clockwise = clockwiseDistance(from, to);
  return clockwise <= 18 ? clockwise : clockwise - rouletteNumberCount;
}

int absoluteWheelDistance(int from, int to) =>
    signedWheelDistance(from, to).abs();

int numberAtSignedDelta(int from, int delta) {
  if (delta < -18 || delta > 18) {
    throw RangeError.range(delta, -18, 18, 'delta');
  }
  final int index = (wheelIndex(from) + delta) % rouletteNumberCount;
  return europeanWheelOrder[index];
}
