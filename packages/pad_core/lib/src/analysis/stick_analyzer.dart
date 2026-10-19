import 'dart:math' as math;

/// Une position de stick horodatée.
class StickSample {
  const StickSample(this.x, this.y, this.tUs);

  final double x;
  final double y;
  final int tUs;

  double get magnitude => math.sqrt(x * x + y * y);
  double get angle => math.atan2(y, x);
}

/// Métriques d'un stick sur une fenêtre d'analyse.
class StickMetrics {
  const StickMetrics({
    required this.samples,
    required this.driftPercent,
    required this.deadzonePercent,
    required this.circularityPercent,
    required this.coveragePercent,
    required this.radiusMin,
    required this.radiusMax,
    required this.restSamples,
  });

  final int samples;
  final double driftPercent;
  final double deadzonePercent;
  final double circularityPercent;
  final double coveragePercent;
  final double radiusMin;
  final double radiusMax;
  final int restSamples;

  static const empty = StickMetrics(
    samples: 0,
    driftPercent: 0,
    deadzonePercent: 0,
    circularityPercent: 0,
    coveragePercent: 0,
    radiusMin: 0,
    radiusMax: 0,
    restSamples: 0,
  );

  bool get hasData => samples >= 30;

  /// Verdict lisible, sans jargon.
  String get verdict {
    if (!hasData) return 'Pas assez d\'échantillons';
    if (driftPercent > 5) return 'Drift important — nettoyage ou remplacement';
    if (driftPercent > 2) return 'Drift visible';
    if (circularityPercent < 88) return 'Circularité irrégulière';
    if (deadzonePercent > 12) return 'Zone morte large';
    return 'Stick sain';
  }
}

/// Analyse un stick à partir d'un flux d'échantillons.
///
/// Les calculs sont volontairement simples et reproductibles : ce sont les
/// mêmes formules que celles décrites dans le plan (drift, zone morte,
/// circularité, couverture), pour que deux sessions soient comparables.
class StickAnalyzer {
  StickAnalyzer({this.maxSamples = 20000, this.restThreshold = 0.12});

  final int maxSamples;

  /// En dessous de ce rayon, on considère que le stick est au repos.
  final double restThreshold;

  final List<StickSample> _samples = [];

  int get sampleCount => _samples.length;
  List<StickSample> get samples => List.unmodifiable(_samples);
  StickSample? get last => _samples.isEmpty ? null : _samples.last;

  void add(double x, double y, int tUs) {
    _samples.add(StickSample(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0), tUs));
    if (_samples.length > maxSamples) {
      _samples.removeAt(0);
    }
  }

  void reset() => _samples.clear();

  StickMetrics compute({int angularBuckets = 72, int gridCells = 24}) {
    if (_samples.isEmpty) return StickMetrics.empty;

    // Repos : seuil fixe, avec repli adaptatif si le stick ne redescend
    // jamais sous ce seuil (drift important, capuchon usé...).
    var restLimit = restThreshold;
    var rest = <StickSample>[
      for (final s in _samples)
        if (s.magnitude <= restLimit) s,
    ];
    if (rest.isEmpty) {
      final magnitudes = _samples.map((s) => s.magnitude).toList()..sort();
      final p10 = magnitudes[(magnitudes.length * 0.10).floor().clamp(0, magnitudes.length - 1)];
      restLimit = p10.clamp(0.02, 0.5);
      rest = [
        for (final s in _samples)
          if (s.magnitude <= restLimit) s,
      ];
    }

    // Drift : rayon moyen au repos.
    final drift = rest.isEmpty
        ? 0.0
        : rest.map((s) => s.magnitude).reduce((a, b) => a + b) / rest.length;

    // Zone morte : 95e percentile des rayons au repos.
    final sortedRest = rest.map((s) => s.magnitude).toList()..sort();
    final deadzone = sortedRest.isEmpty
        ? 0.0
        : sortedRest[(sortedRest.length * 0.95).floor().clamp(0, sortedRest.length - 1)];

    // Circularité : rayon max par secteur angulaire, puis min/max.
    final bucketMax = List<double>.filled(angularBuckets, 0);
    for (final s in _samples) {
      if (s.magnitude < 0.2) continue;
      final normalized = (s.angle + math.pi) / (2 * math.pi);
      final index = (normalized * angularBuckets).floor().clamp(0, angularBuckets - 1);
      if (s.magnitude > bucketMax[index]) bucketMax[index] = s.magnitude;
    }
    final visited = bucketMax.where((v) => v > 0).toList();
    final radialMin = visited.isEmpty ? 0.0 : visited.reduce(math.min);
    final radialMax = visited.isEmpty ? 0.0 : visited.reduce(math.max);
    final circularity = radialMax <= 0 ? 0.0 : (radialMin / radialMax) * 100;

    // Couverture angulaire : proportion de secteurs où le stick a atteint
    // au moins 50 % de sa course. Un stick qui ne va que vers la droite
    // obtient ~4 %, même s'il bouge beaucoup.
    final reached = bucketMax.where((v) => v >= 0.5).length;
    final coverage = angularBuckets == 0 ? 0.0 : reached / angularBuckets * 100;


    return StickMetrics(
      samples: _samples.length,
      driftPercent: drift * 100,
      deadzonePercent: deadzone * 100,
      circularityPercent: circularity.clamp(0, 100),
      coveragePercent: coverage.clamp(0, 100),
      radiusMin: radialMin,
      radiusMax: radialMax,
      restSamples: rest.length,
    );
  }
}
