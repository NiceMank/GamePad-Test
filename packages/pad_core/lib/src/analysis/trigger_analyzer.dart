import 'dart:math' as math;

class TriggerMetrics {
  const TriggerMetrics({
    required this.samples,
    required this.minValue,
    required this.maxValue,
    required this.linearityPercent,
    required this.travelPercent,
  });

  final int samples;
  final double minValue;
  final double maxValue;

  /// 100 % = courbe parfaitement linéaire. Mesure l'écart RMS à la droite
  /// passant par (min, 0) et (max, 1).
  final double linearityPercent;

  /// Course réellement parcourue (0..100 %).
  final double travelPercent;

  static const empty = TriggerMetrics(
    samples: 0,
    minValue: 0,
    maxValue: 0,
    linearityPercent: 0,
    travelPercent: 0,
  );

  bool get hasData => samples >= 20;

  String get verdict {
    if (!hasData) return 'Pas assez d\'échantillons';
    if (travelPercent < 97) return 'Course incomplète (${travelPercent.toStringAsFixed(0)} %)';
    if (linearityPercent < 85) return 'Réponse non linéaire';
    return 'Gâchette saine';
  }
}

class TriggerAnalyzer {
  TriggerAnalyzer({this.maxSamples = 20000});

  final int maxSamples;
  final List<double> _values = [];

  int get sampleCount => _values.length;

  void add(double value) {
    _values.add(value.clamp(0.0, 1.0));
    if (_values.length > maxSamples) _values.removeAt(0);
  }

  void reset() => _values.clear();

  TriggerMetrics compute() {
    if (_values.isEmpty) return TriggerMetrics.empty;

    final min = _values.reduce(math.min);
    final max = _values.reduce(math.max);
    final span = max - min;
    final travel = span * 100;

    // Linéarité = R² de la régression de la valeur sur le temps
    // (indépendant de la plage : une gâchette qui s'arrête à 0,96 reste
    // parfaitement linéaire, c'est la course qui est en défaut).
    final n = _values.length;
    final meanX = (n - 1) / 2;
    final meanY = _values.reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    var ssTot = 0.0;
    for (var i = 0; i < n; i++) {
      num += (i - meanX) * (_values[i] - meanY);
      den += (i - meanX) * (i - meanX);
      ssTot += (_values[i] - meanY) * (_values[i] - meanY);
    }
    final slope = den == 0 ? 0.0 : num / den;
    final intercept = meanY - slope * meanX;
    var ssRes = 0.0;
    for (var i = 0; i < n; i++) {
      final err = _values[i] - (intercept + slope * i);
      ssRes += err * err;
    }
    final r2 = ssTot <= 1e-9 ? 1.0 : (1 - ssRes / ssTot).clamp(0.0, 1.0);

    return TriggerMetrics(
      samples: _values.length,
      minValue: min,
      maxValue: max,
      linearityPercent: r2 * 100,
      travelPercent: travel,
    );
  }
}
