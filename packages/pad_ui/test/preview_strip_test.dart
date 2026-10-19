import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

/// Planches de contrôle visuel : une série de rotations et un tour d'horizon
/// des modèles. Servent d'aperçu (docs/captures) et de garde-fou : si le
/// rendu casse, la planche le montre immédiatement.
///
///   flutter test test/preview_strip_test.dart
void main() {
  const cell = Size(300, 260);

  setUpAll(() async {
    // Sans police chargée, les libellés sortent en rectangles.
    final loader = FontLoader('Inter');
    for (final file in ['Inter-Regular', 'Inter-SemiBold']) {
      final bytes = File('assets/fonts/$file.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  });

  Future<void> renderStrip(
    String path,
    List<({ControllerFamily family, double yaw, double pitch, Brightness light})> frames,
    int columns,
  ) async {
    final rows = (frames.length / columns).ceil();
    final width = cell.width * columns;
    final height = cell.height * rows;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF10131A),
    );

    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final col = i % columns;
      final row = i ~/ columns;
      final origin = Offset(
        col * cell.width + cell.width / 2,
        row * cell.height + cell.height / 2 - 8,
      );
      final scene = ControllerScene.build(f.family, f.light);
      debugControllerPainter(
        scene: scene,
        camera: OrbitCamera(yaw: f.yaw, pitch: f.pitch),
        state: const PadState(),
        size: cell,
        origin: origin,
      ).paint(canvas, Size(width, height));

      final tp = TextPainter(
        text: TextSpan(
          text: '${f.family.label} · ${(f.yaw * 180 / math.pi).round()}°',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF8B9099),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          col * cell.width + (cell.width - tp.width) / 2,
          row * cell.height + cell.height - 22,
        ),
      );
    }

    final image = recorder.endRecording().toImageSync(width.round(), height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  }

  test('planches de rotation', () async {
    final dir = Directory('../../docs/captures')..createSync(recursive: true);
    await renderStrip(
      '${dir.path}/rotation_dualsense.png',
      [
        for (var i = 0; i < 8; i++)
          (
            family: ControllerFamily.dualSense,
            yaw: i * math.pi / 4,
            pitch: 0.24,
            light: Brightness.light,
          ),
      ],
      4,
    );
    await renderStrip(
      '${dir.path}/familles.png',
      [
        for (final family in [
          ControllerFamily.dualSense,
          ControllerFamily.dualShock4,
          ControllerFamily.xboxSeries,
          ControllerFamily.switchPro,
          ControllerFamily.steamDeck,
          ControllerFamily.generic,
        ])
          (family: family, yaw: -0.38, pitch: 0.30, light: Brightness.light),
      ],
      3,
    );
    // ignore: avoid_print
    print('planches écrites dans ${dir.path}');
  });
}
