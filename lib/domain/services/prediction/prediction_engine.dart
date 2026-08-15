import '../../entities/prediction.dart';
import '../../entities/spin.dart';

abstract interface class PredictionEngine {
  String get id;
  String get name;
  int get modelVersion;

  PredictionResult predict(List<Spin> history);
}
