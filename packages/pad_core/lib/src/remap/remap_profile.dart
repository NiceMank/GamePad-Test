import 'dart:math' as math;

import '../models/pad_button.dart';

enum AxisCurve { linear, precision, aggressive }

extension AxisCurveLabel on AxisCurve {
  String get labelFr => switch (this) {
    AxisCurve.linear => 'Linéaire',
    AxisCurve.precision => 'Précision (centre lent)',
    AxisCurve.aggressive => 'Agressif (réaction rapide)',
  };
}

/// Réglages d'un stick (les deux axes partagent la zone morte radiale).
class AxisSettings {
  const AxisSettings({
    this.deadzone = 0.08,
    this.curve = AxisCurve.linear,
    this.exponent = 2.0,
    this.invertX = false,
    this.invertY = false,
    this.sensitivity = 1.0,
  });

  final double deadzone;
  final AxisCurve curve;
  final double exponent;
  final bool invertX;
  final bool invertY;
  final double sensitivity;

  bool get isDefault =>
      deadzone == 0.08 &&
      curve == AxisCurve.linear &&
      !invertX &&
      !invertY &&
      sensitivity == 1.0;

  double curveValue(double v) {
    final sign = v < 0 ? -1.0 : 1.0;
    final a = v.abs().clamp(0.0, 1.0);
    final shaped = switch (curve) {
      AxisCurve.linear => a,
      AxisCurve.precision => math.pow(a, exponent).toDouble(),
      AxisCurve.aggressive => math.pow(a, 1 / exponent).toDouble(),
    };
    return (sign * shaped).clamp(-1.0, 1.0);
  }

  AxisSettings copyWith({
    double? deadzone,
    AxisCurve? curve,
    double? exponent,
    bool? invertX,
    bool? invertY,
    double? sensitivity,
  }) => AxisSettings(
    deadzone: deadzone ?? this.deadzone,
    curve: curve ?? this.curve,
    exponent: exponent ?? this.exponent,
    invertX: invertX ?? this.invertX,
    invertY: invertY ?? this.invertY,
    sensitivity: sensitivity ?? this.sensitivity,
  );

  Map<String, Object?> toJson() => {
    'deadzone': deadzone,
    'curve': curve.name,
    'exponent': exponent,
    'invertX': invertX,
    'invertY': invertY,
    'sensitivity': sensitivity,
  };

  factory AxisSettings.fromJson(Map<String, Object?> json) => AxisSettings(
    deadzone: (json['deadzone'] as num?)?.toDouble() ?? 0.08,
    curve: AxisCurve.values.firstWhere(
      (c) => c.name == json['curve'],
      orElse: () => AxisCurve.linear,
    ),
    exponent: (json['exponent'] as num?)?.toDouble() ?? 2.0,
    invertX: json['invertX'] == true,
    invertY: json['invertY'] == true,
    sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 1.0,
  );
}

class TriggerSettings {
  const TriggerSettings({
    this.deadzone = 0.04,
    this.threshold = 0.35,
    this.minValue = 0.0,
    this.maxValue = 1.0,
    this.asButton = true,
  });

  final double deadzone;
  final double threshold;

  /// Bornes observées : permet de normaliser une gâchette qui s'arrête à 0,96.
  final double minValue;
  final double maxValue;

  /// Une gâchette analogique peut aussi produire l'événement bouton L2/R2.
  final bool asButton;

  double normalize(double raw) {
    final span = maxValue - minValue;
    if (span <= 0.01) return raw;
    final v = ((raw - minValue) / span).clamp(0.0, 1.0);
    return v < deadzone ? 0.0 : v;
  }

  TriggerSettings copyWith({
    double? deadzone,
    double? threshold,
    double? minValue,
    double? maxValue,
    bool? asButton,
  }) => TriggerSettings(
    deadzone: deadzone ?? this.deadzone,
    threshold: threshold ?? this.threshold,
    minValue: minValue ?? this.minValue,
    maxValue: maxValue ?? this.maxValue,
    asButton: asButton ?? this.asButton,
  );

  Map<String, Object?> toJson() => {
    'deadzone': deadzone,
    'threshold': threshold,
    'minValue': minValue,
    'maxValue': maxValue,
    'asButton': asButton,
  };

  factory TriggerSettings.fromJson(Map<String, Object?> json) => TriggerSettings(
    deadzone: (json['deadzone'] as num?)?.toDouble() ?? 0.04,
    threshold: (json['threshold'] as num?)?.toDouble() ?? 0.35,
    minValue: (json['minValue'] as num?)?.toDouble() ?? 0.0,
    maxValue: (json['maxValue'] as num?)?.toDouble() ?? 1.0,
    asButton: json['asButton'] as bool? ?? true,
  );
}

/// Un profil complet, applicable à une manette identifiée par sa clé VID/PID.
class RemapProfile {
  const RemapProfile({
    required this.id,
    required this.name,
    this.deviceKey = '*',
    this.buttonMap = const {},
    this.disabledButtons = const {},
    this.leftStick = const AxisSettings(),
    this.rightStick = const AxisSettings(),
    this.leftTrigger = const TriggerSettings(),
    this.rightTrigger = const TriggerSettings(),
    this.stickToDpad = false,
    this.stickToDpadThreshold = 0.65,
    this.turboButtons = const {},
    this.turboHz = 12,
    this.systemWide = false,
  });

  final String id;
  final String name;

  /// `*` = profil générique, sinon `vid:pid:nom`.
  final String deviceKey;

  final Map<PadButton, PadButton> buttonMap;
  final Set<PadButton> disabledButtons;
  final AxisSettings leftStick;
  final AxisSettings rightStick;
  final TriggerSettings leftTrigger;
  final TriggerSettings rightTrigger;
  final bool stickToDpad;
  final double stickToDpadThreshold;
  final Set<PadButton> turboButtons;
  final double turboHz;

  /// Sur PC, appliquer via la manette Xbox virtuelle (tous les jeux).
  final bool systemWide;

  static const neutral = RemapProfile(id: 'neutral', name: 'Par défaut');

  bool get isNeutral =>
      buttonMap.isEmpty &&
      disabledButtons.isEmpty &&
      leftStick.isDefault &&
      rightStick.isDefault &&
      !stickToDpad &&
      turboButtons.isEmpty &&
      leftTrigger.deadzone == 0.04 &&
      leftTrigger.threshold == 0.35 &&
      rightTrigger.deadzone == 0.04 &&
      rightTrigger.threshold == 0.35;

  /// Cible effective d'un bouton (visible dans l'UI « avant / après »).
  PadButton? targetOf(PadButton source) {
    if (disabledButtons.contains(source)) return null;
    return buttonMap[source] ?? source;
  }

  RemapProfile copyWith({
    String? id,
    String? name,
    String? deviceKey,
    Map<PadButton, PadButton>? buttonMap,
    Set<PadButton>? disabledButtons,
    AxisSettings? leftStick,
    AxisSettings? rightStick,
    TriggerSettings? leftTrigger,
    TriggerSettings? rightTrigger,
    bool? stickToDpad,
    double? stickToDpadThreshold,
    Set<PadButton>? turboButtons,
    double? turboHz,
    bool? systemWide,
  }) => RemapProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    deviceKey: deviceKey ?? this.deviceKey,
    buttonMap: buttonMap ?? this.buttonMap,
    disabledButtons: disabledButtons ?? this.disabledButtons,
    leftStick: leftStick ?? this.leftStick,
    rightStick: rightStick ?? this.rightStick,
    leftTrigger: leftTrigger ?? this.leftTrigger,
    rightTrigger: rightTrigger ?? this.rightTrigger,
    stickToDpad: stickToDpad ?? this.stickToDpad,
    stickToDpadThreshold: stickToDpadThreshold ?? this.stickToDpadThreshold,
    turboButtons: turboButtons ?? this.turboButtons,
    turboHz: turboHz ?? this.turboHz,
    systemWide: systemWide ?? this.systemWide,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'deviceKey': deviceKey,
    'buttonMap': {
      for (final e in buttonMap.entries) e.key.name: e.value.name,
    },
    'disabledButtons': [for (final b in disabledButtons) b.name],
    'leftStick': leftStick.toJson(),
    'rightStick': rightStick.toJson(),
    'leftTrigger': leftTrigger.toJson(),
    'rightTrigger': rightTrigger.toJson(),
    'stickToDpad': stickToDpad,
    'stickToDpadThreshold': stickToDpadThreshold,
    'turboButtons': [for (final b in turboButtons) b.name],
    'turboHz': turboHz,
    'systemWide': systemWide,
  };

  factory RemapProfile.fromJson(Map<String, Object?> json) {
    PadButton? parseButton(Object? value) {
      if (value is! String) return null;
      for (final b in PadButton.values) {
        if (b.name == value) return b;
      }
      return null;
    }

    final map = <PadButton, PadButton>{};
    final rawMap = json['buttonMap'];
    if (rawMap is Map) {
      for (final entry in rawMap.entries) {
        final source = parseButton(entry.key);
        final target = parseButton(entry.value);
        if (source != null && target != null) map[source] = target;
      }
    }

    return RemapProfile(
      id: json['id'] as String? ?? 'imported',
      name: json['name'] as String? ?? 'Profil importé',
      deviceKey: json['deviceKey'] as String? ?? '*',
      buttonMap: map,
      disabledButtons: {
        for (final raw in (json['disabledButtons'] as List<Object?>? ?? const []))
          if (parseButton(raw) != null) parseButton(raw)!,
      },
      leftStick: json['leftStick'] is Map
          ? AxisSettings.fromJson((json['leftStick']! as Map).cast<String, Object?>())
          : const AxisSettings(),
      rightStick: json['rightStick'] is Map
          ? AxisSettings.fromJson((json['rightStick']! as Map).cast<String, Object?>())
          : const AxisSettings(),
      leftTrigger: json['leftTrigger'] is Map
          ? TriggerSettings.fromJson((json['leftTrigger']! as Map).cast<String, Object?>())
          : const TriggerSettings(),
      rightTrigger: json['rightTrigger'] is Map
          ? TriggerSettings.fromJson((json['rightTrigger']! as Map).cast<String, Object?>())
          : const TriggerSettings(),
      stickToDpad: json['stickToDpad'] == true,
      stickToDpadThreshold: (json['stickToDpadThreshold'] as num?)?.toDouble() ?? 0.65,
      turboButtons: {
        for (final raw in (json['turboButtons'] as List<Object?>? ?? const []))
          if (parseButton(raw) != null) parseButton(raw)!,
      },
      turboHz: (json['turboHz'] as num?)?.toDouble() ?? 12,
      systemWide: json['systemWide'] == true,
    );
  }
}
