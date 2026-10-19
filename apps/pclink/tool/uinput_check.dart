// Vérification manuelle du backend uinput (Linux).
//
// Crée une manette virtuelle, envoie un état, puis la retire.
// À lancer en root (ou avec les droits sur /dev/uinput) :
//   sudo dart run tool/uinput_check.dart
import 'dart:io';

import 'package:pad_core/pad_core.dart';
import 'package:pclink/src/backends/linux_uinput.dart';

Future<void> main() async {
  final pad = LinuxUinputPad();
  final ok = await pad.start();
  stdout.writeln('start=$ok');
  stdout.writeln('detail=${pad.detail}');
  if (!ok) exit(1);

  pad.submit(
    const PadState(
      pressed: {PadButton.a, PadButton.dpadLeft},
      axes: {
        PadAxis.leftX: 0.75,
        PadAxis.leftY: -0.5,
        PadAxis.rightTrigger: 1.0,
      },
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  pad.submit(PadState.idle);
  await Future<void>.delayed(const Duration(milliseconds: 120));
  await pad.stop();
  stdout.writeln('detail_apres=${pad.detail}');
  exit(0);
}
