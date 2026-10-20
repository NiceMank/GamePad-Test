import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

/// Mesure le coût Dart du painter 3D (hors rasterisation GPU).
void main() {
  test('cout d une image', () {
    final scene = ControllerScene.build(ControllerFamily.dualSense, Brightness.light);
    const size = Size(430, 260);
    final painter = debugControllerPainter(
      scene: scene,
      camera: OrbitCamera(yaw: -0.42, pitch: 0.38),
      state: const PadState(),
      size: size,
      origin: const Offset(215, 130),
    );

    // Chauffe (compilation JIT des chemins chauds).
    for (var i = 0; i < 30; i++) {
      final rec = ui.PictureRecorder();
      painter.paint(Canvas(rec), size);
      rec.endRecording().dispose();
    }

    const frames = 300;
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      painter.paint(canvas, size);
      rec.endRecording().dispose();
    }
    sw.stop();
    // ignore: avoid_print
    print('BENCH painter: ${(sw.elapsedMicroseconds / frames / 1000).toStringAsFixed(3)} ms/image');
  });
}
