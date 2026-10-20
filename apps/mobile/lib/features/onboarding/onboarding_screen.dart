import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

/// Accueil du premier lancement.
///
/// Quatre écrans, une seule fois. Le but n'est pas de faire joli : c'est de
/// répondre à la question « qu'est-ce que je fais maintenant ? » avant que
/// l'utilisateur ne voie un écran vide.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _steps = <_Step>[
    _Step(
      eyebrow: 'ÉTAPE 1 SUR 4',
      title: 'Branchez.\nC\'est tout.',
      body:
          'PadLab détecte votre manette dès l\'ouverture — USB ou Bluetooth. '
          'Ses boutons, ses sticks et ses gâchettes sont lus directement, '
          'sans réglage ni redémarrage.',
      art: _ArtKind.pad,
    ),
    _Step(
      eyebrow: 'ÉTAPE 2 SUR 4',
      title: 'Voyez ce\nqu\'elle envoie',
      body:
          'Chaque appui s\'allume sur le modèle 3D, exactement comme sur la '
          'manette. Le journal montre les événements bruts, horodatés, pour '
          'repérer une touche qui ne répond plus.',
      art: _ArtKind.inputs,
    ),
    _Step(
      eyebrow: 'ÉTAPE 3 SUR 4',
      title: 'Diagnostiquez\nses défauts',
      body:
          'Dérive et zone morte des sticks, circularité, course réelle des '
          'gâchettes, fréquence et gigue du polling. Le score de santé ne '
          's\'affiche qu\'une fois vos sticks réellement bougés.',
      art: _ArtKind.analysis,
    ),
    _Step(
      eyebrow: 'ÉTAPE 4 SUR 4',
      title: 'Jouez sur PC\navec n\'importe quelle manette',
      body:
          'PadLab Link crée une manette Xbox virtuelle sur l\'ordinateur et y '
          'envoie les entrées du téléphone. Windows et Linux, sans compte, '
          'en local sur le réseau.',
      art: _ArtKind.link,
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      widget.onDone();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _steps[_index];
    final last = _index == _steps.length - 1;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- en-tête : marque + passer ---------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  const _BrandMark(size: 28),
                  const SizedBox(width: 9),
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
                  if (!last)
                    TextButton(
                      onPressed: widget.onDone,
                      style: TextButton.styleFrom(
                        foregroundColor: c.muted,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Passer', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),

            // --- pages ------------------------------------------------------
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageView(step: _steps[i]),
              ),
            ),

            // --- pied : progression + action --------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _steps.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(right: 6),
                          height: 3,
                          width: i == _index ? 26 : 10,
                          decoration: BoxDecoration(
                            color: i == _index ? c.text : c.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '${_index + 1} / ${_steps.length}',
                        style: TextStyle(fontSize: 10.5, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: last ? 'Commencer' : 'Suivant',
                    icon: last
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.footnote,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9.5, height: 1.5, color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.art,
  });

  final String eyebrow;
  final String title;
  final String body;
  final _ArtKind art;

  String get footnote => switch (art) {
    _ArtKind.pad => 'Aucune manette ? La démonstration reste disponible.',
    _ArtKind.inputs => 'Touchez une touche du modèle pour la simuler.',
    _ArtKind.analysis =>
      'La batterie n\'est lisible qu\'à partir d\'Android 12, quand la '
          'manette l\'expose.',
    _ArtKind.link => 'Réglages → Revoir l\'introduction, à tout moment.',
  };
}

enum _ArtKind { pad, inputs, analysis, link }

class _PageView extends StatelessWidget {
  const _PageView({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // L'illustration occupe la place libre ; le texte garde la sienne.
    // Aucun débordement : tout enfant graphique sait se mettre à l'échelle.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Art(kind: step.art)),
          const SizedBox(height: 16),
          Text(
            step.eyebrow,
            style: TextStyle(
              fontFamily: PadType.mono,
              fontSize: 9,
              letterSpacing: 1.4,
              color: c.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: TextStyle(
              fontFamily: PadType.display,
              fontSize: 28,
              height: 1.06,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            style: TextStyle(fontSize: 12, height: 1.58, color: c.muted),
          ),
        ],
      ),
    );
  }
}

/// La marque : même dessin que l'icône de l'application, en vectoriel.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF1D1F24) : c.text,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: c.line),
      ),
      child: CustomPaint(
        painter: _MarkPainter(ink: c.isDark ? c.text : c.bg, dot: c.cyan),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.ink, required this.dot});

  final Color ink;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Paint()..color = ink;
    final stemW = s * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.315, s * 0.225, stemW, s * 0.55),
        Radius.circular(stemW / 2),
      ),
      p,
    );
    final centre = Offset(s * 0.525, s * 0.382);
    canvas.drawCircle(centre, s * 0.215, p);
    // L'anneau est évidé par-dessus : le fond transparaît.
    canvas.drawCircle(
      centre,
      s * 0.098,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.drawCircle(centre, s * 0.050, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ink != ink || old.dot != dot;
}

/// Illustration de chaque étape.
///
/// L'étape 1 montre le vrai modèle 3D — celui que l'utilisateur verra ensuite.
/// Les autres sont dessinées : pas d'image à charger, nettes à toutes tailles.
class _Art extends StatelessWidget {
  const _Art({required this.kind});

  final _ArtKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.surface, c.isDark ? const Color(0xFF101114) : c.bg],
        ),
        border: Border.all(color: c.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: switch (kind) {
          // Le modèle réel : ce n'est pas une illustration approximative.
          _ArtKind.pad => const _PadArt(),
          _ArtKind.inputs => CustomPaint(
            painter: _InputsArt(c),
            size: Size.infinite,
          ),
          _ArtKind.analysis => CustomPaint(
            painter: _AnalysisArt(c),
            size: Size.infinite,
          ),
          _ArtKind.link => CustomPaint(
            painter: _LinkArt(c),
            size: Size.infinite,
          ),
        },
      ),
    );
  }
}

/// Étape 1 : le contrôleur 3D de l'application, immobile.
class _PadArt extends StatelessWidget {
  const _PadArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Le modèle remplit la boîte, sans jamais la dépasser.
        final h = (constraints.maxHeight * 0.82).clamp(110.0, 330.0);
        return Center(
          child: Controller3D(
            state: const PadState(
              pressed: {},
              axes: {PadAxis.leftX: 0.12, PadAxis.leftY: -0.08},
            ),
            family: ControllerFamily.dualSense,
            height: h,
            initialYaw: -0.30,
            initialPitch: 0.30,
          ),
        );
      },
    );
  }
}

abstract class _ArtPainter extends CustomPainter {
  _ArtPainter(this.c);

  final PadColors c;

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.c != c;
}

/// Étape 2 : une entrée qui s'allume, et le journal qui la note.
class _InputsArt extends _ArtPainter {
  _InputsArt(super.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.30;

    // Bouton A allumé, avec son halo.
    final a = Offset(w * 0.17, top);
    canvas.drawCircle(a, 26, Paint()..color = c.green.withValues(alpha: 0.13));
    canvas.drawCircle(a, 17, Paint()..color = c.green);
    canvas.drawCircle(
      a,
      17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.green.withValues(alpha: 0.6),
    );
    // Libellé « A » suggéré par deux traits, sans dépendre d'une police.
    canvas.drawLine(
      a + const Offset(-4, -4),
      a + const Offset(-4, 7),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = c.bg.withValues(alpha: 0.75),
    );
    canvas.drawLine(
      a + const Offset(-4, -4),
      a + const Offset(3, -4),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = c.bg.withValues(alpha: 0.75),
    );

    // Stick poussé, tige visible.
    final stick = Offset(w * 0.47, top);
    canvas.drawCircle(stick, 34, Paint()..color = c.bg.withValues(alpha: 0.5));
    canvas.drawCircle(
      stick,
      34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.line,
    );
    canvas.drawCircle(stick, 26, Paint()..color = c.line.withValues(alpha: 0.5));
    final tip = stick + const Offset(18, -13);
    canvas.drawLine(
      stick,
      tip,
      Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = c.muted,
    );
    canvas.drawCircle(tip, 11, Paint()..color = c.cyan);

    // Gâchette à mi-course.
    final left = w * 0.62;
    final right = w * 0.94;
    canvas.drawRRect(
      RRect.fromLTRBR(left, top - 6, right, top + 6, const Radius.circular(6)),
      Paint()..color = c.line,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        top - 6,
        left + (right - left) * 0.62,
        top + 6,
        const Radius.circular(6),
      ),
      Paint()..color = c.cyan,
    );

    // Journal : quatre lignes, la première vivante.
    for (var i = 0; i < 4; i++) {
      final y = h * 0.56 + i * (h * 0.11);
      final live = i == 0;
      canvas.drawCircle(
        Offset(w * 0.08, y),
        2.6,
        Paint()..color = live ? c.green : c.muted.withValues(alpha: 0.35),
      );
      canvas.drawLine(
        Offset(w * 0.13, y),
        Offset(w * (0.13 + (live ? 0.30 : 0.22)), y),
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = live
              ? c.text.withValues(alpha: 0.62)
              : c.muted.withValues(alpha: 0.20),
      );
      canvas.drawLine(
        Offset(w * 0.80, y),
        Offset(w * 0.90, y),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = c.muted.withValues(alpha: 0.16),
      );
    }
  }
}

/// Étape 3 : la trace d'un stick et quatre mesures.
class _AnalysisArt extends _ArtPainter {
  _AnalysisArt(super.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = Offset(w * 0.30, h * 0.5);
    final r = math.min(h * 0.36, w * 0.235);

    canvas.drawCircle(centre, r, Paint()..color = c.line.withValues(alpha: 0.16));
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = c.line,
    );
    canvas.drawCircle(
      centre,
      r * 0.14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = c.line,
    );

    // Trace elliptique : le défaut doit se voir, pas un cercle parfait.
    final path = Path();
    for (var i = 0; i <= 140; i++) {
      final a = i / 140 * 2 * math.pi;
      final wob = 1 + math.sin(a * 3 + 0.6) * 0.055;
      final p = centre +
          Offset(math.cos(a) * r * wob, math.sin(a) * r * wob * 1.04);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = c.cyan,
    );
    // Point de repos, légèrement décentré : la dérive.
    canvas.drawCircle(
      centre + const Offset(4, -2),
      3,
      Paint()..color = c.amber,
    );

    const rows = [true, true, false, true];
    for (var i = 0; i < rows.length; i++) {
      final y = h * 0.26 + i * (h * 0.16);
      canvas.drawLine(
        Offset(w * 0.60, y + 10),
        Offset(w * 0.94, y + 10),
        Paint()
          ..strokeWidth = 1
          ..color = c.line,
      );
      canvas.drawCircle(
        Offset(w * 0.60, y),
        2.6,
        Paint()..color = rows[i] ? c.green : c.amber,
      );
      canvas.drawLine(
        Offset(w * 0.635, y),
        Offset(w * 0.635 + 54, y),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = c.muted.withValues(alpha: 0.32),
      );
      canvas.drawLine(
        Offset(w * 0.855, y),
        Offset(w * 0.855 + 32, y),
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = c.text.withValues(alpha: 0.62),
      );
    }
  }
}

/// Étape 4 : téléphone → réseau → PC → manette virtuelle.
class _LinkArt extends _ArtPainter {
  _LinkArt(super.c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h * 0.5;

    // --- téléphone -------------------------------------------------------
    final phoneW = (w * 0.14).clamp(44.0, 66.0);
    final phoneH = phoneW * 1.75;
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.17, cy),
        width: phoneW,
        height: phoneH,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(phone, Paint()..color = c.bg.withValues(alpha: 0.55));
    canvas.drawRRect(
      phone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = c.line,
    );
    canvas.drawCircle(Offset(w * 0.17, cy), phoneW * 0.17, Paint()..color = c.cyan);

    // Ondes : le signal part du téléphone.
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * 0.17, cy), radius: phoneW * 0.42 + i * 14),
        -0.72,
        1.44,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = c.cyan.withValues(alpha: 0.40 - i * 0.10),
      );
    }

    // --- écran d'ordinateur : paysage, comme un vrai moniteur ------------
    final screenW = (w * 0.40).clamp(150.0, 420.0);
    final screenH = screenW * 0.62;
    final screenCentre = Offset(w * 0.72, cy - h * 0.04);
    final screen = RRect.fromRectAndRadius(
      Rect.fromCenter(center: screenCentre, width: screenW, height: screenH),
      const Radius.circular(7),
    );
    canvas.drawRRect(screen, Paint()..color = c.bg.withValues(alpha: 0.55));
    canvas.drawRRect(
      screen,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = c.line,
    );
    // Pied + socle.
    canvas.drawLine(
      Offset(screenCentre.dx, screenCentre.dy + screenH / 2),
      Offset(screenCentre.dx, screenCentre.dy + screenH / 2 + 14),
      Paint()
        ..strokeWidth = 2
        ..color = c.line,
    );
    canvas.drawLine(
      Offset(screenCentre.dx - screenW * 0.16, screenCentre.dy + screenH / 2 + 14),
      Offset(screenCentre.dx + screenW * 0.16, screenCentre.dy + screenH / 2 + 14),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = c.line,
    );

    // --- manette émise, dessinée dans l'écran ----------------------------
    final padW = screenW * 0.52;
    final padH = padW * 0.44;
    final padCentre = screenCentre;
    final pad = RRect.fromRectAndRadius(
      Rect.fromCenter(center: padCentre, width: padW, height: padH),
      Radius.circular(padH * 0.42),
    );
    canvas.drawRRect(pad, Paint()..color = c.text.withValues(alpha: 0.16));
    canvas.drawRRect(
      pad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = c.text.withValues(alpha: 0.30),
    );
    // Croix directionnelle (un vrai signe, pas deux points).
    final dpad = Offset(padCentre.dx - padW * 0.22, padCentre.dy);
    final arm = padH * 0.17;
    final bar = padH * 0.055;
    canvas.drawRect(
      Rect.fromCenter(center: dpad, width: arm * 2, height: bar),
      Paint()..color = c.cyan.withValues(alpha: 0.75),
    );
    canvas.drawRect(
      Rect.fromCenter(center: dpad, width: bar, height: arm * 2),
      Paint()..color = c.cyan.withValues(alpha: 0.75),
    );
    // Deux boutons côté droit.
    canvas.drawCircle(
      Offset(padCentre.dx + padW * 0.20, padCentre.dy - padH * 0.10),
      padH * 0.075,
      Paint()..color = c.green.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset(padCentre.dx + padW * 0.30, padCentre.dy + padH * 0.10),
      padH * 0.075,
      Paint()..color = c.danger.withValues(alpha: 0.75),
    );

    // --- liaison ---------------------------------------------------------
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(w * 0.40 + i * (w * 0.045), cy),
        2.4,
        Paint()..color = c.cyan.withValues(alpha: 0.85 - i * 0.16),
      );
    }
  }
}
