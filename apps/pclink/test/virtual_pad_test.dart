import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pclink/src/backends/null_pad.dart';
import 'package:pclink/src/virtual_pad_factory.dart';

void main() {
  test('le backend se crée et retombe proprement sans driver', () async {
    final pad = await createVirtualPad();
    addTearDown(pad.stop);
    expect(pad.backend, isNotEmpty);
    if (!pad.ready) {
      expect(pad.detail, isNotEmpty);
    }
    // Aucune exception même si le périphérique n'existe pas.
    pad.submit(const PadState(pressed: {PadButton.a}));
    pad.submit(PadState.idle);
  });

  test('NullPad compte les rapports et mappe les bits', () async {
    final pad = NullPad();
    await pad.start();
    pad.submit(const PadState(pressed: {PadButton.a, PadButton.dpadLeft}));
    expect(pad.reports, 1);
    expect(pad.lastReport.buttons & 0x1000, 0x1000); // A
    expect(pad.lastReport.buttons & 0x0004, 0x0004); // gauche
    await pad.stop();
    expect(pad.ready, isFalse);
  });
}
