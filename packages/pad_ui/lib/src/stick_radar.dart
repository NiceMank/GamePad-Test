import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Radar de stick : cercles de course, zone morte, traînée et point courant.
class StickRadar extends StatelessWidget {
  const StickRadar({
    super.key,
    required this.x,
    required this.y,
    this.trail = const [],
    this.deadzone = 0.08,
    this.size = 240,
    this.color,
  });

  final double x;
  final double y;
  final List<Offset> trail;
  final double deadzone;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarPainter(
          x: x,
          y: y,
          trail: trail,
          deadzone: deadzone,
          colors: c,
          accent: color ?? c.cyan,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.x,
    required this.y,
    required this.trail,
    required this.deadzone,
    required this.colors,
    required this.accent,
  });

  final double x;
  final double y;
  final List<Offset> trail;
  final double deadzone;
  final PadColors colors;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Fond radial.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.09),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Cercles de course.
    for (final r in [1.0, 0.75, 0.5, 0.25]) {
      canvas.drawCircle(
        center,
        radius * r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r == 1.0 ? 1.2 : 0.8
          ..color = r == 1.0 ? colors.line : colors.line.withValues(alpha: 0.65),
      );
    }

    // Croix.
    final axisPaint = Paint()
      ..color = colors.line.withValues(alpha: 0.8)
      ..strokeWidth = 0.8;
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), axisPaint);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), axisPaint);

    // Zone morte.
    canvas.drawCircle(
      center,
      radius * deadzone.clamp(0.0, 0.9),
      Paint()
        ..color = colors.magenta.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      center,
      radius * deadzone.clamp(0.0, 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.magenta.withValues(alpha: 0.75),
    );

    // Traînée.
    if (trail.length > 1) {
      final path = Path();
      for (var i = 0; i < trail.length; i++) {
        final p = Offset(
          center.dx + trail[i].dx * radius,
          center.dy + trail[i].dy * radius,
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = accent.withValues(alpha: 0.35),
      );
    }

    // Point courant.
    final dot = Offset(center.dx + x * radius, center.dy + y * radius);
    canvas.drawCircle(
      dot,
      10,
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(dot, 4, Paint()..color = accent);
    canvas.drawCircle(
      dot,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.x != x || old.y != y || old.trail.length != trail.length || old.accent != accent;
}

/// Anneau de batterie avec état et libellé central.
class BatteryRing extends StatelessWidget {
  const BatteryRing({
    super.key,
    required this.percent,
    this.size = 132,
    this.label,
    this.sublabel,
    this.color,
  });

  final double? percent;
  final double size;
  final String? label;
  final String? sublabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = (percent ?? 0) / 100;
    final accent = color ??
        (value > 0.5 ? c.green : (value > 0.2 ? c.amber : c.danger));

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0.0, 1.0),
          color: accent,
          track: c.line,
          origin: -math.pi / 2,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label ?? (percent == null ? '—' : '${percent!.round()}'),
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1,
                  color: c.text,
                ),
              ),
              if (sublabel != null)
                Padding(
                  padding: EdgeInsets.only(top: size * 0.03),
                  child: Text(
                    sublabel!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: size * 0.075,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anneau de score de santé (0-100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.score,
    required this.grade,
    this.size = 150,
  });

  final double score;
  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = (score / 100).clamp(0.0, 1.0);
    final accent = score >= 90
        ? c.green
        : score >= 60
            ? c.amber
            : c.danger;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value: value, color: accent, track: c.line, origin: -math.pi / 2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (size < 92)
                Text(
                  score.round().toString(),
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: c.text,
                  ),
                )
              else
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: score.round().toString(),
                        style: TextStyle(
                          fontSize: size * 0.26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          color: c.text,
                        ),
                      ),
                      TextSpan(
                        text: '/100',
                        style: TextStyle(
                          fontSize: size * 0.075,
                          fontWeight: FontWeight.w700,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              if (size >= 92)
                Text(
                  grade,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: size * 0.065,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.origin,
  });

  final double value;
  final Color color;
  final Color track;
  final double origin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = track,
    );

    canvas.drawArc(
      rect,
      origin,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    canvas.drawArc(
      rect,
      origin,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}
