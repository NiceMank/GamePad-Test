import 'dart:math' as math;

import '../models/battery.dart';

/// Estime l'autonomie restante à partir de mesures de capacité.
///
/// Aucun OS n'expose l'autonomie d'une manette : on la **mesure**. La méthode
/// est une régression linéaire sur une fenêtre glissante, avec une confiance
/// explicite afin de ne jamais afficher un chiffre trompeur.
class BatteryEstimator {
  BatteryEstimator({this.window = const Duration(minutes: 30), this.minSpan = const Duration(minutes: 2)});

  /// Fenêtre glissante utilisée pour la régression.
  final Duration window;

  /// En dessous de cette durée d'observation, aucune estimation n'est publiée.
  final Duration minSpan;

  final List<BatteryReading> _readings = [];

  List<BatteryReading> get readings => List.unmodifiable(_readings);
  BatteryReading? get latest => _readings.isEmpty ? null : _readings.last;

  void add(BatteryReading reading) {
    _readings.add(reading);
    _readings.sort((a, b) => a.at.compareTo(b.at));
    final cutoff = reading.at.subtract(window * 3);
    _readings.removeWhere((r) => r.at.isBefore(cutoff));
  }

  void reset() => _readings.clear();

  BatteryEstimate estimate() {
    final usable = [
      for (final r in _readings)
        if (r.isUsable) r,
    ];
    if (usable.length < 2) {
      return const BatteryEstimate(
        samples: 0,
        reason: 'En attente de mesures',
      );
    }

    final current = usable.last;
    if (current.status == BatteryStatus.full) {
      return BatteryEstimate(
        remaining: Duration.zero,
        toFull: Duration.zero,
        samples: usable.length,
        confidence: 1,
        reason: 'Batterie pleine',
      );
    }

    final cutoff = current.at.subtract(window);
    final considered = [
      for (final r in usable)
        if (r.at.isAfter(cutoff)) r,
    ];
    if (considered.length < 2) {
      return BatteryEstimate(samples: usable.length, reason: 'Fenêtre trop courte');
    }

    final span = current.at.difference(considered.first.at);
    if (span < minSpan) {
      return BatteryEstimate(
        samples: considered.length,
        reason: 'Observation en cours (${span.inSeconds} s)',
        confidence: (span.inSeconds / minSpan.inSeconds) * 0.3,
      );
    }

    // Régression linéaire : % = a + b * minutes.
    final t0 = considered.first.at.microsecondsSinceEpoch;
    final xs = [for (final r in considered) (r.at.microsecondsSinceEpoch - t0) / 6e7];
    final ys = [for (final r in considered) r.percent!];
    final slope = _slope(xs, ys); // % par minute
    final residual = _residual(xs, ys, slope);
    final perHour = slope * 60;

    // Qualité : durée d'observation, nombre de points, bruit de la régression.
    final spanScore = (span.inMinutes / 20).clamp(0.0, 1.0);
    final sampleScore = (considered.length / 10).clamp(0.0, 1.0);
    final noiseScore = (1.0 - (residual / 6.0)).clamp(0.0, 1.0);
    final confidence = (spanScore * 0.5 + sampleScore * 0.25 + noiseScore * 0.25)
        .clamp(0.0, 1.0);

    if (current.status == BatteryStatus.charging) {
      if (perHour <= 0.5) {
        return BatteryEstimate(
          samples: considered.length,
          confidence: confidence * 0.5,
          reason: 'Charge trop lente pour estimer',
        );
      }
      final hours = (100 - current.percent!) / perHour;
      return BatteryEstimate(
        toFull: _toDuration(hours),
        drainPerHour: -perHour, // négatif = charge
        samples: considered.length,
        confidence: confidence,
      );
    }

    // Décharge : il faut une pente négative franche.
    if (perHour > -0.2) {
      return BatteryEstimate(
        samples: considered.length,
        drainPerHour: perHour,
        confidence: confidence * 0.4,
        reason: 'Décharge trop lente pour extrapoler',
      );
    }

    final hours = current.percent! / -perHour;
    return BatteryEstimate(
      remaining: _toDuration(hours),
      drainPerHour: -perHour,
      samples: considered.length,
      confidence: confidence,
    );
  }

  double _slope(List<double> xs, List<double> ys) {
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var num = 0.0;
    var den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - meanX) * (ys[i] - meanY);
      den += (xs[i] - meanX) * (xs[i] - meanX);
    }
    return den == 0 ? 0 : num / den;
  }

  double _residual(List<double> xs, List<double> ys, double slope) {
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    final intercept = meanY - slope * meanX;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final predicted = intercept + slope * xs[i];
      final err = ys[i] - predicted;
      sum += err * err;
    }
    return math.sqrt(sum / n);
  }

  Duration _toDuration(double hours) {
    if (!hours.isFinite || hours <= 0) return Duration.zero;
    return Duration(minutes: (hours * 60).round().clamp(0, 60 * 240));
  }
}

/// Estime la santé à partir de l'endurance observée, comparée à une référence
/// par modèle. C'est une **estimation**, pas une donnée constructeur.
class BatteryHealthEstimator {
  const BatteryHealthEstimator();

  BatteryHealth estimate({
    required double drainPerHour,
    required double referenceHours,
    required double confidence,
    double? observedHours,
  }) {
    if (drainPerHour <= 0.05 || referenceHours <= 0) {
      return BatteryHealth.unknown;
    }
    final endurance = observedHours ?? (100 / drainPerHour);
    final ratio = (endurance / referenceHours).clamp(0.0, 1.3);
    final score = (ratio * 100).clamp(0.0, 100.0);
    final grade = switch (score) {
      >= 85 => 'A',
      >= 70 => 'B',
      >= 55 => 'C',
      >= 40 => 'D',
      _ => 'E',
    };
    return BatteryHealth(
      score: score,
      grade: grade,
      confidence: confidence,
      referenceHours: referenceHours,
      measuredHours: endurance,
      note: confidence < 0.35
          ? 'Estimation en cours : garde la manette connectée plus longtemps.'
          : 'Comparé à une autonomie de référence de ${referenceHours.toStringAsFixed(1)} h.',
    );
  }
}
