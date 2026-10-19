import 'pad_button.dart';
import 'pad_device.dart';

/// Familles de manettes reconnues, utilisées pour le rendu 3D et les glyphes.
///
/// La détection se fait d'abord sur les identifiants USB (fiables), puis sur
/// le nom annoncé par le système, qui varie beaucoup selon le téléphone.
enum ControllerFamily {
  dualSense('DualSense', 0x054C, 0x0CE6),
  dualShock4('DualShock 4', 0x054C, 0x09CC),
  dualShock3('DualShock 3', 0x054C, 0x0268),
  xboxSeries('Xbox Series', 0x045E, 0x0B13),
  xboxOne('Xbox One', 0x045E, 0x02FD),
  xbox360('Xbox 360', 0x045E, 0x028E),
  switchPro('Switch Pro', 0x057E, 0x2009),
  joyCon('Joy-Con', 0x057E, 0x2006),
  steamDeck('Steam Deck', 0x28DE, 0x1205),
  generic('Manette', 0, 0);

  const ControllerFamily(this.label, this.vendorId, this.productId);

  final String label;
  final int vendorId;
  final int productId;

  bool get isPlayStation => this == dualSense || this == dualShock4 || this == dualShock3;
  bool get isXbox => this == xboxSeries || this == xboxOne || this == xbox360;
  bool get isNintendo => this == switchPro || this == joyCon;

  /// Disposition logique des glyphes sur les boutons de façade.
  PadLayout get layout => switch (this) {
    dualSense || dualShock4 || dualShock3 => PadLayout.playstation,
    xboxSeries || xboxOne || xbox360 => PadLayout.xbox,
    switchPro || joyCon => PadLayout.nintendo,
    _ => PadLayout.universal,
  };

  /// Détecte la famille à partir d'un appareil (VID/PID puis nom).
  static ControllerFamily detect(PadDevice? device) {
    if (device == null) return generic;
    for (final family in ControllerFamily.values) {
      if (family == generic) continue;
      if (family.vendorId != 0 &&
          family.vendorId == device.vendorId &&
          family.productId != 0 &&
          family.productId == device.productId) {
        return family;
      }
    }
    final name = device.name.toLowerCase();
    if (name.contains('dualsense') || name.contains('dualsens') || name.contains('ps5')) {
      return dualSense;
    }
    if (name.contains('dualshock 4') || name.contains('dualshock4') || name.contains('ps4')) {
      return dualShock4;
    }
    if (name.contains('dualshock 3') || name.contains('ps3')) return dualShock3;
    if (name.contains('xbox series') || name.contains('series x')) return xboxSeries;
    if (name.contains('xbox one')) return xboxOne;
    if (name.contains('xbox 360') || name.contains('xbox wireless')) return xbox360;
    if (name.contains('joy-con') || name.contains('joycon')) return joyCon;
    if (name.contains('switch pro') || name.contains('pro controller')) return switchPro;
    if (name.contains('steam deck')) return steamDeck;
    return generic;
  }
}
