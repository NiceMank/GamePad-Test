import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class TesterScreen extends StatefulWidget {
  const TesterScreen({super.key});

  @override
  State<TesterScreen> createState() => _TesterScreenState();
}

class _TesterScreenState extends State<TesterScreen> {
  static const _layouts = [
    PadLayout.android,
    PadLayout.playstation,
    PadLayout.xbox,
    PadLayout.nintendo,
    PadLayout.universal,
  ];
  static const _layoutLabels = ['Android', 'PS', 'Xbox', 'Switch', 'Univ.'];

  int _layoutIndex = 1;
  double _strong = 0.8;
  double _weak = 0.5;

  Future<void> _pulse({
    required double strong,
    required double weak,
    required int durationMs,
  }) async {
    final session = PadScope.of(context);
    await session.vibrate(strong: strong, weak: weak, durationMs: durationMs);
  }

  Future<void> _presetPulse() => _pulse(strong: _strong, weak: _weak, durationMs: 350);

  Future<void> _presetDouble() async {
    await _pulse(strong: _strong, weak: _weak, durationMs: 120);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await _pulse(strong: _strong * 0.7, weak: _weak, durationMs: 120);
  }

  Future<void> _presetRamp() async {
    for (final step in [0.25, 0.5, 0.75, 1.0]) {
      await _pulse(strong: step, weak: step * 0.8, durationMs: 110);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final state = session.state;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Test d\'entrées', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.text)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: c.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'LIVE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${session.device?.name ?? 'Manette'} · ${session.simulate ? 'simulation' : 'matériel'}',
            style: TextStyle(fontSize: 10.5, color: c.muted),
          ),
          const SizedBox(height: 12),
          SegmentedTabs(
            labels: _layoutLabels,
            index: _layoutIndex,
            compact: true,
            onChanged: (i) => setState(() => _layoutIndex = i),
          ),
          const SizedBox(height: 10),
          PadCard(
            padding: const EdgeInsets.all(6),
            child: Controller2D(state: state, layout: _layouts[_layoutIndex]),
          ),
          const SizedBox(height: 12),
          TriggerBar(label: 'L2', value: state.axis(PadAxis.leftTrigger)),
          const SizedBox(height: 6),
          TriggerBar(label: 'R2', value: state.axis(PadAxis.rightTrigger), isRight: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AxisPill(
                  label: 'L',
                  x: state.axis(PadAxis.leftX),
                  y: state.axis(PadAxis.leftY),
                  color: c.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AxisPill(
                  label: 'R',
                  x: state.axis(PadAxis.rightX),
                  y: state.axis(PadAxis.rightY),
                  color: c.magenta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionLabel('Boutons actifs', trailing: Text('${state.pressed.length} / 22', style: TextStyle(fontSize: 9.5, color: c.muted))),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final button in PadButton.values)
                _ButtonChip(
                  button: button,
                  layout: _layouts[_layoutIndex],
                  pressed: state.isPressed(button),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionLabel('Journal'),
          PadCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                if (session.recentEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text('Appuie sur un bouton…', style: TextStyle(fontSize: 11, color: c.muted)),
                  ),
                for (final event in session.recentEvents.take(5))
                  _EventRow(event: event, layout: _layouts[_layoutIndex]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionLabel(
            'Moteurs de vibration',
            trailing: Text(
              session.simulate ? 'simulation' : 'matériel',
              style: TextStyle(fontSize: 9.5, color: c.muted),
            ),
          ),
          PadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MotorSlider(
                  label: 'Moteur fort · gauche',
                  value: _strong,
                  color: c.cyan,
                  onChanged: (v) => setState(() => _strong = v),
                ),
                _MotorSlider(
                  label: 'Moteur faible · droit',
                  value: _weak,
                  color: c.magenta,
                  onChanged: (v) => setState(() => _weak = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _PresetChip(label: 'Impulsion', onTap: _presetPulse),
                    _PresetChip(label: 'Double', onTap: _presetDouble),
                    _PresetChip(label: 'Rampe', onTap: _presetRamp),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'Tester',
                        icon: Icons.vibration_rounded,
                        onPressed: _presetPulse,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'Stop',
                      icon: Icons.stop_rounded,
                      onPressed: session.stopVibration,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  session.simulate
                      ? 'Les moteurs sont pilotés en mode matériel. En simulation, '
                            'les valeurs restent affichées mais aucune vibration n\'est envoyée.'
                      : 'Chaque moteur est adressé séparément (deux canaux quand la manette '
                            'les expose). Durée et intensité respectent 0–255 côté natif.',
                  style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Valeurs brutes · mode Universal'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 2.5,
            children: [
              _RawCell(label: 'L.X', value: state.rawAxis(PadAxis.leftX)),
              _RawCell(label: 'L.Y', value: state.rawAxis(PadAxis.leftY)),
              _RawCell(label: 'R.X', value: state.rawAxis(PadAxis.rightX)),
              _RawCell(label: 'R.Y', value: state.rawAxis(PadAxis.rightY)),
              _RawCell(label: 'LT', value: state.rawAxis(PadAxis.leftTrigger)),
              _RawCell(label: 'RT', value: state.rawAxis(PadAxis.rightTrigger)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisPill extends StatelessWidget {
  const _AxisPill({required this.label, required this.x, required this.y, required this.color});

  final String label;
  final double x;
  final double y;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.2),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$label  ${x.toStringAsFixed(2)} / ${y.toStringAsFixed(2)}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
    );
  }
}

class _ButtonChip extends StatelessWidget {
  const _ButtonChip({required this.button, required this.layout, required this.pressed});

  final PadButton button;
  final PadLayout layout;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: pressed ? c.cyan.withValues(alpha: 0.16) : c.card,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: pressed ? c.cyan.withValues(alpha: 0.6) : c.line),
      ),
      child: Text(
        button.glyph(layout),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          color: pressed ? c.cyan : c.muted,
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.layout});

  final PadEvent event;
  final PadLayout layout;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDown = event.type == PadEventType.buttonDown;
    final time = DateTime.fromMicrosecondsSinceEpoch(event.timestampUs);
    final stamp =
        '${time.second.toString().padLeft(2, '0')}.${(time.millisecond ~/ 10).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(stamp, style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: c.muted)),
          ),
          SizedBox(
            width: 26,
            child: Text(
              event.button?.glyph(layout) ?? '',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w800, color: isDown ? c.cyan : c.magenta),
            ),
          ),
          Expanded(
            child: Text(
              '${event.button?.name ?? ''} · ${isDown ? 'down' : 'up'}',
              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: c.text),
            ),
          ),
          Text(
            isDown ? '1' : '0',
            style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: isDown ? c.green : c.muted),
          ),
        ],
      ),
    );
  }
}

class _RawCell extends StatelessWidget {
  const _RawCell({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 8, letterSpacing: 0.6, color: c.muted, fontWeight: FontWeight.w700)),
          Text(
            value.round().toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w800, color: c.text),
          ),
        ],
      ),
    );
  }
}


class _MotorSlider extends StatelessWidget {
  const _MotorSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.text),
              ),
            ),
            Text(
              '${(value * 100).round()} %',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: color,
            inactiveTrackColor: c.line,
            thumbColor: color,
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.line),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.text),
        ),
      ),
    );
  }
}
