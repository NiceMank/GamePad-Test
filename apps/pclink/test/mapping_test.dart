import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pclink/src/mapping.dart';

void main() {
  group('mapping Xbox', () {
    test('boutons → bits XInput', () {
      final report = toXboxReport(
        const PadState(
          pressed: {PadButton.a, PadButton.dpadUp, PadButton.start, PadButton.r1, PadButton.l3},
        ),
      );
      expect(report.buttons & XboxButtons.a, XboxButtons.a);
      expect(report.buttons & XboxButtons.dpadUp, XboxButtons.dpadUp);
      expect(report.buttons & XboxButtons.start, XboxButtons.start);
      expect(report.buttons & XboxButtons.leftShoulder, 0);
      expect(report.buttons & XboxButtons.rightShoulder, XboxButtons.rightShoulder);
      expect(report.buttons & XboxButtons.leftThumb, XboxButtons.leftThumb);
    });

    test('Y est inversé pour XInput', () {
      const state = PadState(
        axes: {PadAxis.leftY: 0.5, PadAxis.rightY: -1.0},
      );
      final report = toXboxReport(state);
      expect(report.leftY, lessThan(0));
      expect(report.rightY, 32767);
    });

    test('gâchettes 0..255 et saturation', () {
      const state = PadState(
        axes: {PadAxis.leftTrigger: 0.5, PadAxis.rightTrigger: 2.0},
      );
      final report = toXboxReport(state);
      expect(report.leftTrigger, 128);
      expect(report.rightTrigger, 255);
    });

    test('limites des sticks', () {
      expect(axisToI16(-2), -32767);
      expect(axisToI16(2), 32767);
      expect(triggerToU8(-1), 0);
    });
  });

  group('encodeur evdev', () {
    test('premier envoi émet axes + SYN', () {
      final encoder = EvdevEncoder();
      final events = encoder.encode(
        const PadState(axes: {PadAxis.leftX: 0.5, PadAxis.leftY: -0.5}),
      );
      expect(
        events.any((e) => e.type == Evdev.evAbs && e.code == Evdev.absX && e.value > 0),
        isTrue,
      );
      expect(events.last, const EvdevEvent(Evdev.evSyn, Evdev.synReport, 0));
    });

    test('état identique → aucun événement', () {
      final encoder = EvdevEncoder();
      const state = PadState(axes: {PadAxis.leftX: 0.25});
      encoder.encode(state);
      expect(encoder.encode(state), isEmpty);
    });

    test('bouton enfoncé puis relâché', () {
      final encoder = EvdevEncoder();
      final press = encoder.encode(const PadState(pressed: {PadButton.a}));
      expect(
        press.any((e) => e.type == Evdev.evKey && e.code == Evdev.btnSouth && e.value == 1),
        isTrue,
      );
      final release = encoder.encode(PadState.idle);
      expect(
        release.any((e) => e.type == Evdev.evKey && e.code == Evdev.btnSouth && e.value == 0),
        isTrue,
      );
    });

    test('croix directionnelle sur ABS_HAT0', () {
      final encoder = EvdevEncoder();
      final events = encoder.encode(const PadState(pressed: {PadButton.dpadLeft}));
      expect(
        events.any((e) => e.code == Evdev.absHat0X && e.value == -1),
        isTrue,
      );
    });
  });
}
