import 'pad_axis.dart';
import 'pad_button.dart';

/// Photo d'une manette à un instant donné.
///
/// Les valeurs sont **normalisées** (sticks -1..1, gâchettes 0..1) mais on
/// conserve toujours les valeurs brutes, seules capables de révéler une
/// résolution ou une zone morte matérielle.
class PadState {
  const PadState({
    this.pressed = const {},
    this.axes = const {},
    this.rawAxes = const {},
    this.timestampUs = 0,
    this.sequence = 0,
  });

  final Set<PadButton> pressed;
  final Map<PadAxis, double> axes;
  final Map<PadAxis, double> rawAxes;
  final int timestampUs;
  final int sequence;

  static const PadState idle = PadState();

  double axis(PadAxis axis) => axes[axis] ?? (axis.isTrigger ? 0.0 : 0.0);

  double rawAxis(PadAxis axis) => rawAxes[axis] ?? 0.0;

  bool isPressed(PadButton button) => pressed.contains(button);

  /// Intensité d'un bouton, 0..1.
  ///
  /// Les gâchettes analogiques renvoient leur course (utile pour allumer le
  /// modèle 3D progressivement) ; les autres boutons valent 1 s'ils sont
  /// enfoncés.
  double axisForButton(PadButton button) {
    switch (button) {
      case PadButton.l2:
        return axis(PadAxis.leftTrigger);
      case PadButton.r2:
        return axis(PadAxis.rightTrigger);
      default:
        return isPressed(button) ? 1 : 0;
    }
  }

  bool get hasInput =>
      pressed.isNotEmpty ||
      axes.values.any((v) => v.abs() > 0.02);

  PadState copyWith({
    Set<PadButton>? pressed,
    Map<PadAxis, double>? axes,
    Map<PadAxis, double>? rawAxes,
    int? timestampUs,
    int? sequence,
  }) => PadState(
    pressed: pressed ?? this.pressed,
    axes: axes ?? this.axes,
    rawAxes: rawAxes ?? this.rawAxes,
    timestampUs: timestampUs ?? this.timestampUs,
    sequence: sequence ?? this.sequence,
  );

  /// Applique un delta (utile quand la plateforme n'envoie que les changements).
  PadState merge({
    PadButton? pressedButton,
    bool? isDown,
    PadAxis? axis,
    double? value,
    double? rawValue,
    int? timestampUs,
    int? sequence,
  }) {
    final nextPressed = {...pressed};
    if (pressedButton != null && isDown != null) {
      if (isDown) {
        nextPressed.add(pressedButton);
      } else {
        nextPressed.remove(pressedButton);
      }
    }
    final nextAxes = {...axes};
    final nextRaw = {...rawAxes};
    if (axis != null && value != null) {
      nextAxes[axis] = value.clamp(-1.0, 1.0);
      nextRaw[axis] = rawValue ?? value;
    }
    return PadState(
      pressed: nextPressed,
      axes: nextAxes,
      rawAxes: nextRaw,
      timestampUs: timestampUs ?? this.timestampUs,
      sequence: sequence ?? this.sequence,
    );
  }
}

/// Événement pour l'historique et le calcul de fréquence.
enum PadEventType { buttonDown, buttonUp, axis, connected, disconnected, battery, motion, touchpad }

class PadEvent {
  const PadEvent({
    required this.type,
    required this.timestampUs,
    this.button,
    this.axis,
    this.value = 0,
    this.deviceId = 0,
    this.code = 0,
  });

  final PadEventType type;
  final int timestampUs;
  final PadButton? button;
  final PadAxis? axis;
  final double value;
  final int deviceId;

  /// Code natif (keycode Android, index iOS) — précieux en mode Universal.
  final int code;
}
