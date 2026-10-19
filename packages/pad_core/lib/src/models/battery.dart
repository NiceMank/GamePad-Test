/// État de charge rapporté par la plateforme.
enum BatteryStatus { unknown, charging, discharging, full, notCharging }

extension BatteryStatusLabel on BatteryStatus {
  bool get isCharging =>
      this == BatteryStatus.charging || this == BatteryStatus.full;

  String get labelFr => switch (this) {
    BatteryStatus.unknown => 'Inconnu',
    BatteryStatus.charging => 'En charge',
    BatteryStatus.discharging => 'Décharge',
    BatteryStatus.full => 'Pleine',
    BatteryStatus.notCharging => 'Non branchée',
  };
}

/// Une mesure de batterie horodatée.
class BatteryReading {
  const BatteryReading({
    required this.at,
    required this.status,
    this.percent,
    this.voltage,
  });

  final DateTime at;
  final BatteryStatus status;

  /// 0..100. `null` si la manette n'expose pas la capacité.
  final double? percent;
  final double? voltage;

  bool get isUsable => percent != null && percent!.isFinite;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'status': status.name,
    'percent': percent,
    'voltage': voltage,
  };

  factory BatteryReading.fromJson(Map<String, Object?> json) => BatteryReading(
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    status: BatteryStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => BatteryStatus.unknown,
    ),
    percent: (json['percent'] as num?)?.toDouble(),
    voltage: (json['voltage'] as num?)?.toDouble(),
  );
}

/// Résultat d'estimation : toujours accompagné d'une confiance.
class BatteryEstimate {
  const BatteryEstimate({
    this.remaining,
    this.toFull,
    this.drainPerHour,
    this.confidence = 0,
    this.samples = 0,
    this.reason,
  });

  /// Temps avant 0 % (décharge).
  final Duration? remaining;

  /// Temps avant 100 % (charge).
  final Duration? toFull;

  /// Vitesse de décharge en points de % par heure.
  final double? drainPerHour;

  /// 0..1 — au-dessous de 0.35, l'UI doit afficher « estimation en cours ».
  final double confidence;

  final int samples;
  final String? reason;

  bool get isReliable => confidence >= 0.35 && remaining != null;

  String get confidenceLabel {
    if (confidence >= 0.75) return 'fiable';
    if (confidence >= 0.35) return 'approximative';
    return 'en cours';
  }
}

/// Santé estimée de la batterie (jamais une valeur constructeur).
class BatteryHealth {
  const BatteryHealth({
    required this.score,
    required this.grade,
    required this.confidence,
    this.referenceHours,
    this.measuredHours,
    this.note,
  });

  /// 0..100
  final double score;

  /// A..E
  final String grade;
  final double confidence;
  final double? referenceHours;
  final double? measuredHours;
  final String? note;

  static const unknown = BatteryHealth(
    score: 0,
    grade: '—',
    confidence: 0,
    note: 'Pas assez de données',
  );
}
