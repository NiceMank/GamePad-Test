import 'pad_axis.dart';
import 'pad_button.dart';

enum ConnectionGuess { bluetooth, usb, network, unknown }

/// Ce que la manette sait faire, tel que rapporté par l'OS.
class PadCapabilities {
  const PadCapabilities({
    this.axes = const [],
    this.buttonBits = 0,
    this.vibratorCount = 0,
    this.hasBattery = false,
    this.hasLight = false,
    this.hasMotion = false,
    this.hasTouchpad = false,
    this.hasMicrophone = false,
  });

  final List<RawAxisRange> axes;
  final int buttonBits;
  final int vibratorCount;
  final bool hasBattery;
  final bool hasLight;
  final bool hasMotion;
  final bool hasTouchpad;
  final bool hasMicrophone;

  List<PadButton> get buttons => [
    for (final b in PadButton.values)
      if (buttonBits & padButtonBit(b) != 0) b,
  ];

  bool supportsButton(PadButton button) =>
      buttonBits & padButtonBit(button) != 0;

  Map<String, Object?> toJson() => {
    'axes': [for (final a in axes) a.toJson()],
    'buttonBits': buttonBits,
    'vibratorCount': vibratorCount,
    'hasBattery': hasBattery,
    'hasLight': hasLight,
    'hasMotion': hasMotion,
    'hasTouchpad': hasTouchpad,
    'hasMicrophone': hasMicrophone,
  };

  factory PadCapabilities.fromJson(Map<Object?, Object?> json) {
    final rawAxes = (json['axes'] as List<Object?>? ?? const []);
    final axes = <RawAxisRange>[];
    for (final raw in rawAxes) {
      if (raw is! Map) continue;
      final map = raw;
      final name = map['axis'] as String?;
      axes.add(RawAxisRange(
        axis: PadAxis.values.firstWhere(
          (a) => a.name == name,
          orElse: () => PadAxis.leftX,
        ),
        min: (map['min'] as num?)?.toDouble() ?? -1,
        max: (map['max'] as num?)?.toDouble() ?? 1,
        flat: (map['flat'] as num?)?.toDouble() ?? 0,
        fuzz: (map['fuzz'] as num?)?.toDouble() ?? 0,
        resolution: (map['resolution'] as num?)?.toDouble() ?? 0,
      ));
    }
    return PadCapabilities(
      axes: axes,
      buttonBits: (json['buttonBits'] as num?)?.toInt() ?? 0,
      vibratorCount: (json['vibratorCount'] as num?)?.toInt() ?? 0,
      hasBattery: json['hasBattery'] == true,
      hasLight: json['hasLight'] == true,
      hasMotion: json['hasMotion'] == true,
      hasTouchpad: json['hasTouchpad'] == true,
      hasMicrophone: json['hasMicrophone'] == true,
    );
  }
}

/// Une manette telle qu'exposée par la plateforme.
class PadDevice {
  const PadDevice({
    required this.id,
    required this.name,
    this.vendorId,
    this.productId,
    this.descriptor,
    this.controllerNumber = 0,
    this.sources = 0,
    this.connection = ConnectionGuess.unknown,
    this.capabilities = const PadCapabilities(),
    this.isExternal = true,
    this.profileId,
  });

  final int id;
  final String name;
  final int? vendorId;
  final int? productId;
  final String? descriptor;
  final int controllerNumber;
  final int sources;
  final ConnectionGuess connection;
  final PadCapabilities capabilities;
  final bool isExternal;

  /// Profil de glyphes / remap associé (déduit du VID/PID ou du nom).
  final String? profileId;

  /// Clé stable : le VID/PID quand il existe, sinon le nom nettoyé.
  String get key => '${vendorId ?? 'na'}:${productId ?? 'na'}:$name';

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'vendorId': vendorId,
    'productId': productId,
    'descriptor': descriptor,
    'controllerNumber': controllerNumber,
    'sources': sources,
    'connection': connection.name,
    'capabilities': capabilities.toJson(),
    'isExternal': isExternal,
    'profileId': profileId,
  };

  /// Tolère les maps non typées renvoyées par les canaux de plateforme.
  factory PadDevice.fromJson(Map<Object?, Object?> json) => PadDevice(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? 'Manette inconnue',
    vendorId: (json['vendorId'] as num?)?.toInt(),
    productId: (json['productId'] as num?)?.toInt(),
    descriptor: json['descriptor'] as String?,
    controllerNumber: (json['controllerNumber'] as num?)?.toInt() ?? 0,
    sources: (json['sources'] as num?)?.toInt() ?? 0,
    connection: ConnectionGuess.values.firstWhere(
      (c) => c.name == json['connection'],
      orElse: () => ConnectionGuess.unknown,
    ),
    capabilities: json['capabilities'] is Map
        ? PadCapabilities.fromJson(
            (json['capabilities']! as Map).cast<String, Object?>(),
          )
        : const PadCapabilities(),
    isExternal: json['isExternal'] as bool? ?? true,
    profileId: json['profileId'] as String?,
  );
}
