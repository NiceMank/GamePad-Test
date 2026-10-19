import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';
import '../link/link_screen.dart';
import '../remap/remap_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final device = session.device;
    final report = session.buildHealthReport();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'P',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF04121B)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PadLab',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: c.text),
                ),
              ),
              if (session.simulate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: c.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'SIMULATION',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.amber),
                  ),
                ),
              IconButton(
                onPressed: () => onNavigate(4),
                icon: Icon(Icons.settings_rounded, size: 20, color: c.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const SectionLabel('Manette connectée'),
          PadCard(
            accent: device == null ? null : c.cyan.withValues(alpha: 0.35),
            child: Row(
              children: [
                const ControllerGlyph(size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device?.name ?? 'Aucune manette',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        device == null
                            ? 'Branche une manette en Bluetooth ou USB-C'
                            : '${device.connection == ConnectionGuess.bluetooth ? 'Bluetooth' : 'USB'} · Joueur ${device.controllerNumber}',
                        style: TextStyle(fontSize: 10.5, color: c.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device?.capabilities.hasBattery == true
                            ? 'Batterie ${session.battery.percent?.round() ?? '—'} % · ${session.battery.status.labelFr}'
                            : 'Batterie non exposée',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: session.battery.percent != null && session.battery.percent! > 20 ? c.green : c.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ScoreRing(score: report.score, grade: report.grade, size: 52),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Lancer le test complet',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => onNavigate(1),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Outils'),
          Row(
            children: [
              Expanded(
                child: _ToolTile(
                  icon: Icons.adjust_rounded,
                  title: 'Stick Lab',
                  subtitle: 'Drift & circularité',
                  color: c.cyan,
                  onTap: () => onNavigate(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolTile(
                  icon: Icons.battery_6_bar_rounded,
                  title: 'Batterie',
                  subtitle: 'Autonomie & santé',
                  color: c.green,
                  onTap: () => onNavigate(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ToolTile(
                  icon: Icons.tune_rounded,
                  title: 'Remapping',
                  subtitle: 'Boutons, courbes',
                  color: c.magenta,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RemapScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToolTile(
                  icon: Icons.desktop_windows_rounded,
                  title: 'PadLab Link',
                  subtitle: 'Xbox virtuel sur PC',
                  color: c.amber,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const LinkScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionLabel(
            'Rendu 3D',
            trailing: Text(
              'glisse pour tourner',
              style: TextStyle(fontSize: 9.5, color: c.muted),
            ),
          ),
          PadCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Controller3D(state: session.state, height: 230, autoRotate: true),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Dernières sessions'),
          _SessionRow(
            title: 'DualSense — test complet',
            subtitle: "Aujourd'hui · 14:32 · 30 s",
            score: report.score.round(),
          ),
          const _SessionRow(
            title: 'Xbox Series — sticks',
            subtitle: 'Hier · 19:07 · 30 s',
            score: 78,
            muted: true,
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontSize: 10, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.title,
    required this.subtitle,
    required this.score,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final int score;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: c.line),
            ),
            child: Icon(Icons.videogame_asset_rounded, size: 15, color: c.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.text)),
                Text(subtitle, style: TextStyle(fontSize: 9.5, color: c.muted)),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: muted ? c.amber : c.green,
            ),
          ),
        ],
      ),
    );
  }
}
