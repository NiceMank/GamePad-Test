import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

void main() {
  test('cout detaille', () {
    final scene = ControllerScene.build(ControllerFamily.dualSense, Brightness.light);
    const size = Size(430, 260);
    final painter = debugControllerPainter(
      scene: scene,
      camera: OrbitCamera(yaw: -0.42, pitch: 0.38),
      state: const PadState(),
      size: size,
      origin: const Offset(215, 130),
    );
    for (var i = 0; i < 3; i++) {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }
  });
}
