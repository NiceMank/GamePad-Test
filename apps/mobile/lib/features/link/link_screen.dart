import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';

class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final TextEditingController _host = TextEditingController(text: '192.168.1.10');
  final TextEditingController _code = TextEditingController(text: '1234');
  Timer? _refresh;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _host.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final session = PadScope.of(context);
    final code = int.tryParse(_code.text.trim());
    if (code == null || code < 0 || code > 65535) {
      _toast('Code invalide : 4 chiffres attendus.');
      return;
    }
    setState(() => _busy = true);
    final ok = await session.link.start(
      host: _host.text.trim(),
      code: code,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) _toast(session.link.error ?? 'Connexion impossible.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final link = session.link;
    final token = int.tryParse(_code.text.trim()) ?? 0;

    final packet = LinkStatePacket.fromPadState(
      session.state,
      token: token,
      sequence: session.state.sequence,
      batteryPercent: (session.battery.percent ?? 0xFF).round(),
      batteryStatus: session.battery.status,
    );
    final bytes = packet.encode();
    final hex = [
      for (var i = 0; i < bytes.length; i += 8)
        bytes
            .sublist(i, i + 8 > bytes.length ? bytes.length : i + 8)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' '),
    ].join('\n');

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('PadLab Link')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
        children: [
          const PadHeader(
            eyebrow: 'Passerelle PC',
            title: 'Manette Xbox virtuelle',
            subtitle: 'PadLab Bridge expose la manette comme une manette Xbox '
                'pour tous les jeux Windows, sans pilote supplémentaire côté mobile.',
          ),
          const SizedBox(height: 12),
          PadCard(
            accent: c.cyan.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.desktop_windows_rounded, size: 20, color: c.cyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Manette Xbox virtuelle sur PC',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text),
                      ),
                    ),
                    _StatusChip(
                      label: link.running ? 'ENVOI' : 'À L\'ARRÊT',
                      color: link.running ? c.green : c.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'PadLab Link expose une manette Xbox 360 virtuelle (ViGEmBus sous '
                  'Windows, uinput sous Linux). Les jeux la reconnaissent comme une '
                  'manette XInput, avec tes profils de remapping, courbes et zones '
                  'mortes déjà appliqués.',
                  style: TextStyle(fontSize: 11, height: 1.5, color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Connexion'),
          PadCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Field(
                        controller: _host,
                        label: 'Adresse du PC',
                        hint: '192.168.1.10',
                        enabled: !link.running,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _Field(
                        controller: _code,
                        label: 'Code (4 chiffres)',
                        hint: '1234',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        enabled: !link.running,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: link.running ? 'Diffusion active' : 'Diffuser vers le PC',
                        icon: link.running ? Icons.wifi_tethering_rounded : Icons.play_arrow_rounded,
                        onPressed: link.running || _busy ? null : _start,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: 'Arrêter',
                      icon: Icons.stop_rounded,
                      onPressed: link.running
                          ? () {
                              link.stop();
                              setState(() {});
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Row(label: 'Cible', value: link.remote ?? '—'),
                _Row(
                  label: 'Aller-retour',
                  value: link.rttUs == 0 ? '—' : '${(link.rttUs / 1000).toStringAsFixed(1)} ms',
                  color: link.rttUs > 0 && link.rttUs < 20000 ? c.green : c.amber,
                ),
                _Row(label: 'Trames envoyées', value: '${link.sent}'),
                if (link.supported && link.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      link.error!,
                      style: TextStyle(fontSize: 10, height: 1.45, color: c.danger),
                    ),
                  ),
                if (!link.supported)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'La version web ne peut pas ouvrir de socket UDP : utilisez '
                      'l\'application Android.',
                      style: TextStyle(fontSize: 10, height: 1.45, color: c.amber),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Liaison'),
          Row(
            children: [
              Expanded(
                child: _TransportCard(
                  title: 'USB',
                  detail: 'adb reverse',
                  latency: '≈ 2 ms',
                  color: c.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TransportCard(
                  title: 'Wi-Fi 5 GHz',
                  detail: 'UDP 47833',
                  latency: '≈ 12 ms',
                  color: c.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionLabel('Paquet d\'état', trailing: Text('${bytes.length} octets', style: TextStyle(fontSize: 9.5, color: c.muted))),
          PadCard(
            child: SelectableText(
              hex,
              style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10.5, height: 1.6, color: c.muted),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En-tête PLK1 · version 1 · type 1 · jeton 0x${token.toRadixString(16).toUpperCase().padLeft(4, '0')}. '
            'Les paquets sont absolus : une perte UDP ne désynchronise jamais la '
            'manette virtuelle. 250 trames/s par défaut, coalescées côté téléphone.',
            style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Mise en route'),
          const _Step(index: 1, text: 'Lancer PadLab Link sur le PC (Windows ou Linux). Le code à 4 chiffres et l\'adresse s\'affichent.'),
          const _Step(index: 2, text: 'Saisir les deux ici, puis appuyer sur « Diffuser vers le PC ».'),
          const _Step(index: 3, text: 'Le PC crée la manette virtuelle : Xbox 360 via ViGEmBus, ou périphérique evdev sous Linux.'),
          const _Step(index: 4, text: 'Choisir cette manette dans le jeu. Le remapping PadLab est déjà appliqué.'),
          const SizedBox(height: 16),
          if (session.simulate)
            Text(
              'Mode simulation : les trames sont générées localement pour vérifier '
              'le protocole. Le PC se connecte exactement au même format.',
              style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: c.muted)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: c.cyan),
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 10.5, color: c.muted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color ?? c.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: color),
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  const _TransportCard({required this.title, required this.detail, required this.latency, required this.color});

  final String title;
  final String detail;
  final String latency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.text)),
          Text(detail, style: TextStyle(fontSize: 9.5, color: c.muted)),
          const SizedBox(height: 6),
          Text(
            latency,
            style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.cyan.withValues(alpha: 0.12),
              border: Border.all(color: c.cyan.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.cyan),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 11, height: 1.45, color: c.text)),
          ),
        ],
      ),
    );
  }
}
