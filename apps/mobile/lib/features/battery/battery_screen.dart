import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class BatteryScreen extends StatelessWidget {
  const BatteryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final estimate = session.batteryEstimate;
    final health = session.batteryHealth;
    final readings = (session.batteryEstimator).readings;
    final percent = session.battery.percent;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Batterie', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.text)),
          const SizedBox(height: 2),
          Text(
            session.device?.name ?? 'Manette',
            style: TextStyle(fontSize: 10.5, color: c.muted),
          ),
          const SizedBox(height: 16),
          Center(
            child: BatteryRing(
              percent: percent,
              size: 168,
              sublabel: session.battery.status.labelFr.toUpperCase(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'AUTONOMIE RESTANTE',
                  value: estimate.remaining == null ? '—' : _fmt(estimate.remaining!),
                  badge: estimate.confidenceLabel,
                  tone: estimate.isReliable ? c.green : c.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'DÉCHARGE',
                  value: estimate.drainPerHour == null ? '—' : estimate.drainPerHour!.toStringAsFixed(1),
                  unit: '%/h',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'ÉTAT',
                  value: session.battery.status.labelFr,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'TEMPS DE CHARGE',
                  value: estimate.toFull == null ? '—' : _fmt(estimate.toFull!),
                ),
              ),
            ],
          ),
          if (estimate.reason != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.hourglass_bottom_rounded, size: 13, color: c.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    estimate.reason!,
                    style: TextStyle(fontSize: 10, color: c.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const SectionLabel('Santé estimée'),
          PadCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (health.score >= 85 ? c.green : health.score >= 60 ? c.amber : c.danger).withValues(alpha: 0.12),
                    border: Border.all(
                      color: (health.score >= 85 ? c.green : health.score >= 60 ? c.amber : c.danger).withValues(alpha: 0.4),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    health.grade,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: health.score >= 85 ? c.green : health.score >= 60 ? c.amber : c.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        health.measuredHours == null
                            ? 'Estimation en cours'
                            : '${health.measuredHours!.toStringAsFixed(1)} h d\'endurance mesurée',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        health.note ?? 'Garde la manette connectée pour accumuler des mesures.',
                        style: TextStyle(fontSize: 10, height: 1.4, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionLabel(
            'Historique',
            trailing: Text('${readings.length} mesures', style: TextStyle(fontSize: 9.5, color: c.muted)),
          ),
          PadCard(
            child: SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _BatteryChartPainter(readings: readings, color: c.cyan, grid: c.line),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'La manette n\'expose ni capacité de conception ni nombre de cycles. '
            'L\'autonomie et la santé sont donc estimées à partir de mesures réelles, '
            'avec un niveau de confiance affiché. Aucune valeur n\'est inventée.',
            style: TextStyle(fontSize: 10, height: 1.55, color: c.muted),
          ),
          const SizedBox(height: 14),
          if (session.simulate)
            GhostButton(
              label: 'Injecter 70 min de mesures (démo)',
              icon: Icons.science_rounded,
              onPressed: session.seedDemoBattery,
            ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return '$h h ${m.toString().padLeft(2, '0')}';
  }
}

class _BatteryChartPainter extends CustomPainter {
  _BatteryChartPainter({required this.readings, required this.color, required this.grid});

  final List<BatteryReading> readings;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    // Grille.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final usable = readings.where((r) => r.percent != null).toList();
    if (usable.length < 2) return;

    final minT = usable.first.at.millisecondsSinceEpoch.toDouble();
    final maxT = usable.last.at.millisecondsSinceEpoch.toDouble();
    final span = (maxT - minT) == 0 ? 1.0 : (maxT - minT);

    final path = Path();
    for (var i = 0; i < usable.length; i++) {
      final x = (usable[i].at.millisecondsSinceEpoch - minT) / span * size.width;
      final y = size.height - (usable[i].percent! / 100) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_BatteryChartPainter old) => old.readings.length != readings.length;
}
