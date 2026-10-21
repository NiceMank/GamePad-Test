import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import '../../app/scope.dart';
import '../../session/pad_session.dart';

/// Test guidé, une étape à la fois.
///
/// Au lieu de laisser l'utilisateur deviner quoi essayer sur un écran qui
/// affiche tout d'un coup, chaque étape demande un geste précis, attend
/// l'entrée réelle, puis passe à la suivante. Le résultat est un parcours
/// qu'on peut suivre du début à la fin sans se perdre.
class GuidedTestScreen extends StatefulWidget {
  const GuidedTestScreen({super.key, this.embedded = false});

  /// Vrai quand l'écran est monté dans la coquille (pas en route poussée).
  final bool embedded;

  @override
  State<GuidedTestScreen> createState() => _GuidedTestScreenState();
}

/// Une étape : ce qu'on demande, ce qui la valide, et où l'on regarde.
class _Step {
  const _Step({
    required this.title,
    required this.hint,
    required this.buttons,
    this.triggerAxis,
    this.threshold = 0.9,
  });

  final String title;
  final String hint;

  /// Boutons qui valident l'étape.
  final List<PadButton> buttons;

  final PadAxis? triggerAxis;

  /// Course minimale d'une gâchette pour valider.
  final double threshold;

  bool satisfiedBy(PadState state) {
    if (triggerAxis != null) {
      return state.axis(triggerAxis!) >= threshold;
    }
    for (final b in buttons) {
      if (state.isPressed(b)) return true;
    }
    return false;
  }
}

class _GuidedTestScreenState extends State<GuidedTestScreen> {
  /// Parcours complet, dans l'ordre où une manette se découvre.
  static const _steps = <_Step>[
    _Step(
      title: 'Croix directionnelle',
      hint: 'Appuie sur haut, bas, gauche, droite.',
      buttons: [
        PadButton.dpadUp,
        PadButton.dpadDown,
        PadButton.dpadLeft,
        PadButton.dpadRight,
      ],
    ),
    _Step(
      title: 'Sticks',
      hint: 'Tourne chaque stick jusqu\'au bord, dans les quatre directions.',
      buttons: [],
    ),
    _Step(
      title: 'Boutons de façade',
      hint: 'Presse les quatre boutons, un par un.',
      buttons: [PadButton.a, PadButton.b, PadButton.x, PadButton.y],
    ),
    _Step(
      title: 'Gâchettes',
      hint: 'Enfonce L2 puis R2 à fond.',
      buttons: [],
      triggerAxis: PadAxis.leftTrigger,
      threshold: 0.85,
    ),
    _Step(
      title: 'Gâchette droite',
      hint: 'Enfonce R2 jusqu\'au bout.',
      buttons: [],
      triggerAxis: PadAxis.rightTrigger,
      threshold: 0.85,
    ),
    _Step(
      title: 'Épaules',
      hint: 'Clique L1 puis R1.',
      buttons: [PadButton.l1, PadButton.r1],
    ),
    _Step(
      title: 'Boutons centraux',
      hint: 'Presse Share puis Options.',
      buttons: [PadButton.select, PadButton.start],
    ),
  ];

  int _index = 0;
  final Set<int> _done = {};
  final Set<PadButton> _seen = {};
  Timer? _watch;
  String? _lastTitle;

  /// Récupérée pendant la construction : on ne peut pas lire un
  /// InheritedWidget depuis un minuteur.
  PadSession? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session = PadScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    // On surveille à 30 Hz : assez pour valider à l'image près, sans coûter
    // une reconstruction par trame.
    _watch = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }

  void _tick() {
    final session = _session;
    if (!mounted || session == null) return;
    final state = session.state;
    if (state.pressed.isNotEmpty) {
      _seen.addAll(state.pressed);
    }
    if (_index >= _steps.length) return;

    final step = _steps[_index];
    var ok = step.satisfiedBy(state);

    // Les étapes « ensemble » se valident quand chaque bouton a été vu au
    // moins une fois : on ne demande pas de tout tenir en même temps.
    if (step.buttons.length > 1) {
      ok = step.buttons.every(_seen.contains);
    }

    if (ok) {
      setState(() {
        _done.add(_index);
        _index++;
        _lastTitle = step.title;
      });
    }
  }

  void _skip() {
    setState(() {
      _index++;
      _lastTitle = _steps[(_index - 1).clamp(0, _steps.length - 1)].title;
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _done.clear();
      _seen.clear();
      _lastTitle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = PadScope.of(context);
    final c = context.colors;
    final family = ControllerFamily.detect(session.device);
    final finished = _index >= _steps.length;
    final step = finished ? null : _steps[_index];
    final progress = _done.length / _steps.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        PadHeader(
          eyebrow: 'Test guidé',
          title: finished ? 'Terminé' : 'Étape ${_index + 1} sur ${_steps.length}',
          subtitle: session.device?.name ?? 'Manette',
        ),
        const SizedBox(height: 12),
        _Progress(value: progress, c: c),
        const SizedBox(height: 14),
        if (!finished)
          _StepCard(
            step: step!,
            index: _index,
            total: _steps.length,
            onSkip: _skip,
            seen: _seen,
          )
        else
          _Summary(
            done: _done.length,
            total: _steps.length,
            onRestart: _restart,
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 372,
          child: Controller3D(
            state: session.state,
            family: family,
            height: 372,
            spinning: false,
            showHint: true,
            hintLabel: 'Glissez pour tourner · touchez une touche',
            onButtonTap: (button) {
              session.tapButton(button);
              _seen.add(button);
            },
          ),
        ),
        if (!finished) ...[
          const SizedBox(height: 12),
          // Couverture : ce qui a été vu, ce qui reste. Utile, et ça remplit
          // le bas de l'écran au lieu de laisser un vide.
          _Coverage(seen: _seen, c: c),
        ],
        if (_lastTitle != null && !finished) ...[
          const SizedBox(height: 6),
          Text(
            'Étape validée : $_lastTitle',
            style: TextStyle(fontSize: 10.5, color: c.green),
          ),
        ],
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.c});

  final double value;
  final PadColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: c.line,
              valueColor: AlwaysStoppedAnimation(c.cyan),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(value * 100).round()} %',
          style: TextStyle(
            fontFamily: PadType.mono,
            fontSize: 11,
            color: c.muted,
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onSkip,
    required this.seen,
  });

  final _Step step;
  final int index;
  final int total;
  final VoidCallback onSkip;
  final Set<PadButton> seen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${step.title}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.text),
          ),
          const SizedBox(height: 4),
          Text(step.hint, style: TextStyle(fontSize: 12, color: c.muted)),
          if (step.buttons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in step.buttons)
                  _Chip(
                    label: _label(b),
                    done: seen.contains(b),
                    c: c,
                  ),
              ],
            ),
          ],
          if (step.triggerAxis != null) ...[
            const SizedBox(height: 10),
            _Chip(label: step.title.toUpperCase(), done: false, c: c),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Étape ${index + 1} / $total',
                style: TextStyle(
                  fontFamily: PadType.mono,
                  fontSize: 10,
                  color: c.muted,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: c.muted,
                ),
                child: const Text('Passer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nom lisible d'un bouton, tel qu'il est sérigraphié sur la manette.
String _label(PadButton b) => switch (b) {
  PadButton.a => 'A / ✕',
  PadButton.b => 'B / ◯',
  PadButton.x => 'X / □',
  PadButton.y => 'Y / △',
  PadButton.dpadUp => 'Haut',
  PadButton.dpadDown => 'Bas',
  PadButton.dpadLeft => 'Gauche',
  PadButton.dpadRight => 'Droite',
  PadButton.l1 => 'L1',
  PadButton.r1 => 'R1',
  PadButton.l2 => 'L2',
  PadButton.r2 => 'R2',
  PadButton.select => 'Share',
  PadButton.start => 'Options',
  PadButton.guide => 'PS',
  PadButton.touchpad => 'Pavé',
  PadButton.l3 => 'L3',
  PadButton.r3 => 'R3',
  _ => b.name.toUpperCase(),
};

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.done, required this.c});

  final String label;
  final bool done;
  final PadColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: done ? c.green.withValues(alpha: 0.16) : c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: done ? c.green : c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(Icons.check_rounded, size: 12, color: c.green),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: PadType.mono,
              fontSize: 10.5,
              color: done ? c.green : c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.done,
    required this.total,
    required this.onRestart,
  });

  final int done;
  final int total;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final perfect = done == total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: perfect ? c.green : c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                perfect ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 18,
                color: perfect ? c.green : c.amber,
              ),
              const SizedBox(width: 8),
              Text(
                perfect ? 'Toutes les entrées répondent' : '$done entrées validées sur $total',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            perfect
                ? 'Aucun défaut détecté sur ce parcours. Passe à l\'analyse des sticks pour la dérive et la zone morte.'
                : 'Les étapes passées ne sont pas forcément en cause : recommence en appuyant plus franchement, ou relance le test.',
            style: TextStyle(fontSize: 12, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.replay_rounded, size: 16),
            label: const Text('Recommencer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.text,
              side: BorderSide(color: c.line),
              minimumSize: const Size(0, 38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Les touches attendues, cochées au fur et à mesure.
class _Coverage extends StatelessWidget {
  const _Coverage({required this.seen, required this.c});

  final Set<PadButton> seen;
  final PadColors c;

  static const _keys = [
    (PadButton.a, 'A'),
    (PadButton.b, 'B'),
    (PadButton.x, 'X'),
    (PadButton.y, 'Y'),
    (PadButton.dpadUp, '↑'),
    (PadButton.l1, 'L1'),
    (PadButton.r1, 'R1'),
    (PadButton.l2, 'L2'),
    (PadButton.r2, 'R2'),
    (PadButton.start, 'MENU'),
    (PadButton.select, 'VIEW'),
    (PadButton.l3, 'L3'),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _keys.where((k) => seen.contains(k.$1)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Touches vues',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: c.muted,
                ),
              ),
              const Spacer(),
              Text(
                '$done / ${_keys.length}',
                style: TextStyle(
                  fontFamily: PadType.mono,
                  fontSize: 10,
                  color: c.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final k in _keys)
                _KeyChip(
                  label: k.$2,
                  seen: seen.contains(k.$1),
                  c: c,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une touche vue, en pastille compacte.
///
/// Un `Container` porteur d'un `alignment` s'étire sur toute la largeur
/// disponible : dans un `Wrap`, les touches devenaient des barres pleine
/// largeur avec une seule lettre au milieu. La largeur est donc imposée.
class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label, required this.seen, required this.c});

  final String label;
  final bool seen;
  final PadColors c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: label.length > 2 ? 50 : 36,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: seen ? c.green.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seen ? c.green.withValues(alpha: 0.5) : c.line,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: seen ? c.green : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
