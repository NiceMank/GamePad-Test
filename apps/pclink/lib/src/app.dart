import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import 'link_server.dart';
import 'virtual_pad.dart';
import 'virtual_pad_factory.dart';

/// Fenêtre principale de PadLab Link : appairage, sortie Xbox, statistiques.
class LinkApp extends StatefulWidget {
  const LinkApp({super.key});

  @override
  State<LinkApp> createState() => _LinkAppState();
}

class _LinkAppState extends State<LinkApp> {
  final ValueNotifier<PadState> _state = ValueNotifier(PadState.idle);
  final LinkServer _server = LinkServer();
  final List<String> _log = [];
  final List<double> _jitterHistory = [];

  VirtualPad? _pad;
  Timer? _uiTimer;
  Timer? _demoTimer;
  PadState _latest = PadState.idle;
  bool _demo = false;
  bool _starting = false;
  int _reports = 0;
  List<String> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _starting = true);
    _pad = await createVirtualPad();
    _addresses = await _resolveAddresses();
    final ok = await _server.start();
    if (!ok) _appendLog('Écoute impossible sur le port ${_server.port}');
    _server.onState = _applyState;

    // L'UI est rafraîchie à 60 Hz, indépendamment du débit d'entrée.
    _uiTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _starting = false);
  }

  void _applyState(PadState state, LinkStatePacket packet) {
    _latest = state;
    _pad?.submit(state);
    _reports++;
    _state.value = state;
  }

  void _appendLog(String message) {
    _log.insert(0, '${_stamp()}  $message');
    if (_log.length > 40) _log.removeLast();
  }

  static String _stamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void _toggleDemo() {
    if (_demo) {
      _demoTimer?.cancel();
      _demoTimer = null;
      setState(() => _demo = false);
      _appendLog('Démo arrêtée');
      return;
    }
    _appendLog('Démo locale : entrées synthétiques à 250 Hz');
    setState(() => _demo = true);
    var tick = 0;
    _demoTimer = Timer.periodic(const Duration(milliseconds: 4), (_) {
      tick++;
      final t = tick * 0.004;
      final state = PadState(
        pressed: {
          if (math.sin(t * 1.7) > 0.8) PadButton.a,
          if (math.cos(t * 1.1) > 0.75) PadButton.b,
          if (math.sin(t * 0.6) > 0.55) PadButton.dpadRight,
          if (math.cos(t * 0.9) > 0.9) PadButton.r1,
        },
        axes: {
          PadAxis.leftX: math.sin(t * 0.9) * 0.6,
          PadAxis.leftY: math.cos(t * 0.7) * 0.45,
          PadAxis.rightX: math.sin(t * 1.3 + 1.2) * 0.35,
          PadAxis.rightY: math.cos(t * 1.7 + 0.4) * 0.5,
          PadAxis.leftTrigger: (math.sin(t * 0.5) + 1) / 2 * 0.9,
          PadAxis.rightTrigger: (math.cos(t * 0.8) + 1) / 2,
        },
        timestampUs: DateTime.now().microsecondsSinceEpoch,
        sequence: tick,
      );
      _latest = state;
      _pad?.submit(state);
      _state.value = state;
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _demoTimer?.cancel();
    _server.stop();
    _pad?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stats = _server.stats;
    if (stats.jitterMs > 0) {
      _jitterHistory.add(stats.jitterMs);
      if (_jitterHistory.length > 120) _jitterHistory.removeAt(0);
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(c, stats),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _stage(c)),
                    const SizedBox(width: 14),
                    SizedBox(width: 340, child: _sidePanel(c, stats)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PadColors c, LinkStats stats) {
    final connected = stats.streaming;
    final tone = connected ? c.green : (_starting ? c.amber : c.muted);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [c.cyan, c.blue]),
          ),
          child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PadLab Link', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.text)),
            Text(
              'Manette Android → manette Xbox virtuelle',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.muted),
            ),
          ],
        ),
        const Spacer(),
        _Chip(
          label: connected ? 'FLUX ACTIF' : (_starting ? 'DÉMARRAGE' : 'EN ATTENTE'),
          color: tone,
        ),
        const SizedBox(width: 8),
        _Chip(
          label: '${_pad?.backend.toUpperCase() ?? '…'} · ${_pad?.ready == true ? 'PRÊT' : 'HORS LIGNE'}',
          color: _pad?.ready == true ? c.cyan : c.amber,
        ),
        const SizedBox(width: 12),
        GhostButton(label: _demo ? 'Arrêter la démo' : 'Mode démo', icon: Icons.science_rounded, onPressed: _toggleDemo),
      ],
    );
  }

  Widget _stage(PadColors c) {
    return PadCard(
      child: Column(
        children: [
          Row(
            children: [
              SectionLabel(
                'Manette virtuelle',
                trailing: Text(
                  _pad?.detail ?? '',
                  style: TextStyle(fontSize: 9, color: c.muted),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<PadState>(
                valueListenable: _state,
                builder: (context, state, _) => Controller3D(
                  state: state,
                  height: 320,
                  autoRotate: true,
                ),
              ),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(child: TriggerBar(label: 'LT', value: _latest.axis(PadAxis.leftTrigger))),
              const SizedBox(width: 12),
              Expanded(child: TriggerBar(label: 'RT', value: _latest.axis(PadAxis.rightTrigger), isRight: true)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final button in PadButton.values)
                _ButtonDot(
                  button: button,
                  pressed: _latest.isPressed(button),
                  color: c.cyan,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidePanel(PadColors c, LinkStats stats) {
    final code = _server.pairingCode.toString().padLeft(4, '0');
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SectionLabel('Appairage'),
        PadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(code, style: TextStyle(fontFamily: 'monospace', fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6, color: c.cyan)),
                  const Spacer(),
                  _Chip(
                    label: _server.paired ? 'APPAIRÉ' : 'CODE REQUIS',
                    color: _server.paired ? c.green : c.amber,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Saisissez ce code dans PadLab → Link sur le téléphone.',
                style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
              ),
              const SizedBox(height: 8),
              for (final address in _addresses)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '$address:${_server.udpPort}',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: c.text),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Oublier',
                      icon: Icons.link_off_rounded,
                      onPressed: () {
                        _server.unpair();
                        _appendLog('Manette oubliée');
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Liaison'),
        Row(
          children: [
            Expanded(child: StatTile(label: 'Paquets/s', value: stats.packetsPerSecond.toStringAsFixed(0), tone: c.cyan)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: 'Perte', value: '${stats.lost}', tone: stats.lost > 0 ? c.amber : c.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: StatTile(label: 'Jitter', value: stats.jitterMs.toStringAsFixed(1), unit: 'ms', tone: c.blue)),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'Batterie',
                value: (stats.batteryPercent == null || stats.batteryPercent == 0xFF)
                    ? '—'
                    : '${stats.batteryPercent}',
                unit: '%',
                tone: c.magenta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PadCard(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            height: 54,
            child: CustomPaint(
              painter: _SparkPainter(values: List<double>.from(_jitterHistory), color: c.cyan, grid: c.line),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Journal'),
        PadCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: SizedBox(
            height: 132,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final line in _log.take(12))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      line,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, height: 1.4, color: c.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Sortie'),
        PadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pad?.backend == 'ViGEmBus'
                    ? 'Pilote ViGEmBus · Xbox 360 (XInput)'
                    : _pad?.backend == 'uinput'
                    ? 'Périphérique evdev 045E:028E'
                    : 'Aucune sortie virtuelle active',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${_pad?.detail ?? ''}\n$_reports rapports envoyés',
                style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<List<String>> _resolveAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      ).timeout(const Duration(milliseconds: 400));
      final addresses = interfaces
          .expand((i) => i.addresses)
          .map((a) => a.address)
          .toList();
      return addresses.isEmpty ? const ['127.0.0.1'] : addresses;
    } catch (_) {
      return const ['127.0.0.1'];
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: color),
      ),
    );
  }
}

class _ButtonDot extends StatelessWidget {
  const _ButtonDot({required this.button, required this.pressed, required this.color});

  final PadButton button;
  final bool pressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: pressed ? color.withValues(alpha: 0.2) : c.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: pressed ? color : c.line),
      ),
      child: Text(
        button.glyph(PadLayout.xbox),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: pressed ? color : c.muted,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.values, required this.color, required this.grid});

  final List<double> values;
  final Color color;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 1), Offset(size.width, size.height - 1), gridPaint);

    if (values.length < 2) return;
    final maxValue = values.reduce(math.max).clamp(1.0, double.infinity);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] / maxValue) * (size.height - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values.length != values.length;
}
