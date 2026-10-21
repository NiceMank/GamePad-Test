import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';
import '../../session/pad_session.dart';

/// Réglages.
///
/// Trois groupes seulement — apparence, manette, application — et aucune
/// information répétée : un titre de section qui répète le titre de la carte
/// qu'il introduit fait amateur.
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        Text(
          'Réglages',
          style: TextStyle(
            fontFamily: PadType.display,
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: c.text,
          ),
        ),
        const SizedBox(height: 24),

        // --- apparence -------------------------------------------------------
        const SectionLabel('Apparence'),
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
        const SizedBox(height: 26),

        // --- manette ---------------------------------------------------------
        const SectionLabel('Source des entrées'),
        _SourceCard(session: session),
        const SizedBox(height: 10),
        _DeviceCard(session: session),
        const SizedBox(height: 26),

        // --- application -----------------------------------------------------
        const SectionLabel('Application'),
        _SettingsCard(
          children: [
            _SwitchRow(
              title: 'Actualisation automatique',
              subtitle: session.autoRefresh
                  ? _autoRefreshLabel(session.lastAutoRefreshAt)
                  : 'Appuyez sur ↻ dans l\'onglet Manette pour relire.',
              value: session.autoRefresh,
              onChanged: session.setAutoRefresh,
            ),
            const _Divider(),
            const _InfoRow(label: 'Durée d\'analyse', value: '30 s'),
            const _InfoRow(label: 'Seuil de dérive', value: '2 %'),
            const _InfoRow(label: 'Course de gâchette', value: '97 %'),
          ],
        ),
        const SizedBox(height: 10),
        _SettingsCard(
          children: [
            const _InfoRow(label: 'Version', value: PadVersion.label),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tout reste sur le téléphone : pas de compte, pas de '
                    'publicité, aucune donnée envoyée.',
                    style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
                  ),
                  if (onReplayOnboarding != null) ...[
                    const SizedBox(height: 12),
                    GhostButton(
                      label: 'Revoir l\'introduction',
                      icon: Icons.replay_rounded,
                      onPressed: () => onReplayOnboarding!(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Choix de la source, avec l'état réel en dessous.
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.session});

  final PadSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final live = session.isReal;
    return _SettingsCard(
      children: [
        SegmentedTabs(
          labels: const ['Auto', 'Manette', 'Démo'],
          index: switch (session.mode) {
            SourceMode.auto => 0,
            SourceMode.real => 1,
            SourceMode.demo => 2,
          },
          onChanged: (i) => session.setMode(switch (i) {
            0 => SourceMode.auto,
            1 => SourceMode.real,
            _ => SourceMode.demo,
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: live ? c.green : c.muted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                live
                    ? 'Les entrées viennent de la manette branchée.'
                    : 'Les entrées sont générées, aucune manette n\'est lue.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: live ? c.green : c.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// La manette détectée, ou l'absence de manette — avec le bouton de relance.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.session});

  final PadSession session;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final devices = session.hardwareDevices;
    final empty = devices.isEmpty;

    return _SettingsCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                empty ? 'Aucune manette détectée' : devices.first.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 17,
              color: c.muted,
              tooltip: 'Rechercher maintenant',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: session.refreshNow,
            ),
          ],
        ),
        Text(
          empty
              ? (session.hardwareError ??
                  'Branchez une manette en USB ou appairez-la en Bluetooth.')
              : _describe(devices.first),
          style: TextStyle(fontSize: 10.5, height: 1.5, color: c.muted),
        ),
      ],
    );
  }

  static String _describe(PadDevice d) {
    final link = d.connection == ConnectionGuess.bluetooth ? 'Bluetooth' : 'USB';
    final vid = d.vendorId;
    final pid = d.productId;
    final ids = (vid == null || pid == null)
        ? null
        : '${vid.toRadixString(16).padLeft(4, '0')}:'
              '${pid.toRadixString(16).padLeft(4, '0')}';
    return [
      link,
      if (ids != null) ids.toUpperCase(),
      'manette n°${d.controllerNumber}',
    ].join(' · ');
  }
}

/// Carte neutre, sans titre : un simple fond avec un filet.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, height: 1.45, color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 32,
          child: Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(height: 1, color: context.colors.line),
      );
}

/// « il y a 4 s » : plus parlant qu'un horodatage absolu.
String _autoRefreshLabel(DateTime? at) {
  const cadence = 'Manettes toutes les 5 s · batterie toutes les 10 s';
  if (at == null) return cadence;
  final s = DateTime.now().difference(at).inSeconds;
  if (s < 60) return '$cadence · à l\'instant';
  return '$cadence · ${_stamp(at)}';
}

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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: PadType.mono,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Version de l'application, tenue à un seul endroit.
///
/// Elle était recopiée dans l'écran de réglages : elle y est restée en 0.5.0
/// après la sortie suivante. Ce n'est pas la panacée (un vrai build la lirait
/// depuis `package_info_plus`), mais elle ne peut plus diverger du pubspec
/// sans qu'on le voie dans le diff.
class PadVersion {
  const PadVersion._();

  static const label = '0.6.1';
}
