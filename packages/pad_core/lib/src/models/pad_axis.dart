/// Axes analogiques normalisés.
enum PadAxis { leftX, leftY, rightX, rightY, leftTrigger, rightTrigger }

extension PadAxisRange on PadAxis {
  bool get isTrigger => this == PadAxis.leftTrigger || this == PadAxis.rightTrigger;

  /// Les sticks vont de -1 à 1, les gâchettes de 0 à 1.
  double get min => isTrigger ? 0.0 : -1.0;
  double get max => 1.0;
}

/// Axes bruts exposés par le matériel (pour le mode Universal).
class RawAxisRange {
  const RawAxisRange({
    required this.axis,
    required this.min,
    required this.max,
    this.flat = 0,
    this.fuzz = 0,
    this.resolution = 0,
  });

  final PadAxis axis;
  final double min;
  final double max;
  final double flat;
  final double fuzz;
  final double resolution;

  /// Convertit une valeur brute en valeur normalisée selon la plage réelle.
  double normalize(double raw) {
    final span = max - min;
    if (span <= 0) {
      return axis.isTrigger ? 0.0 : 0.0;
    }
    final unit = ((raw - min) / span).clamp(0.0, 1.0);
    return axis.isTrigger ? unit : (unit * 2.0) - 1.0;
  }

  Map<String, Object?> toJson() => {
    'axis': axis.name,
    'min': min,
    'max': max,
    'flat': flat,
    'fuzz': fuzz,
    'resolution': resolution,
  };
}
