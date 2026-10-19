import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _tab = 0;
  static const _tabs = ['Sticks', 'Gâchettes', 'Fréquence', 'Santé'];

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PadHeader(
            eyebrow: 'Diagnostic',
            title: 'Analyse des entrées',
          ),
          const SizedBox(height: 6),
          Text(
            session.analyzing
                ? 'Mesure en cours · ${(_analysisDuration - session.analysisElapsed).inSeconds.clamp(0, 30)} s restantes'
                : '${session.leftStick.sampleCount} échantillons · ${(session.leftStick.sampleCount * 0.016).toStringAsFixed(0)} s de capture',
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
          const SizedBox(height: 14),
          SegmentedTabs(labels: _tabs, index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 12),
          if (_tab == 0) _SticksTab(session: session),
          if (_tab == 1) _TriggersTab(session: session),
          if (_tab == 2) _PollingTab(session: session),
          if (_tab == 3) _HealthTab(session: session),
        ],
      ),
    );
  }
}

const _analysisDuration = Duration(seconds: 30);

class _SticksTab extends StatelessWidget {
  const _SticksTab({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = session.state as PadState;
    final metrics = (session.leftStick as StickAnalyzer).compute();
    final trail = (session.trail as List<dynamic>)
        .map((e) => e as Offset)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: StickRadar(
            x: state.axis(PadAxis.leftX),
            y: state.axis(PadAxis.leftY),
            trail: trail,
            deadzone: metrics.deadzonePercent / 100,
            size: 250,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'DRIFT AU REPOS',
                value: metrics.driftPercent.toStringAsFixed(1),
                unit: '%',
                badge: metrics.driftPercent < 2 ? 'OK' : 'ÉLEVÉ',
                tone: metrics.driftPercent < 2 ? c.green : c.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'ZONE MORTE',
                value: metrics.deadzonePercent.toStringAsFixed(1),
                unit: '%',
                badge: metrics.deadzonePercent < 10 ? 'OK' : 'LARGE',
                tone: metrics.deadzonePercent < 10 ? c.green : c.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatTile(label: 'CIRCULARITÉ', value: metrics.circularityPercent.toStringAsFixed(1), unit: '%'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(label: 'COUVERTURE', value: metrics.coveragePercent.toStringAsFixed(1), unit: '%'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (session.analyzing)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (session.analysisElapsed.inMilliseconds / 30000).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: c.line,
                  valueColor: AlwaysStoppedAnimation<Color>(c.cyan),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fais tourner le stick gauche en grands cercles, puis laisse-le au repos 5 s.',
                style: TextStyle(fontSize: 10, color: c.muted),
              ),
            ],
          )
        else
          PrimaryButton(
            label: metrics.hasData ? 'Relancer une analyse 30 s' : 'Démarrer l\'analyse 30 s',
            icon: Icons.play_arrow_rounded,
            onPressed: () => session.toggleAnalysis(),
          ),
      ],
    );
  }
}

class _TriggersTab extends StatelessWidget {
  const _TriggersTab({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = (session.leftTrigger as TriggerAnalyzer).compute();
    final right = (session.rightTrigger as TriggerAnalyzer).compute();

    return Column(
      children: [
        _TriggerCard(title: 'Gâchette gauche · L2', metrics: left, color: c.cyan),
        const SizedBox(height: 10),
        _TriggerCard(title: 'Gâchette droite · R2', metrics: right, color: c.magenta),
        const SizedBox(height: 10),
        PadCard(
          child: Text(
            'Une course complète doit atteindre 97–100 %. En dessous, la gâchette '
            'n\'exploite pas toute sa plage : poussière, butée usée ou calibration d\'usine.',
            style: TextStyle(fontSize: 11, height: 1.5, color: c.muted),
          ),
        ),
      ],
    );
  }
}

class _TriggerCard extends StatelessWidget {
  const _TriggerCard({required this.title, required this.metrics, required this.color});

  final String title;
  final TriggerMetrics metrics;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.text)),
              const Spacer(),
              Text(
                metrics.verdict,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(label: 'COURSE', value: metrics.travelPercent.toStringAsFixed(0), unit: '%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(label: 'LINÉARITÉ', value: metrics.linearityPercent.toStringAsFixed(0), unit: '%'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (metrics.travelPercent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: c.line,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollingTab extends StatelessWidget {
  const _PollingTab({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = (session.polling as PollingAnalyzer).compute();

    return Column(
      children: [
        PadCard(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: m.hz.toStringAsFixed(0),
                        style: TextStyle(fontFamily: PadType.mono, fontSize: 34, fontWeight: FontWeight.w900, color: c.text),
                      ),
                      TextSpan(
                        text: ' Hz',
                        style: TextStyle(fontFamily: PadType.mono, fontSize: 13, color: c.cyan, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                  Text('fréquence de sondage estimée', style: TextStyle(fontSize: 9.5, color: c.muted)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: c.green.withValues(alpha: 0.3)),
                ),
                child: Text(m.quality, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: c.green)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: StatTile(label: 'INTERVALLE MOYEN', value: m.meanIntervalMs.toStringAsFixed(2), unit: 'ms')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'JITTER', value: m.jitterMs.toStringAsFixed(2), unit: 'ms')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: StatTile(label: 'MIN', value: m.minIntervalMs.toStringAsFixed(2), unit: 'ms')),
          const SizedBox(width: 8),
          Expanded(child: StatTile(label: 'MAX', value: m.maxIntervalMs.toStringAsFixed(2), unit: 'ms')),
        ]),
        const SizedBox(height: 10),
        PadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Distribution des intervalles', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text)),
                  const Spacer(),
                  Text('n = ${m.samples}', style: TextStyle(fontFamily: PadType.mono, fontSize: 9.5, color: c.muted)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  painter: _HistogramPainter(histogram: m.histogram, color: c.cyan, accent: c.magenta),
                  size: Size.infinite,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (session.simulate)
          Text(
            'Mode simulation : la fréquence reflète le tick de démonstration (60 Hz), pas le matériel.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9.5, color: c.muted, height: 1.4),
          ),
      ],
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({required this.histogram, required this.color, required this.accent});

  final Map<double, int> histogram;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (histogram.isEmpty) return;
    final entries = histogram.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxCount = entries.map((e) => e.value).reduce(math.max);
    final barWidth = size.width / entries.length;
    for (var i = 0; i < entries.length; i++) {
      final ratio = entries[i].value / maxCount;
      final height = math.max(2.0, ratio * (size.height - 4));
      final paint = Paint()
        ..color = entries[i].value == maxCount ? accent : color.withValues(alpha: 0.75);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * barWidth + 1, size.height - height, barWidth - 2, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.histogram != histogram;
}

class _HealthTab extends StatelessWidget {
  const _HealthTab({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final report = session.buildHealthReport() as HealthReport;

    return Column(
      children: [
        Center(child: ScoreRing(score: report.score, grade: report.gradeLabel, size: 160)),
        const SizedBox(height: 12),
        PadCard(
          child: Column(
            children: [
              for (final component in report.components) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(component.label, style: TextStyle(fontSize: 10.5, color: c.muted)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: component.ratio.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: c.line,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            component.ratio > 0.85 ? c.green : (component.ratio > 0.6 ? c.amber : c.danger),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${component.score.round()}/${component.max.round()}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontFamily: PadType.mono, fontSize: 9.5, fontWeight: FontWeight.w700, color: c.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final issue in report.issues.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: IssueTile(
              title: issue.title,
              detail: issue.detail,
              severity: switch (issue.severity) {
                IssueSeverity.critical => PadIssueLevel.critical,
                IssueSeverity.warning => PadIssueLevel.warning,
                IssueSeverity.info => PadIssueLevel.ok,
              },
            ),
          ),
      ],
    );
  }
}
