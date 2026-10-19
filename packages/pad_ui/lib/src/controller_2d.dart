import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';

import 'theme.dart';

/// Manette 2D vectorielle, pilotée par un [PadState].
///
/// Aucun asset : tout est dessiné, donc net à toutes les densités et
/// thémable instantanément (sombre / clair, couleurs par marque).
class Controller2D extends StatelessWidget {
  const Controller2D({
    super.key,
    required this.state,
    this.layout = PadLayout.playstation,
    this.height,
    this.showLabels = true,
  });

  final PadState state;
  final PadLayout layout;
  final double? height;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final widget = AspectRatio(
      aspectRatio: 280 / 168,
      child: CustomPaint(
        painter: Controller2DPainter(
          state: state,
          layout: layout,
          colors: c,
          showLabels: showLabels,
        ),
      ),
    );
    return height == null ? widget : SizedBox(height: height, child: widget);
  }
}

class Controller2DPainter extends CustomPainter {
  Controller2DPainter({
    required this.state,
    required this.layout,
    required this.colors,
    required this.showLabels,
  });

  final PadState state;
  final PadLayout layout;
  final PadColors colors;
  final bool showLabels;

  /// Dessine la manette dans un canvas quelconque (utilisé par le rendu 3D).
  void paintScaled(Canvas canvas, Size size) => paint(canvas, size);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 280.0;
    canvas.save();
    canvas.scale(scale, scale);

    final bodyPath = _bodyPath();
    final bodyRect = bodyPath.getBounds();

    // Ombre + corps.
    canvas.drawPath(
      bodyPath.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: colors.isDark ? 0.45 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.isDark
              ? [const Color(0xFF1B2740), const Color(0xFF0A111D)]
              : [const Color(0xFFFDFEFF), const Color(0xFFE7EEF8)],
        ).createShader(bodyRect),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = colors.isDark ? const Color(0xFF31425F) : const Color(0xFFC9D6E6),
    );

    // Bumpers.
    _bumper(canvas, const Rect.fromLTWH(69, 18, 38, 9), PadButton.l1);
    _bumper(canvas, const Rect.fromLTWH(173, 18, 38, 9), PadButton.r1);

    // Touchpad + bouton PS.
    _touchpad(canvas);

    // D-pad.
    _dpad(canvas);

    // Boutons de façade.
    _faceButton(canvas, const Offset(198, 47), PadButton.y);
    _faceButton(canvas, const Offset(217, 66), PadButton.b);
    _faceButton(canvas, const Offset(198, 85), PadButton.a);
    _faceButton(canvas, const Offset(179, 66), PadButton.x);

    // Sticks.
    _stick(canvas, const Offset(100, 120), PadAxis.leftX, PadAxis.leftY, PadButton.l3, colors.cyan);
    _stick(canvas, const Offset(180, 120), PadAxis.rightX, PadAxis.rightY, PadButton.r3, colors.magenta);

    canvas.restore();
  }

  Path _bodyPath() => Path()
    ..moveTo(96, 28)
    ..lineTo(184, 28)
    ..cubicTo(207, 28, 221, 42, 224, 62)
    ..cubicTo(227, 80, 220, 91, 227, 107)
    ..cubicTo(235, 125, 231, 148, 217, 153)
    ..cubicTo(203, 158, 190, 143, 181, 129)
    ..lineTo(172, 117)
    ..lineTo(108, 117)
    ..lineTo(99, 129)
    ..cubicTo(90, 143, 77, 158, 63, 153)
    ..cubicTo(49, 148, 45, 125, 53, 107)
    ..cubicTo(60, 91, 53, 80, 56, 62)
    ..cubicTo(59, 42, 73, 28, 96, 28)
    ..close();

  void _bumper(Canvas canvas, Rect rect, PadButton button) {
    final pressed = state.isPressed(button);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4.5)),
      Paint()
        ..color = pressed
            ? colors.cyan.withValues(alpha: 0.85)
            : (colors.isDark ? const Color(0xFF172236) : const Color(0xFFDCE6F2)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = pressed ? colors.cyan : (colors.isDark ? const Color(0xFF2B3A55) : const Color(0xFFC2D0E2)),
    );
  }

  void _touchpad(Canvas canvas) {
    const rect = Rect.fromLTWH(111, 39, 58, 29);
    final pressed = state.isPressed(PadButton.touchpad);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()..color = colors.isDark ? const Color(0xFF0A111D) : const Color(0xFFF1F5FA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pressed ? 1.6 : 1
        ..color = pressed ? colors.cyan : (colors.isDark ? const Color(0xFF2C3D59) : const Color(0xFFC9D6E6)),
    );

    // Bouton PS sous le touchpad.
    final ps = Offset(140, 77);
    canvas.drawCircle(ps, 4.6, Paint()..color = colors.isDark ? const Color(0xFF0D1626) : const Color(0xFFE4ECF6));
    canvas.drawCircle(
      ps,
      4.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = state.isPressed(PadButton.guide)
            ? colors.cyan
            : (colors.isDark ? const Color(0xFF31425F) : const Color(0xFFC9D6E6)),
    );
  }

  void _dpad(Canvas canvas) {
    const center = Offset(82, 66);
    const arm = 17.0;
    const thick = 10.0;
    final entries = <(PadButton, Rect)>[
      (PadButton.dpadUp, Rect.fromCenter(center: Offset(center.dx, center.dy - arm / 2), width: thick, height: arm)),
      (PadButton.dpadDown, Rect.fromCenter(center: Offset(center.dx, center.dy + arm / 2), width: thick, height: arm)),
      (PadButton.dpadLeft, Rect.fromCenter(center: Offset(center.dx - arm / 2, center.dy), width: arm, height: thick)),
      (PadButton.dpadRight, Rect.fromCenter(center: Offset(center.dx + arm / 2, center.dy), width: arm, height: thick)),
    ];
    for (final (button, rect) in entries) {
      final pressed = state.isPressed(button);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.4)),
        Paint()
          ..color = pressed
              ? colors.cyan
              : (colors.isDark ? const Color(0xFF111A2A) : const Color(0xFFE9EFF7)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2.4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = pressed ? colors.cyan : (colors.isDark ? const Color(0xFF31425F) : const Color(0xFFC9D6E6)),
      );
    }
  }

  void _faceButton(Canvas canvas, Offset center, PadButton button) {
    final pressed = state.isPressed(button);
    final accent = switch (button) {
      PadButton.y => colors.green,
      PadButton.b => colors.magenta,
      PadButton.a => colors.cyan,
      PadButton.x => const Color(0xFFB98CFF),
      _ => colors.cyan,
    };

    if (pressed) {
      canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(
      center,
      7.6,
      Paint()
        ..color = pressed
            ? accent.withValues(alpha: 0.22)
            : (colors.isDark ? const Color(0xFF101A2A) : const Color(0xFFF7FAFE)),
    );
    canvas.drawCircle(
      center,
      7.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accent.withValues(alpha: pressed ? 1 : 0.75),
    );

    if (showLabels) {
      _text(canvas, button.glyph(layout), center, accent, 7.5);
    }
  }

  void _stick(
    Canvas canvas,
    Offset center,
    PadAxis axisX,
    PadAxis axisY,
    PadButton click,
    Color accent,
  ) {
    final x = state.axis(axisX).clamp(-1.0, 1.0);
    final y = state.axis(axisY).clamp(-1.0, 1.0);
    final pressed = state.isPressed(click);

    // Puits.
    canvas.drawCircle(center, 17.5, Paint()..color = colors.isDark ? const Color(0xFF0A101B) : const Color(0xFFE6EDF6));
    canvas.drawCircle(
      center,
      17.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.isDark ? const Color(0xFF2B3A55) : const Color(0xFFC9D6E6),
    );

    // Croix de repère.
    final tick = Paint()
      ..color = colors.isDark ? const Color(0xFF31425F) : const Color(0xFFC9D6E6)
      ..strokeWidth = 1;
    canvas.drawLine(center + const Offset(0, -21), center + const Offset(0, -17), tick);
    canvas.drawLine(center + const Offset(0, 17), center + const Offset(0, 21), tick);
    canvas.drawLine(center + const Offset(-21, 0), center + const Offset(-17, 0), tick);
    canvas.drawLine(center + const Offset(17, 0), center + const Offset(21, 0), tick);

    // Chapeau mobile.
    final knob = center + Offset(x * 9.5, y * 9.5);
    if (pressed) {
      canvas.drawCircle(
        knob,
        12,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(knob, 9.8, Paint()..color = colors.isDark ? const Color(0xFF152238) : const Color(0xFFD7E2F0));
    canvas.drawCircle(
      knob,
      9.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = pressed ? accent : (colors.isDark ? const Color(0xFF37506F) : const Color(0xFFB6C6DA)),
    );
    canvas.drawCircle(knob + const Offset(-2.5, -2.5), 1.6, Paint()..color = accent.withValues(alpha: 0.9));
  }

  void _text(Canvas canvas, String text, Offset center, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(Controller2DPainter old) =>
      old.state != state || old.layout != layout || old.colors != colors;
}

/// Petite vignette de manette, pour les listes et les cartes.
class ControllerGlyph extends StatelessWidget {
  const ControllerGlyph({super.key, this.size = 44, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.cyan;
    return SizedBox(
      width: size,
      height: size * 0.8,
      child: CustomPaint(painter: _GlyphPainter(c)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 60.0;
    canvas.save();
    canvas.scale(scale, scale);
    final body = Path()
      ..moveTo(18, 7)
      ..lineTo(42, 7)
      ..cubicTo(48, 7, 52, 11, 53, 18)
      ..cubicTo(53.6, 23, 52, 27, 55, 32)
      ..cubicTo(57, 36, 56, 41, 52, 42)
      ..cubicTo(48, 43, 44, 39, 42, 36)
      ..lineTo(39, 32)
      ..lineTo(21, 32)
      ..lineTo(18, 36)
      ..cubicTo(16, 39, 12, 43, 8, 42)
      ..cubicTo(4, 41, 3, 36, 5, 32)
      ..cubicTo(8, 27, 6.4, 23, 7, 18)
      ..cubicTo(8, 11, 12, 7, 18, 7)
      ..close();
    canvas.drawPath(body, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: 0.7),
    );
    canvas.drawCircle(const Offset(19, 26), 4.6, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(const Offset(41, 26), 4.6, Paint()..color = color.withValues(alpha: 0.55));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.color != color;
}

/// Barre de gâchette analogique.
class TriggerBar extends StatelessWidget {
  const TriggerBar({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.isRight = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool isRight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = color ?? (isRight ? c.magenta : c.cyan);
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.muted,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 8, color: c.line),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent.withValues(alpha: 0.85), accent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).round()} %',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
      ],
    );
  }
}
