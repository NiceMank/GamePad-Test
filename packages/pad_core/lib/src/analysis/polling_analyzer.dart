import 'dart:math' as math;

class PollingMetrics {
  const PollingMetrics({
    required this.samples,
    required this.hz,
    required this.meanIntervalMs,
    required this.minIntervalMs,
    required this.maxIntervalMs,
    required this.jitterMs,
    required this.stalls,
    required this.histogram,
  });

  final int samples;
  final double hz;
  final double meanIntervalMs;
  final double minIntervalMs;
  final double maxIntervalMs;

  /// Écart-type des intervalles — la vraie mesure de stabilité.
  final double jitterMs;

  /// Nombre d'intervalles > 4x la médiane (paquets perdus / réveil de l'OS).
  final int stalls;

  /// Comptage par tranche de 0,25 ms, pour l'histogramme.
  final Map<double, int> histogram;

  static const empty = PollingMetrics(
    samples: 0,
    hz: 0,
    meanIntervalMs: 0,
    minIntervalMs: 0,
    maxIntervalMs: 0,
    jitterMs: 0,
    stalls: 0,
    histogram: {},
  );

  bool get hasData => samples >= 20;

  String get quality {
    if (!hasData) return 'Mesure en cours';
    if (jitterMs > 4) return 'Instable';
    if (stalls > samples * 0.02) return 'Pertes fréquentes';
    if (jitterMs > 1.5) return 'Correct';
    return 'Stable';
  }
}

class PollingAnalyzer {
  PollingAnalyzer({this.maxIntervals = 20000});

  final int maxIntervals;
  final List<int> _intervalsUs = [];
  int? _lastUs;

  int get sampleCount => _intervalsUs.length;

  /// À appeler à chaque événement natif horodaté en µs.
  void addTimestamp(int timestampUs) {
    final last = _lastUs;
    if (last != null) {
      final delta = timestampUs - last;
      if (delta > 0) {
        _intervalsUs.add(delta);
        if (_intervalsUs.length > maxIntervals) _intervalsUs.removeAt(0);
      }
    }
    _lastUs = timestampUs;
  }

  void reset() {
    _intervalsUs.clear();
    _lastUs = null;
  }

  PollingMetrics compute() {
    if (_intervalsUs.length < 5) return PollingMetrics.empty;

    final sorted = [..._intervalsUs]..sort();
    final median = sorted[sorted.length ~/ 2].toDouble();
    final mean = _intervalsUs.reduce((a, b) => a + b) / _intervalsUs.length;
    var variance = 0.0;
    for (final i in _intervalsUs) {
      final d = i - mean;
      variance += d * d;
    }
    variance /= _intervalsUs.length;
    final sd = math.sqrt(variance);

    final stalls = _intervalsUs.where((i) => i > median * 4).length;

    final histogram = <double, int>{};
    for (final i in _intervalsUs) {
      final bucket = (i / 250).round() * 0.25; // 0,25 ms
      histogram[bucket] = (histogram[bucket] ?? 0) + 1;
    }

    return PollingMetrics(
      samples: _intervalsUs.length,
      hz: median <= 0 ? 0 : 1e6 / median,
      meanIntervalMs: mean / 1000,
      minIntervalMs: sorted.first / 1000,
      maxIntervalMs: sorted.last / 1000,
      jitterMs: sd / 1000,
      stalls: stalls,
      histogram: histogram,
    );
  }
}
