import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

void main() {
  test('rendu PNG du modèle', () async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(900, 700);
    binding.platformDispatcher.views.first.devicePixelRatio = 2;
    // Sans ce dossier, le test échoue sur une machine neuve (et en CI).
    Directory('/tmp/shots').createSync(recursive: true);

    for (final (i, (family, yaw, pitch)) in [
      (ControllerFamily.dualSense, -0.42, 0.38),
      (ControllerFamily.dualSense, 0.0, 0.0),
      (ControllerFamily.dualSense, 3.10, 0.10),
      (ControllerFamily.xboxSeries, -0.42, 0.38),
    ].indexed) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 900, 700),
        Paint()..color = const Color(0xFF12151C),
      );
      final scene = ControllerScene.build(family, Brightness.dark);
      final painter = debugControllerPainter(
        scene: scene,
        camera: OrbitCamera(yaw: yaw, pitch: pitch),
        state: const PadState(pressed: {PadButton.a}),
        size: const Size(900, 700),
        origin: const Offset(450, 350),
      );
      painter.paint(canvas, const Size(900, 700));
      final image = recorder.endRecording().toImageSync(900, 700);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final name = '/tmp/shots/scene_$i.png';
      File(name).writeAsBytesSync(data!.buffer.asUint8List());
      // ignore: avoid_print
      print('écrit $name');
    }
  });
}
