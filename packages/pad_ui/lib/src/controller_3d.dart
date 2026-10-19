
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:pad_core/pad_core.dart';

import 'theme.dart';
import 'three/controller_scene.dart';
import 'three/scene.dart';
import 'three/vec.dart';

/// Manette en volume, manipulable.
///
/// Le modèle est un vrai maillage (corps extrudé, sticks cylindriques, croix,
/// gâchettes) rendu par un painter trié en profondeur : on peut faire un tour
/// complet, l'arrière est dessiné lui aussi. Les boutons sont cliquables et
/// s'allument quand l'état de la manette les signale.
class Controller3D extends StatefulWidget {
  const Controller3D({
    super.key,
    required this.state,
    this.layout = PadLayout.playstation,
    this.family,
    this.height = 280,
    this.autoRotate = false,
    this.initialYaw = -0.42,
    this.initialPitch = 0.38,
    this.onButtonTap,
    this.showHint = false,
  });

  final PadState state;
  final PadLayout layout;

  /// Modèle détecté ; à défaut, déduit de [layout].
  final ControllerFamily? family;
  final double height;
  final bool autoRotate;
  final double initialYaw;
  final double initialPitch;

  /// Appelé quand on touche un bouton sur le modèle.
  final ValueChanged<PadButton>? onButtonTap;

  /// Affiche « glisser pour tourner » sous le modèle.
  final bool showHint;

  @override
  State<Controller3D> createState() => _Controller3DState();
}

class _Controller3DState extends State<Controller3D> with SingleTickerProviderStateMixin {
  late double _yaw = widget.initialYaw;
  late double _pitch = widget.initialPitch;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _velocity = 0;
  bool _dragging = false;

  ControllerFamily? _sceneFamily;
  Brightness? _sceneBrightness;
  ControllerScene? _scene;

  PadButton? _flashing;
  int _flashStart = 0;

  final List<_Hit> _hits = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || _dragging) return;

    var dirty = false;
    if (_velocity.abs() > 0.002) {
      _yaw += _velocity * dt;
      _velocity *= math.pow(0.02, dt).toDouble(); // amortissement ~ 1,9 s
      dirty = true;
    }
    if (widget.autoRotate) {
      _yaw += dt * 0.35;
      dirty = true;
    }
    if (_flashing != null &&
        elapsed.inMilliseconds - _flashStart > 260) {
      _flashing = null;
      dirty = true;
    }
    if (dirty) setState(() {});
  }

  void _reset() => setState(() {
    _yaw = widget.initialYaw;
    _pitch = widget.initialPitch;
    _velocity = 0;
  });

  ControllerFamily get _family =>
      widget.family ??
      switch (widget.layout) {
        PadLayout.playstation => ControllerFamily.dualSense,
        PadLayout.xbox => ControllerFamily.xboxSeries,
        PadLayout.nintendo => ControllerFamily.switchPro,
        _ => ControllerFamily.generic,
      };

  void _tap(Offset local) {
    _Hit? best;
    var bestDistance = double.infinity;
    for (final hit in _hits) {
      final d = (hit.position - local).distance;
      if (d < hit.radius && d < bestDistance) {
        best = hit;
        bestDistance = d;
      }
    }
    if (best == null) return;
    setState(() {
      _flashing = best!.button;
      _flashStart = _last.inMilliseconds;
    });
    widget.onButtonTap?.call(best.button);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final family = _family;
    final brightness = Theme.of(context).brightness;
    if (_scene == null || _sceneFamily != family || _sceneBrightness != brightness) {
      _scene = ControllerScene.build(family, brightness);
      _sceneFamily = family;
      _sceneBrightness = brightness;
    }

    final hintHeight = widget.showHint ? 18.0 : 0.0;
    // Le widget s'adapte au parent : si une hauteur maximale est imposée, on
    // y rentre (le texte d'aide compris) au lieu de déborder de quelques px.
    return LayoutBuilder(
      builder: (context, outer) {
        final canvasHeight = outer.hasBoundedHeight
            ? math.min(widget.height, outer.maxHeight - hintHeight)
            : widget.height;
        return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: canvasHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Cadrage calculé sur l'emprise réelle du modèle : il reste
              // stable quand on tourne (pas de zoom « respirant »).
              final fit = _Fit.of(_scene!, constraints.biggest);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _reset,
                onTapUp: (d) => _tap(d.localPosition),
                onPanStart: (_) => setState(() {
                  _dragging = true;
                  _velocity = 0;
                }),
                onPanUpdate: (details) => setState(() {
                  _yaw += details.delta.dx * 0.011;
                  _pitch = (_pitch + details.delta.dy * 0.006).clamp(-0.85, 1.35);
                }),
                onPanEnd: (details) {
                  _velocity = details.velocity.pixelsPerSecond.dx * 0.011;
                  setState(() => _dragging = false);
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _Controller3DPainter(
                    scene: _scene!,
                    camera: OrbitCamera(yaw: _yaw, pitch: _pitch),
                    state: widget.state,
                    fit: fit,
                    accent: colors.cyan,
                    flashing: _flashing,
                    hits: _hits,
                    origin: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.showHint)
          SizedBox(
            height: hintHeight,
            child: Center(
              child: Text(
                'glisser pour tourner · double-tap pour recentrer',
                style: TextStyle(fontSize: 9.5, color: colors.muted),
              ),
            ),
          ),
      ],
        );
      },
    );
  }
}

/// Cadrage : échelle et décalage vertical pour que la manette remplisse
/// l'espace disponible quel que soit le modèle ou l'angle.
class _Fit {
  const _Fit(this.scale, this.centerDy);

  final double scale;
  final double centerDy;

  static _Fit of(ControllerScene scene, Size size) {
    // Emprise horizontale la plus large possible sur un tour complet : un
    // sommet à (x, z) décrit un cercle de rayon sqrt(x² + z²).
    var halfWidth = 0.0;
    var halfHeight = 0.0;
    var minY = 0.0;
    var maxY = 0.0;
    for (final part in scene.parts) {
      for (final v in part.verts) {
        final r = math.sqrt(v.x * v.x + v.z * v.z);
        if (r > halfWidth) halfWidth = r;
        if (v.y < minY) minY = v.y;
        if (v.y > maxY) maxY = v.y;
        if (v.y.abs() > halfHeight) halfHeight = v.y.abs();
      }
    }
    final scale = math.min(
      (size.width * 0.49) / halfWidth,
      (size.height * 0.49) / halfHeight,
    );
    // Centre vertical de la boîte englobante, pour éviter de laisser un
    // grand vide au-dessus de la manette.
    final centerDy = ((minY + maxY) / 2) * scale;
    return _Fit(scale, centerDy);
  }
}

class _Hit {
  const _Hit(this.button, this.position, this.radius);

  final PadButton button;
  final Offset position;
  final double radius;
}

class _Controller3DPainter extends CustomPainter {
  _Controller3DPainter({
    required this.scene,
    required this.camera,
    required this.state,
    required this.fit,
    required this.accent,
    required this.flashing,
    required this.hits,
    required this.origin,
  });

  final ControllerScene scene;
  final OrbitCamera camera;
  final PadState state;
  final _Fit fit;
  final Color accent;
  final PadButton? flashing;
  final List<_Hit> hits;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.translate(0, fit.centerDy);

    // Halo derrière la manette : donne du volume sans être « néon ».
    canvas.drawCircle(
      center.translate(0, -size.height * 0.04),
      size.height * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.10), accent.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(
          center: center.translate(0, -size.height * 0.04),
          radius: size.height * 0.46,
        )),
    );

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, size.height * 0.40),
        width: size.width * 0.62,
        height: size.height * 0.10,
      ),
      shadow,
    );

    Offset project(V3 p) {
      final r = camera.rotate(p);
      final s = camera.perspective(r.z);
      return Offset(
        center.dx + r.x * fit.scale * s,
        center.dy - r.y * fit.scale * s,
      );
    }

    final projected = <List<Offset>>[];
    final faceList = <({
      int group,
      int layer,
      double elevation,
      double depth,
      List<Offset> pts,
      Color color,
    })>[];

    // La coque est un prisme convexe : les gros polygones de sa face avant
    // ne peuvent pas être triés par profondeur moyenne face aux petits
    // objets posés dessus (un stick passait dessous). On raisonne donc par
    // plans : ce qui est derrière la coque, la coque, puis ce qui est posé
    // dessus — et l'ordre des deux premiers groupes s'inverse quand on
    // regarde la manette de dos.
    const planeZ = ControllerScene.front;
    final seesFront = camera.rotate(const V3(0, 0, 1)).z > 0;

    int groupOf(Part part) {
      if (part.role == 'shell') return 1;
      var minZ = double.infinity;
      var maxZ = double.negativeInfinity;
      for (final v in part.verts) {
        if (v.z < minZ) minZ = v.z;
        if (v.z > maxZ) maxZ = v.z;
      }
      if (minZ > planeZ - 0.02) return 2; // posé sur la façade
      if (maxZ < planeZ - 0.02) return 0; // gâchettes, trappe, vis
      return 1;
    }

    for (final part in scene.parts) {
      final pts = [for (final v in part.verts) project(v)];
      projected.add(pts);
      var value = part.button == null ? 0.0 : state.axisForButton(part.button!);
      for (final b in part.buttons) {
        value = math.max(value, state.axisForButton(b));
      }
      final isOn = (part.button != null || part.buttons.isNotEmpty) &&
          (value >= 0.5 ||
              (flashing != null &&
                  (flashing == part.button || part.buttons.contains(flashing))));
      // Élévation = point le plus haut de la pièce : sur une façade, l'ordre
      // de peinture correct est du plus bas au plus haut, pas la profondeur
      // moyenne (une grande plaque fine passait par-dessus la croix).
      var elevation = double.negativeInfinity;
      for (final v in part.verts) {
        if (v.z > elevation) elevation = v.z;
      }
      var rawGroup = groupOf(part);
      // Vue de dos : les détails de façade sont derrière, la coque devant.
      final group = rawGroup == 1
          ? 1
          : (seesFront ? rawGroup : 2 - rawGroup);
      for (final face in part.faces) {
        var depth = 0.0;
        for (final i in face.indices) {
          depth += camera.depthOf(part.verts[i]);
        }
        depth /= face.indices.length;
        faceList.add((
          group: group,
          layer: face.layer,
          elevation: elevation,
          depth: depth,
          pts: [for (final i in face.indices) pts[i]],
          // Un bouton enfoncé s'allume : la pièce prend la teinte d'accent,
          // comme une LED sous le capuchon.
          color: isOn ? Color.lerp(face.color, accent, part.glow)! : face.color,
        ));
      }
    }

    // Peintre : groupe (derrière / coque / posé sur la façade), puis
    // hauteur de pose, puis profondeur.
    faceList.sort((a, b) {
      final g = a.group.compareTo(b.group);
      if (g != 0) return g;
      final l = a.layer.compareTo(b.layer);
      if (l != 0) return l;
      if (a.group == 2) {
        final e = a.elevation.compareTo(b.elevation);
        if (e != 0) return e;
      }
      return a.depth.compareTo(b.depth);
    });

    final fill = Paint()..style = PaintingStyle.fill;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;
    for (final face in faceList) {
      final path = Path()..addPolygon(face.pts, true);
      fill.color = face.color;
      canvas.drawPath(path, fill);
      // Trait de la même couleur : masque les micro-fentes entre facettes
      // adjacentes, très visibles sur les flancs clairs.
      seam.color = face.color;
      canvas.drawPath(path, seam);
    }

    // Éclairage du dessus : un reflet large en haut à gauche et une
    // occlusion douce en bas. Sans ça, la face avant reste un aplat plat.
    // Nombre de sommets de l'anneau avant du boîtier (la coque a désormais
    // trois anneaux : avant, joint, arrière).
    var contourHalf = projected.first.length ~/ 2;
    for (final part in scene.parts) {
      if (part.role == 'shell') {
        contourHalf = part.seam.isNotEmpty
            ? part.seam.length
            : part.verts.length ~/ 2;
        break;
      }
    }
    final topPath = Path()
      ..addPolygon(
        [for (var i = 0; i < contourHalf; i++) projected.first[i]],
        true,
      );
    canvas.save();
    canvas.clipPath(topPath);
    final bounds = topPath.getBounds();
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.75),
          radius: 1.15,
          colors: [
            Colors.white.withValues(alpha: 0.17),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0.48, 1.0],
        ).createShader(bounds),
    );
    canvas.restore();

    // Arête du corps : on ne trace que l'anneau le plus proche de la
    // caméra. Tracer aussi l'anneau arrière dessinait un faux liseré au
    // milieu de la face avant (il est physiquement masqué).
    final bodyPart = scene.parts.firstWhere(
      (part) => part.role == 'shell',
      orElse: () => scene.parts.first,
    );
    final bodyPts = projected[scene.parts.indexOf(bodyPart)];
    final ringSize = bodyPart.ringSize == 0
        ? bodyPts.length ~/ 2
        : bodyPart.ringSize;
    final ringCount = ringSize == 0 ? 1 : bodyPts.length ~/ ringSize;
    var nearest = 0;
    var nearestDepth = double.negativeInfinity;
    for (var r = 0; r < ringCount; r++) {
      var depth = 0.0;
      for (var i = 0; i < ringSize; i++) {
        depth += camera.depthOf(bodyPart.verts[r * ringSize + i]);
      }
      depth /= ringSize;
      if (depth > nearestDepth) {
        nearestDepth = depth;
        nearest = r;
      }
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeJoin = StrokeJoin.round;
    final outlinePath = Path()
      ..addPolygon(
        [
          for (var i = 0; i < ringSize; i++) bodyPts[nearest * ringSize + i],
        ],
        true,
      );
    canvas.drawPath(outlinePath, edge);

    // Liseré lumineux : la lumière accroche l'arête du boîtier. Tracé à
    // l'intérieur du contour (clip), il ne déborde pas de la silhouette.
    canvas.save();
    canvas.clipPath(outlinePath);
    canvas.drawPath(
      outlinePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = Colors.white.withValues(alpha: 0.34),
    );
    canvas.restore();

    // Capuchons de sticks : dégradé radial pour donner la rotondité, sinon
    // ils se lisent comme de simples disques sombres. Ignorés quand la
    // manette est vue de dos, sinon ils flottent sur la coque arrière.
    for (var p = 0; p < scene.parts.length; p++) {
      final part = scene.parts[p];
      final cap = part.capCenter;
      if (cap == null) continue;
      if (camera.depthOf(V3(cap.dx, cap.dy, part.capZ)) < 0.05) continue;
      final z = part.capZ;
      final centerScreen = project(V3(cap.dx, cap.dy, z));
      final edge = project(V3(cap.dx + part.capRadius, cap.dy, z));
      final radius = (edge - centerScreen).distance;
      final rect = Rect.fromCircle(center: centerScreen, radius: radius * 1.02);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            colors: [
              Colors.white.withValues(alpha: 0.20),
              Colors.white.withValues(alpha: 0.02),
              Colors.black.withValues(alpha: 0.30),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect),
      );
    }

    // Liseré lumineux du pavé tactile (DualSense / DualShock) : un trait
    // continu qui suit son pourtour.
    final touch = scene.parts.where((part) => part.name == 'touchpad');
    if (touch.isNotEmpty) {
      final part = touch.first;
      final ringSize = part.ringSize;
      final pts = projected[scene.parts.indexOf(part)];
      canvas.drawPath(
        Path()
          ..addPolygon(
            [for (var i = 0; i < ringSize; i++) pts[i]],
            true,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round
          ..color = accent.withValues(alpha: 0.85),
      );
    }

    // Symboles des boutons de façade : tracés vectoriels (un « ○ » de police
    // n'a ni la graisse ni l'alignement d'un vrai symbole imprimé).
    final facing = camera.rotate(const V3(0, 0, 1)).z;
    if (facing > 0.12) {
      for (final part in scene.parts) {
        if (part.glyph == null && part.label == null) continue;
        final c = _centroid(part);
        final screen = project(c);
        final persp = camera.perspective(camera.rotate(c).z);
        final color = part.labelColor ?? const Color(0xFFE9EDF5);
        if (part.glyph != null) {
          _paintGlyph(
            canvas,
            part.glyph!,
            screen,
            radius: 0.036 * fit.scale * persp,
            color: color,
            angle: 0,
          );
        } else {
          final tp = TextPainter(
            text: TextSpan(
              text: part.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: (0.072 * fit.scale * persp * part.labelScale)
                    .clamp(7.0, 30.0),
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, screen - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // Zones cliquables (invisibles) : un appui sur le modèle renvoie le
    // bouton logique correspondant.
    hits.clear();
    for (final entry in scene.buttons) {
      // Un bouton revenu de l'autre côté du boîtier ne doit pas capter le
      // clic : sinon on « appuie » sur la face cachée.
      if (camera.depthOf(entry.center) < -0.02) continue;
      final screen = project(entry.center);
      final persp = camera.perspective(camera.rotate(entry.center).z);
      hits.add(_Hit(entry.button, screen, entry.radius * fit.scale * persp));
    }
  }

  /// Trace un symbole PlayStation en traits épais, à la taille demandée.
  void _paintGlyph(
    Canvas canvas,
    PadGlyph glyph,
    Offset center, {
    required double radius,
    required Color color,
    double angle = 0,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, radius * 0.24)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final r = radius;
    switch (glyph) {
      case PadGlyph.circle:
        canvas.drawCircle(Offset.zero, r * 0.88, paint);
      case PadGlyph.cross:
        final d = r * 0.66;
        canvas.drawLine(Offset(-d, -d), Offset(d, d), paint);
        canvas.drawLine(Offset(d, -d), Offset(-d, d), paint);
      case PadGlyph.square:
        final s = r * 0.80;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 2),
            Radius.circular(r * 0.16),
          ),
          paint,
        );
      case PadGlyph.triangle:
        final path = Path()
          ..moveTo(0, -r * 0.95)
          ..lineTo(r * 0.90, r * 0.68)
          ..lineTo(-r * 0.90, r * 0.68)
          ..close();
        canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  V3 _centroid(Part part) {
    var sum = V3.zero;
    for (final v in part.verts) {
      sum = sum + v;
    }
    return sum * (1 / part.verts.length);
  }

  @override
  bool shouldRepaint(_Controller3DPainter old) =>
      old.camera.yaw != camera.yaw ||
      old.camera.pitch != camera.pitch ||
      old.state != state ||
      old.flashing != flashing ||
      old.fit.scale != fit.scale;
}


/// Point d'entrée de test : construit le painter avec un cadrage explicite.
@visibleForTesting
CustomPainter debugControllerPainter({
  required ControllerScene scene,
  required OrbitCamera camera,
  required PadState state,
  required Size size,
  required Offset origin,
}) => _Controller3DPainter(
  scene: scene,
  camera: camera,
  state: state,
  fit: _Fit.of(scene, size),
  accent: const Color(0xFF22E6FF),
  flashing: null,
  hits: [],
  origin: origin,
);
