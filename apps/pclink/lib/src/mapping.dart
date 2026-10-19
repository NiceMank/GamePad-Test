import 'package:pad_core/pad_core.dart';

/// Bits `wButtons` du rapport XInput (XUSB_GAMEPAD_*).
abstract final class XboxButtons {
  static const dpadUp = 0x0001;
  static const dpadDown = 0x0002;
  static const dpadLeft = 0x0004;
  static const dpadRight = 0x0008;
  static const start = 0x0010;
  static const back = 0x0020;
  static const leftThumb = 0x0040;
  static const rightThumb = 0x0080;
  static const leftShoulder = 0x0100;
  static const rightShoulder = 0x0200;
  static const guide = 0x0400;
  static const a = 0x1000;
  static const b = 0x2000;
  static const x = 0x4000;
  static const y = 0x8000;
}

/// Rapport Xbox 360 prêt à être envoyé à ViGEm.
class XboxReport {
  const XboxReport({
    this.buttons = 0,
    this.leftTrigger = 0,
    this.rightTrigger = 0,
    this.leftX = 0,
    this.leftY = 0,
    this.rightX = 0,
    this.rightY = 0,
  });

  final int buttons;
  final int leftTrigger; // 0..255
  final int rightTrigger; // 0..255
  final int leftX; // -32768..32767
  final int leftY;
  final int rightX;
  final int rightY;

  bool get isEmpty =>
      buttons == 0 &&
      leftTrigger == 0 &&
      rightTrigger == 0 &&
      leftX.abs() < 32 &&
      leftY.abs() < 32 &&
      rightX.abs() < 32 &&
      rightY.abs() < 32;

  Map<String, int> toMap() => {
    'buttons': buttons,
    'leftTrigger': leftTrigger,
    'rightTrigger': rightTrigger,
    'leftX': leftX,
    'leftY': leftY,
    'rightX': rightX,
    'rightY': rightY,
  };

  @override
  String toString() => 'XboxReport(${toMap()})';
}

int axisToI16(double value) =>
    (value.clamp(-1.0, 1.0) * 32767).round().clamp(-32768, 32767);

int triggerToU8(double value) => (value.clamp(0.0, 1.0) * 255).round();

/// Conversion PadLab → Xbox 360.
///
/// Convention : dans PadLab, Y positif = **vers le bas** ; XInput attend
/// Y positif = vers le haut, d'où l'inversion.
XboxReport toXboxReport(PadState state) {
  var buttons = 0;
  void set(PadButton b, int bit) {
    if (state.isPressed(b)) buttons |= bit;
  }

  set(PadButton.dpadUp, XboxButtons.dpadUp);
  set(PadButton.dpadDown, XboxButtons.dpadDown);
  set(PadButton.dpadLeft, XboxButtons.dpadLeft);
  set(PadButton.dpadRight, XboxButtons.dpadRight);
  set(PadButton.start, XboxButtons.start);
  set(PadButton.select, XboxButtons.back);
  set(PadButton.l3, XboxButtons.leftThumb);
  set(PadButton.r3, XboxButtons.rightThumb);
  set(PadButton.l1, XboxButtons.leftShoulder);
  set(PadButton.r1, XboxButtons.rightShoulder);
  set(PadButton.guide, XboxButtons.guide);
  set(PadButton.a, XboxButtons.a);
  set(PadButton.b, XboxButtons.b);
  set(PadButton.x, XboxButtons.x);
  set(PadButton.y, XboxButtons.y);

  return XboxReport(
    buttons: buttons,
    leftTrigger: triggerToU8(state.axis(PadAxis.leftTrigger)),
    rightTrigger: triggerToU8(state.axis(PadAxis.rightTrigger)),
    leftX: axisToI16(state.axis(PadAxis.leftX)),
    leftY: axisToI16(-state.axis(PadAxis.leftY)),
    rightX: axisToI16(state.axis(PadAxis.rightX)),
    rightY: axisToI16(-state.axis(PadAxis.rightY)),
  );
}

/// Codes evdev Linux utilisés par la manette virtuelle.
abstract final class Evdev {
  static const synReport = 0;
  static const evSyn = 0x00;
  static const evKey = 0x01;
  static const evAbs = 0x03;

  static const absX = 0x00;
  static const absY = 0x01;
  static const absZ = 0x02;
  static const absRx = 0x03;
  static const absRy = 0x04;
  static const absRz = 0x05;
  static const absHat0X = 0x10;
  static const absHat0Y = 0x11;

  static const btnSouth = 0x130; // A
  static const btnEast = 0x131; // B
  static const btnNorth = 0x133; // X
  static const btnWest = 0x134; // Y
  static const btnTL = 0x136;
  static const btnTR = 0x137;
  static const btnTL2 = 0x138;
  static const btnTR2 = 0x139;
  static const btnSelect = 0x13a;
  static const btnStart = 0x13b;
  static const btnMode = 0x13c;
  static const btnThumbL = 0x13d;
  static const btnThumbR = 0x13e;
}

/// Un événement evdev : (type, code, valeur).
class EvdevEvent {
  const EvdevEvent(this.type, this.code, this.value);
  final int type;
  final int code;
  final int value;

  @override
  String toString() => 'EvdevEvent($type, $code, $value)';

  @override
  bool operator ==(Object other) =>
      other is EvdevEvent &&
      other.type == type &&
      other.code == code &&
      other.value == value;

  @override
  int get hashCode => Object.hash(type, code, value);
}

/// Encodeur incrémental : n'envoie que ce qui a changé, plus un SYN_REPORT.
///
/// Écrire les 16 valeurs à chaque paquet coûterait 16 `write()` par frame ;
/// en différentiel on tombe à ~1–3 écritures quand la manette bouge.
class EvdevEncoder {
  int? _buttons;
  int? _leftX, _leftY, _rightX, _rightY;
  int? _leftTrigger, _rightTrigger;

  List<EvdevEvent> encode(PadState state) {
    final events = <EvdevEvent>[];

    void emitIfChanged(int? previous, int code, int value) {
      if (previous != value) events.add(EvdevEvent(Evdev.evAbs, code, value));
    }

    final lx = axisToI16(state.axis(PadAxis.leftX));
    final ly = axisToI16(state.axis(PadAxis.leftY));
    final rx = axisToI16(state.axis(PadAxis.rightX));
    final ry = axisToI16(state.axis(PadAxis.rightY));
    final lt = triggerToU8(state.axis(PadAxis.leftTrigger));
    final rt = triggerToU8(state.axis(PadAxis.rightTrigger));

    emitIfChanged(_leftX, Evdev.absX, lx);
    emitIfChanged(_leftY, Evdev.absY, ly);
    emitIfChanged(_rightX, Evdev.absRx, rx);
    emitIfChanged(_rightY, Evdev.absRy, ry);
    emitIfChanged(_leftTrigger, Evdev.absZ, lt);
    emitIfChanged(_rightTrigger, Evdev.absRz, rt);

    // Croix directionnelle : ABS_HAT0X/Y (-1, 0, 1).
    final hatX = state.isPressed(PadButton.dpadLeft)
        ? -1
        : state.isPressed(PadButton.dpadRight)
        ? 1
        : 0;
    final hatY = state.isPressed(PadButton.dpadUp)
        ? -1
        : state.isPressed(PadButton.dpadDown)
        ? 1
        : 0;
    emitIfChanged(_hatX, Evdev.absHat0X, hatX);
    emitIfChanged(_hatY, Evdev.absHat0Y, hatY);

    final buttons = _buttonMask(state.pressed);
    if (_buttons != buttons) {
      final changed = (_buttons ?? 0) ^ buttons;
      for (final entry in _buttonCodes.entries) {
        if (changed & (1 << entry.key.index) != 0) {
          events.add(
            EvdevEvent(
              Evdev.evKey,
              entry.value,
              buttons & (1 << entry.key.index) != 0 ? 1 : 0,
            ),
          );
        }
      }
    }

    _leftX = lx;
    _leftY = ly;
    _rightX = rx;
    _rightY = ry;
    _leftTrigger = lt;
    _rightTrigger = rt;
    _hatX = hatX;
    _hatY = hatY;
    _buttons = buttons;

    if (events.isNotEmpty) {
      events.add(const EvdevEvent(Evdev.evSyn, Evdev.synReport, 0));
    }
    return events;
  }

  int? _hatX;
  int? _hatY;

  static const Map<PadButton, int> _buttonCodes = {
    PadButton.a: Evdev.btnSouth,
    PadButton.b: Evdev.btnEast,
    PadButton.x: Evdev.btnNorth,
    PadButton.y: Evdev.btnWest,
    PadButton.l1: Evdev.btnTL,
    PadButton.r1: Evdev.btnTR,
    PadButton.l2: Evdev.btnTL2,
    PadButton.r2: Evdev.btnTR2,
    PadButton.select: Evdev.btnSelect,
    PadButton.start: Evdev.btnStart,
    PadButton.guide: Evdev.btnMode,
    PadButton.l3: Evdev.btnThumbL,
    PadButton.r3: Evdev.btnThumbR,
  };

  int _buttonMask(Set<PadButton> pressed) {
    var mask = 0;
    for (final b in pressed) {
      final bit = _buttonCodes[b];
      if (bit == null) continue;
      mask |= 1 << b.index;
    }
    return mask;
  }

  /// Codes evdev à déclarer à l'ouverture du périphérique.
  static List<int> get keyCodes => _buttonCodes.values.toList()..sort();
}
