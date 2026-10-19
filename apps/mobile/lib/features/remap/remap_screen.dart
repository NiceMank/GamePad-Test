import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class RemapScreen extends StatelessWidget {
  const RemapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final profile = session.profile;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Remapping',
          style: TextStyle(
            fontFamily: PadType.display,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: c.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Exporter le profil',
            onPressed: () => _export(context, profile),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          Text(
            'Les correspondances s\'appliquent en direct dans l\'app. Sur PC, '
            'PadLab Link les étend à tous les jeux via la manette Xbox virtuelle.',
            style: TextStyle(fontSize: 11, height: 1.5, color: c.muted),
          ),
          const SizedBox(height: 14),
          const SectionLabel('Boutons'),
          GhostButton(label: 'Réinitialiser le profil', icon: Icons.restart_alt_rounded, onPressed: session.resetProfile),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final button in PadButton.values)
                _MappingChip(
                  source: button,
                  target: profile.targetOf(button),
                  onTap: () => _pickTarget(context, session, profile, button),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Stick gauche'),
          _StickSettingsCard(
            settings: profile.leftStick,
            onChanged: (next) => session.updateProfile(profile.copyWith(leftStick: next)),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Stick droit'),
          _StickSettingsCard(
            settings: profile.rightStick,
            onChanged: (next) => session.updateProfile(profile.copyWith(rightStick: next)),
          ),
          const SizedBox(height: 12),
          PadCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: profile.stickToDpad,
                  onChanged: (v) => session.updateProfile(profile.copyWith(stickToDpad: v)),
                  title: Text('Stick gauche → D-pad', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                  subtitle: Text('Utile pour les jeux de plateforme 2D', style: TextStyle(fontSize: 10, color: c.muted)),
                ),
                if (profile.stickToDpad)
                  Slider(
                    value: profile.stickToDpadThreshold,
                    min: 0.3,
                    max: 0.95,
                    onChanged: (v) => session.updateProfile(profile.copyWith(stickToDpadThreshold: v)),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: profile.systemWide,
                  onChanged: (v) => session.updateProfile(profile.copyWith(systemWide: v)),
                  title: Text('Appliquer à tout le système (PC)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                  subtitle: Text('Nécessite PadLab Link + ViGEmBus sur Windows', style: TextStyle(fontSize: 10, color: c.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Aperçu JSON'),
          PadCard(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(profile.toJson()),
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9.5, height: 1.45, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }

  void _pickTarget(BuildContext context, dynamic session, RemapProfile profile, PadButton source) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        final c = sheetContext.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cible pour ${source.name}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final target in PadButton.values)
                      GestureDetector(
                        onTap: () {
                          final map = Map<PadButton, PadButton>.from(profile.buttonMap);
                          map[source] = target;
                          session.updateProfile(profile.copyWith(buttonMap: map));
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.line),
                          ),
                          child: Text(
                            target.name,
                            style: TextStyle(fontSize: 11, fontFamily: 'JetBrainsMono', color: c.text),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                GhostButton(
                  label: 'Désactiver ce bouton',
                  icon: Icons.block_rounded,
                  onPressed: () {
                    final disabled = Set<PadButton>.from(profile.disabledButtons)..add(source);
                    session.updateProfile(profile.copyWith(disabledButtons: disabled));
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _export(BuildContext context, RemapProfile profile) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profil JSON'),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(profile.toJson()),
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fermer')),
        ],
      ),
    );
  }
}

class _MappingChip extends StatelessWidget {
  const _MappingChip({required this.source, required this.target, required this.onTap});

  final PadButton source;
  final PadButton? target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = target == null;
    final changed = target != null && target != source;
    final accent = disabled ? c.danger : (changed ? c.magenta : c.muted);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              source.name,
              style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono', color: c.muted),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.arrow_forward_rounded, size: 11, color: accent),
            ),
            Text(
              target?.name ?? 'off',
              style: TextStyle(fontSize: 10, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w800, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickSettingsCard extends StatelessWidget {
  const _StickSettingsCard({required this.settings, required this.onChanged});

  final AxisSettings settings;
  final ValueChanged<AxisSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Zone morte', style: TextStyle(fontSize: 11, color: c.muted)),
              const Spacer(),
              Text(
                '${(settings.deadzone * 100).round()} %',
                style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, fontWeight: FontWeight.w800, color: c.text),
              ),
            ],
          ),
          Slider(
            value: settings.deadzone,
            max: 0.4,
            onChanged: (v) => onChanged(settings.copyWith(deadzone: v)),
          ),
          Row(
            children: [
              Text('Sensibilité', style: TextStyle(fontSize: 11, color: c.muted)),
              const Spacer(),
              Text(
                '×${settings.sensitivity.toStringAsFixed(2)}',
                style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, fontWeight: FontWeight.w800, color: c.text),
              ),
            ],
          ),
          Slider(
            value: settings.sensitivity,
            min: 0.5,
            max: 2,
            onChanged: (v) => onChanged(settings.copyWith(sensitivity: v)),
          ),
          const SizedBox(height: 6),
          SegmentedTabs(
            labels: [for (final curve in AxisCurve.values) curve.labelFr.split(' ').first],
            index: AxisCurve.values.indexOf(settings.curve),
            compact: true,
            onChanged: (i) => onChanged(settings.copyWith(curve: AxisCurve.values[i])),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: settings.invertX,
                  onChanged: (v) => onChanged(settings.copyWith(invertX: v)),
                  title: Text('Inverser X', style: TextStyle(fontSize: 11, color: c.text)),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: settings.invertY,
                  onChanged: (v) => onChanged(settings.copyWith(invertY: v)),
                  title: Text('Inverser Y', style: TextStyle(fontSize: 11, color: c.text)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
