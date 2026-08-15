import 'package:flutter_test/flutter_test.dart';
import 'package:roulette_lab/core/constants/roulette_constants.dart';
import 'package:roulette_lab/domain/entities/roulette_number_meta.dart';

void main() {
  group('Europese roulette-eigenschappen', () {
    test('kleur, dozijn, kolom, parity en bereik zijn correct', () {
      expect(RouletteNumberMeta.of(0).color, RouletteColor.green);
      expect(RouletteNumberMeta.of(0).dozen, isNull);
      expect(RouletteNumberMeta.of(1).color, RouletteColor.red);
      expect(RouletteNumberMeta.of(2).color, RouletteColor.black);
      expect(RouletteNumberMeta.of(12).dozen, 1);
      expect(RouletteNumberMeta.of(13).dozen, 2);
      expect(RouletteNumberMeta.of(36).dozen, 3);
      expect(RouletteNumberMeta.of(34).column, 1);
      expect(RouletteNumberMeta.of(35).column, 2);
      expect(RouletteNumberMeta.of(36).column, 3);
      expect(RouletteNumberMeta.of(18).range, RouletteRange.low);
      expect(RouletteNumberMeta.of(19).range, RouletteRange.high);
      expect(RouletteNumberMeta.of(8).parity, RouletteParity.even);
      expect(RouletteNumberMeta.of(9).parity, RouletteParity.odd);
    });

    test('alle 37 wielindices zijn uniek en volledig', () {
      expect(europeanWheelOrder.toSet().length, 37);
      expect(
        <int>{...europeanWheelOrder},
        <int>{for (int i = 0; i < 37; i++) i},
      );
      for (int number = 0; number < 37; number++) {
        expect(europeanWheelOrder[wheelIndex(number)], number);
      }
    });

    test('signed afstand, wrap-around en nulafstand', () {
      expect(signedWheelDistance(0, 21), 5);
      expect(signedWheelDistance(21, 30), 10);
      expect(signedWheelDistance(30, 24), 5);
      expect(signedWheelDistance(0, 26), -1);
      expect(signedWheelDistance(8, 8), 0);
      expect(absoluteWheelDistance(0, 26), 1);
      for (int from = 0; from < 37; from++) {
        for (int delta = -18; delta <= 18; delta++) {
          final int target = numberAtSignedDelta(from, delta);
          expect(signedWheelDistance(from, target), delta);
        }
      }
    });
  });
}
