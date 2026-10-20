import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';
import '../../session/pad_session.dart';
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
    final family = ControllerFamily.detect(device);
    final report = session.buildHealthReport();
    final battery = session.battery;
    final estimate = session.batteryEstimate;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TopBar(
            simulate: session.simulate,
            live: session.isReal && device != null,
            hasDevice: device != null,
            onSettings: () => onNavigate(4),
          ),
          const SizedBox(height: 18),

          // --- titre éditorial ------------------------------------------------
          Text(
            device == null ? 'Aucune manette' : device.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PadType.display,
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.9,
              color: c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            device == null
                ? 'Branchez une manette pour commencer'
                : [
                    family.label,
                    device.connection == ConnectionGuess.bluetooth
                        ? 'Bluetooth'
                        : 'USB',
                    session.isReal ? 'entrées réelles' : 'démonstration',
                  ].join(' · '),
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          if (session.sourceNote != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  session.isReal
                      ? Icons.sensors_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: session.isReal ? c.green : c.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    session.sourceNote!,
                    style: TextStyle(fontSize: 10.5, color: c.muted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),

          // --- scène 3D --------------------------------------------------------
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 0.85,
                        colors: [
                          c.cyan.withValues(alpha: c.isDark ? 0.09 : 0.07),
                          c.bg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (device == null)
                  // Aucune manette : on ne montre pas un modèle inventé qui
                  // passerait pour le matériel de l'utilisateur.
                  _NoDevice(onDemo: () => session.setMode(SourceMode.demo))
                else
                  Controller3D(
                    state: session.state,
                    family: family,
                    layout: family.layout,
                    height: 250,
                    autoRotate: true,
                    showHint: true,
                    onButtonTap: session.tapButton,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // --- bandeau de mesures ---------------------------------------------
          IntrinsicHeight(
            child: Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Santé',
                  // Sans mesures réelles, un score serait une invention.
                  value: session.simulate || session.hasMeasurements
                      ? report.score.toStringAsFixed(0)
                      : '—',
                  unit: session.simulate || session.hasMeasurements
                      ? '/ 100'
                      : null,
                  caption: session.simulate || session.hasMeasurements
                      ? report.gradeLabel
                      : 'bougez les sticks',
                  tone: session.simulate || session.hasMeasurements
                      ? _scoreTone(c, report.score)
                      : c.muted,
                ),
              ),
              Container(width: 1, height: 40, color: c.line),
              Expanded(
                child: _HeroStat(
                  label: 'Batterie',
                  value: battery.percent == null ? '—' : battery.percent!.toStringAsFixed(0),
                  unit: battery.percent == null ? null : '%',
                  caption: battery.percent == null
                      ? 'non exposée'
                      : estimate.remaining == null
                      ? 'estimation en cours'
                      : '≈ ${_duration(estimate.remaining!)} restantes',
                  tone: _batteryTone(c, battery.percent),
                ),
              ),
              Container(width: 1, height: 40, color: c.line),
              Expanded(
                child: _HeroStat(
                  label: 'Entrées',
                  value: session.state.hasInput ? 'LIVE' : '—',
                  caption: device == null
                      ? 'aucune'
                      : (session.isReal ? 'matérielles' : 'générées'),
                  tone: session.state.hasInput ? c.green : c.muted,
                  mono: false,
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 20),

          PrimaryButton(
            label: 'Lancer le test complet',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => onNavigate(1),
          ),
          const SizedBox(height: 22),

          // --- outils -----------------------------------------------------------
          const SectionLabel('Outils'),
          _ToolRow(
            icon: Icons.radar_rounded,
            title: 'Analyse des sticks',
            subtitle: 'Dérive, zone morte, circularité sur 30 s',
            onTap: () => onNavigate(2),
          ),
          _ToolRow(
            icon: Icons.battery_5_bar_rounded,
            title: 'Batterie et santé',
            subtitle: 'Autonomie estimée, historique de décharge',
            onTap: () => onNavigate(3),
          ),
          _ToolRow(
            icon: Icons.tune_rounded,
            title: 'Remapping',
            subtitle: 'Boutons, courbes, zones mortes, profils',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RemapScreen()),
            ),
          ),
          _ToolRow(
            icon: Icons.desktop_windows_rounded,
            title: 'PadLab Link',
            subtitle: 'Manette Xbox virtuelle sur PC',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LinkScreen()),
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(
            'Sessions lues',
            trailing: Text(
              '${session.sessions.length}',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
          ),
          if (session.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Aucune session réelle enregistrée pour le moment. '
                'Branchez une manette : la lecture démarre seule et sera notée ici.',
                style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
              ),
            )
          else
            for (final record in session.sessions.take(3))
              _SessionRow(
                name: record.name,
                detail:
                    '${_sessionWhen(record.startedAt)} · '
                    '${_duration(record.duration)}',
                score: record.score.round(),
              ),
        ],
      ),
    );
  }

  /// « aujourd'hui » / « hier » / date courte, sans invention.
  static String _sessionWhen(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final days = today.difference(day).inDays;
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    if (days == 0) return 'aujourd\'hui $hh:$mm';
    if (days == 1) return 'hier $hh:$mm';
    return '${at.day} ${_months[at.month - 1]} · $hh:$mm';
  }

  static const _months = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  static String _duration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }

  static Color _scoreTone(PadColors c, double score) {
    if (score >= 75) return c.green;
    if (score >= 60) return c.amber;
    return c.danger;
  }

  static Color _batteryTone(PadColors c, double? percent) {
    if (percent == null) return c.muted;
    if (percent > 40) return c.text;
    if (percent > 15) return c.amber;
    return c.danger;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.simulate,
    required this.live,
    required this.hasDevice,
    required this.onSettings,
  });

  final bool simulate;

  /// Vrai quand les entrées viennent réellement d'une manette.
  final bool live;
  final bool hasDevice;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: c.text,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'P',
            style: TextStyle(
              fontFamily: PadType.display,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.bg,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'PadLab',
          style: TextStyle(
            fontFamily: PadType.display,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: c.text,
          ),
        ),
        const Spacer(),
        // Badge franc : on doit voir d'un coup d'œil si la manette affichée
        // est réelle ou inventée.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: live ? c.green.withValues(alpha: 0.12) : c.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: live ? c.green : c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: live ? c.green : c.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                live
                    ? 'Réel'
                    : hasDevice
                    ? 'Démo'
                    : 'Aucun',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: live ? c.green : c.muted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.settings_outlined, size: 19, color: c.muted),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    this.unit,
    required this.caption,
    required this.tone,
    this.mono = true,
  });

  final String label;
  final String value;
  final String? unit;
  final String caption;
  final Color tone;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: c.muted),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: mono ? PadType.mono : PadType.body,
                    fontSize: mono ? 21 : 15,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: mono ? -0.8 : 0.2,
                    color: tone,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(unit!, style: TextStyle(fontSize: 9.5, color: c.muted)),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.line),
              ),
              child: Icon(icon, size: 17, color: c.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: c.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.muted.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.name, required this.detail, required this.score});

  final String name;
  final String detail;
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = score >= 80 ? c.green : (score >= 70 ? c.amber : c.danger);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      child: Row(
        children: [
          const ControllerGlyph(size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text),
                ),
                Text(detail, style: TextStyle(fontSize: 10.5, color: c.muted)),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: PadType.mono,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panneau affiché quand aucune manette n'est branchée : on explique quoi
/// faire au lieu de dessiner un contrôleur fictif.
class _NoDevice extends StatelessWidget {
  const _NoDevice({required this.onDemo});

  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videogame_asset_off_rounded, size: 40, color: c.muted),
          const SizedBox(height: 12),
          Text(
            'Aucune manette branchée',
            style: TextStyle(
              fontFamily: PadType.display,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'Branchez une manette en USB ou appairez-la en Bluetooth. '
              'Elle sera reconnue automatiquement, sans redémarrer l\'application.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
            ),
          ),
          const SizedBox(height: 14),
          GhostButton(
            label: 'Voir la démonstration',
            icon: Icons.play_circle_outline_rounded,
            onPressed: onDemo,
          ),
        ],
      ),
    );
  }
}
