import 'package:flutter/material.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.themeMode, required this.onThemeMode});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Text('Réglages', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.text)),
        const SizedBox(height: 16),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: session.simulate,
                onChanged: session.setSimulation,
                title: Text('Mode simulation', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                subtitle: Text(
                  'Génère une manette virtuelle pour tester l\'UI sans matériel.',
                  style: TextStyle(fontSize: 10, color: c.muted),
                ),
              ),
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
                      tooltip: 'Rechercher une manette',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => session.detectHardware(),
                    ),
                  ],
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
              Text('PadLab 0.1.0', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 4),
              Text(
                'Test, diagnostic et remapping de manettes. 100 % local, sans compte, '
                'sans publicité, aucune donnée envoyée.',
                style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
            style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
    );
  }
}
