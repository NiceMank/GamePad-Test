import 'dart:math' as math;

import '../models/pad_axis.dart';
import '../models/pad_button.dart';
import '../models/pad_state.dart';
import 'remap_profile.dart';

/// Applique un [RemapProfile] à un état d'entrée.
///
/// Le moteur est pur : pas d'I/O, pas d'horloge implicite. `nowUs` sert
/// uniquement au turbo, ce qui rend le comportement testable.
class RemapEngine {
  const RemapEngine();

  PadState apply(PadState input, RemapProfile profile, {int nowUs = 0}) {
    if (profile.isNeutral) return input;

    final outButtons = <PadButton>{};
    for (final button in input.pressed) {
      final target = profile.targetOf(button);
      if (target != null) outButtons.add(target);
    }

    // Turbo : hache le bouton maintenu à la fréquence demandée.
    if (profile.turboButtons.isNotEmpty && profile.turboHz > 0) {
      final period = 1e6 / profile.turboHz;
      final phase = (nowUs % (period * 2)) < period;
      if (!phase) {
        for (final b in profile.turboButtons) {
          final target = profile.targetOf(b);
          if (target != null) outButtons.remove(target);
        }
      }
    }

    // Sticks.
    final left = _stick(
      input.axis(PadAxis.leftX),
      input.axis(PadAxis.leftY),
      profile.leftStick,
    );
    final right = _stick(
      input.axis(PadAxis.rightX),
      input.axis(PadAxis.rightY),
      profile.rightStick,
    );

    // Stick gauche -> D-pad.
    if (profile.stickToDpad) {
      final magnitude = math.sqrt(left.$1 * left.$1 + left.$2 * left.$2);
      if (magnitude >= profile.stickToDpadThreshold) {
        final angle = math.atan2(left.$2, left.$1);
        final dx = math.cos(angle);
        final dy = math.sin(angle);
        if (dx > 0.38) outButtons.add(PadButton.dpadRight);
        if (dx < -0.38) outButtons.add(PadButton.dpadLeft);
        if (dy > 0.38) outButtons.add(PadButton.dpadDown);
        if (dy < -0.38) outButtons.add(PadButton.dpadUp);
      }
    }

    // Gâchettes.
    final lt = profile.leftTrigger.normalize(input.axis(PadAxis.leftTrigger));
    final rt = profile.rightTrigger.normalize(input.axis(PadAxis.rightTrigger));
    if (profile.leftTrigger.asButton && lt >= profile.leftTrigger.threshold) {
      final target = profile.targetOf(PadButton.l2);
      if (target != null) outButtons.add(target);
    }
    if (profile.rightTrigger.asButton && rt >= profile.rightTrigger.threshold) {
      final target = profile.targetOf(PadButton.r2);
      if (target != null) outButtons.add(target);
    }

    return PadState(
      pressed: outButtons,
      axes: {
        PadAxis.leftX: left.$1,
        PadAxis.leftY: left.$2,
        PadAxis.rightX: right.$1,
        PadAxis.rightY: right.$2,
        PadAxis.leftTrigger: lt,
        PadAxis.rightTrigger: rt,
      },
      rawAxes: input.rawAxes,
      timestampUs: input.timestampUs,
      sequence: input.sequence,
    );
  }

  /// Applique zone morte radiale, courbe, inversion et sensibilité.
  (double, double) _stick(double x, double y, AxisSettings settings) {
    var dx = settings.invertX ? -x : x;
    var dy = settings.invertY ? -y : y;

    final magnitude = math.sqrt(dx * dx + dy * dy);
    if (magnitude <= settings.deadzone) return (0.0, 0.0);

    // Remise à l'échelle après la zone morte pour conserver toute la course.
    final scaled = (magnitude - settings.deadzone) / (1 - settings.deadzone);
    final angle = math.atan2(dy, dx);
    var nx = math.cos(angle) * scaled;
    var ny = math.sin(angle) * scaled;

    nx = settings.curveValue(nx) * settings.sensitivity;
    ny = settings.curveValue(ny) * settings.sensitivity;

    return (nx.clamp(-1.0, 1.0), ny.clamp(-1.0, 1.0));
  }
}
