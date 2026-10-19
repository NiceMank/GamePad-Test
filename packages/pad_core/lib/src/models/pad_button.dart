/// Boutons logiques, indépendants du matériel.
///
/// L'ordre n'a pas d'importance : ce sont les bitmasks du protocole qui sont
/// figés (voir [padButtonBit]).
enum PadButton {
  a,
  b,
  x,
  y,
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
  l1,
  r1,
  l2,
  r2,
  l3,
  r3,
  start,
  select,
  guide,
  share,
  touchpad,
  mic,
  paddle1,
  paddle2,
}

/// Bitmask stable utilisé sur le fil et dans les rapports.
int padButtonBit(PadButton button) => 1 << button.index;

/// Glyphes par famille de manette.
enum PadLayout { android, playstation, xbox, nintendo, universal }

extension PadButtonGlyph on PadButton {
  String glyph(PadLayout layout) {
    switch (this) {
      case PadButton.a:
        return switch (layout) {
          PadLayout.playstation => '✕',
          PadLayout.nintendo => 'B',
          PadLayout.universal => 'A',
          _ => 'A',
        };
      case PadButton.b:
        return switch (layout) {
          PadLayout.playstation => '○',
          PadLayout.nintendo => 'A',
          _ => 'B',
        };
      case PadButton.x:
        return switch (layout) {
          PadLayout.playstation => '□',
          PadLayout.nintendo => 'Y',
          _ => 'X',
        };
      case PadButton.y:
        return switch (layout) {
          PadLayout.playstation => '△',
          PadLayout.nintendo => 'X',
          _ => 'Y',
        };
      case PadButton.dpadUp:
        return '↑';
      case PadButton.dpadDown:
        return '↓';
      case PadButton.dpadLeft:
        return '←';
      case PadButton.dpadRight:
        return '→';
      case PadButton.l1:
        return layout == PadLayout.playstation ? 'L1' : 'LB';
      case PadButton.r1:
        return layout == PadLayout.playstation ? 'R1' : 'RB';
      case PadButton.l2:
        return layout == PadLayout.playstation ? 'L2' : 'LT';
      case PadButton.r2:
        return layout == PadLayout.playstation ? 'R2' : 'RT';
      case PadButton.l3:
        return 'L3';
      case PadButton.r3:
        return 'R3';
      case PadButton.start:
        return layout == PadLayout.playstation ? 'OPT' : 'START';
      case PadButton.select:
        return layout == PadLayout.playstation ? 'SHARE' : 'SELECT';
      case PadButton.guide:
        return layout == PadLayout.playstation ? 'PS' : 'GUIDE';
      case PadButton.share:
        return 'SHARE';
      case PadButton.touchpad:
        return 'TOUCH';
      case PadButton.mic:
        return 'MIC';
      case PadButton.paddle1:
        return 'P1';
      case PadButton.paddle2:
        return 'P2';
    }
  }

  /// Libellé stable pour les rapports et les profils (jamais traduit).
  String get id => name;
}
