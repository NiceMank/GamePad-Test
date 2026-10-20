import 'package:flutter/material.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';
import '../../session/pad_session.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
    this.onReplayOnboarding,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  /// Relance l'introduction du premier lancement.
  final Future<void> Function()? onReplayOnboarding;

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const PadHeader(
          eyebrow: 'PadLab',
          title: 'Réglages',
          subtitle: 'Apparence, connexion, profil du modèle',
        ),
        const SizedBox(height: 14),
        const SectionLabel('Apparence'),
        PadCard(
          child: Column(
            children: [
              SegmentedTabs(
                labels: const ['Système', 'Sombre', 'Clair'],
                index: switch (themeMode) {
                  ThemeMode.system => 0,
                  ThemeMode.dark => 1,
                  ThemeMode.light => 2,
                },
                onChanged: (i) => onThemeMode(switch (i) {
                  0 => ThemeMode.system,
                  1 => ThemeMode.dark,
                  _ => ThemeMode.light,
                }),
              ),
              const SizedBox(height: 10),
              Text(
                'Les deux thèmes partagent les mêmes composants ; les accents '
                'sont assombris en mode clair pour rester lisibles (contraste AA).',
                style: TextStyle(fontSize: 10, height: 1.5, color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Source des entrées'),
        PadCard(
          child: Column(
            children: [
              Text(
                'Source des entrées',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedTabs(
                labels: const ['Auto', 'Manette', 'Démo'],
                index: switch (session.mode) {
                  SourceMode.auto => 0,
                  SourceMode.real => 1,
                  SourceMode.demo => 2,
                },
                compact: true,
                onChanged: (i) => session.setMode(switch (i) {
                  0 => SourceMode.auto,
                  1 => SourceMode.real,
                  _ => SourceMode.demo,
                }),
              ),
              const SizedBox(height: 8),
              Text(
                session.isReal
                    ? 'Les entrées affichées viennent de la manette branchée.'
                    : 'Les entrées sont générées : aucune manette n\'est lue.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: session.isReal ? c.green : c.muted,
                ),
              ),
              if (session.sourceNote != null) ...[
                const SizedBox(height: 4),
                Text(
                  session.sourceNote!,
                  style: TextStyle(fontSize: 10, color: c.muted),
                ),
              ],
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Bridge Android',
                  style: TextStyle(fontSize: 12.5, color: c.text),
                ),
                subtitle: Text(
                  session.hardwareDevices.isEmpty
                      ? (session.hardwareError ??
                            'pad_bridge · InputDevice, VibratorManager, BatteryState')
                      : session.hardwareDevices
                            .map((d) => d.name)
                            .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: c.muted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (session.hardwareDevices.isEmpty ? c.amber : c.green)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: (session.hardwareDevices.isEmpty ? c.amber : c.green)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        session.hardwareDevices.isEmpty
                            ? 'AUCUNE'
                            : '${session.hardwareDevices.length} DÉTECTÉE${session.hardwareDevices.length > 1 ? 'S' : ''}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: session.hardwareDevices.isEmpty ? c.amber : c.green,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: c.muted,
                      tooltip: 'Rechercher une manette maintenant',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => session.refreshNow(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: session.autoRefresh,
                onChanged: session.setAutoRefresh,
                title: Text(
                  'Actualisation automatique',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                subtitle: Text(
                  session.autoRefresh
                      ? 'Manettes toutes les 5 s, batterie toutes les 10 s. '
                            '${_stamp(session.lastAutoRefreshAt)}'
                      : 'Désactivée : appuyez sur ↻ pour relire maintenant.',
                  style: TextStyle(fontSize: 10, height: 1.4, color: c.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('Analyses'),
        const PadCard(
          child: Column(
            children: [
              _InfoRow(label: 'Durée d\'analyse', value: '30 s'),
              _InfoRow(label: 'Seuil de drift', value: '2 %'),
              _InfoRow(label: 'Seuil de course gâchette', value: '97 %'),
              _InfoRow(label: 'Fréquence de rafraîchissement', value: '60 Hz'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('À propos'),
        PadCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PadLab 0.5.0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 4),
              Text(
                'Test, diagnostic et remapping de manettes. 100 % local, sans compte, '
                'sans publicité, aucune donnée envoyée.',
                style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
              ),
              if (onReplayOnboarding != null) ...[
                const SizedBox(height: 10),
                GhostButton(
                  label: 'Revoir l\'introduction',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => onReplayOnboarding!(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// « il y a 4 s » : plus parlant qu'un horodatage absolu.
String _stamp(DateTime? at) {
  if (at == null) return 'jamais';
  final s = DateTime.now().difference(at).inSeconds;
  if (s < 2) return 'à l\'instant';
  if (s < 60) return 'il y a $s s';
  final m = s ~/ 60;
  if (m < 60) return 'il y a $m min';
  return 'il y a ${m ~/ 60} h';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(fontFamily: PadType.mono, fontSize: 11.5, fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
    );
  }
}
