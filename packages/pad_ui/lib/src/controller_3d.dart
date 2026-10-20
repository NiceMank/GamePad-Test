import 'dart:math' as math;
import 'dart:typed_data';

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

/// Orientation et clignotement partagés avec le peintre : pendant une
/// rotation, seul le canevas se redessine — aucun widget n'est reconstruit.
class _View extends ChangeNotifier {
  _View({required this.yaw, required this.pitch});

  double yaw;
  double pitch;
  double velocity = 0;
  bool dragging = false;
  PadButton? flashing;
  int flashStart = 0;

  bool get busy => velocity.abs() > 0.002 || flashing != null;

  void bump() => notifyListeners();
}

class _Controller3DState extends State<Controller3D>
    with SingleTickerProviderStateMixin {
  late final _View _view = _View(
    yaw: widget.initialYaw,
    pitch: widget.initialPitch,
  );
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  ControllerFamily? _sceneFamily;
  Brightness? _sceneBrightness;
  ControllerScene? _scene;

  final List<_Hit> _hits = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Le ticker ne tourne que lorsqu'il y a quelque chose à animer : au
    // repos, plus aucune image n'est demandée.
    if (widget.autoRotate) _startTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _view.dispose();
    super.dispose();
  }

  void _startTicker() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || _view.dragging) return;

    var dirty = false;
    if (_view.velocity.abs() > 0.002) {
      _view.yaw += _view.velocity * dt;
      _view.velocity *= math.pow(0.02, dt).toDouble(); // amortissement ~ 1,9 s
      dirty = true;
    }
    if (widget.autoRotate) {
      _view.yaw += dt * 0.35;
      dirty = true;
    }
    final flash = _view.flashing;
    // Horodatage mural : le ticker peut redémarrer, l'extinction du flash ne
    // doit pas dépendre de son compteur.
    if (flash != null &&
        DateTime.now().millisecondsSinceEpoch - _view.flashStart > 260) {
      _view.flashing = null;
      dirty = true;
    }
    if (dirty) _view.bump();
    if (!_view.busy && !widget.autoRotate) _ticker.stop();
  }

  void _reset() {
    _view.yaw = widget.initialYaw;
    _view.pitch = widget.initialPitch;
    _view.velocity = 0;
    _view.bump();
  }

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
    _view.flashing = best.button;
    _view.flashStart = DateTime.now().millisecondsSinceEpoch;
    _view.bump();
    _startTicker();
    widget.onButtonTap?.call(best.button);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final family = _family;
    final brightness = Theme.of(context).brightness;
    if (_scene == null ||
        _sceneFamily != family ||
        _sceneBrightness != brightness) {
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
                    onPanStart: (_) {
                      _view.dragging = true;
                      _view.velocity = 0;
                      _view.bump();
                    },
                    onPanUpdate: (details) {
                      _view.yaw += details.delta.dx * 0.011;
                      _view.pitch = (_view.pitch + details.delta.dy * 0.006)
                          .clamp(-0.85, 1.35);
                      _view.bump();
                    },
                    onPanEnd: (details) {
                      _view.velocity =
                          details.velocity.pixelsPerSecond.dx * 0.011;
                      _view.dragging = false;
                      _view.bump();
                      _startTicker();
                    },
                    // Isolé du reste de l'écran : une rotation ne repeint que le
                    // modèle, pas les cartes ni le texte autour.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _Controller3DPainter(
                          scene: _scene!,
                          state: widget.state,
                          fit: fit,
                          accent: colors.cyan,
                          view: _view,
                          hits: _hits,
                          origin: Offset(
                            constraints.maxWidth / 2,
                            constraints.maxHeight / 2,
                          ),
                        ),
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

/// Plan de scène : déplie le maillage en une liste de faces avec tout ce
/// qui ne dépend pas de l'angle de vue (groupe de plan, couche, teinte).
///
/// L'ordre de peinture reste celui d'avant — groupe, couche, élévation puis
/// profondeur — mais il est calculé sur des faces déjà dépliées, et les
/// faces consécutives de même teinte sont tracées en un seul `Path`.
class _ScenePlan {
  _ScenePlan._(this.parts, this.faces);

  final List<_PartPlan> parts;
  final List<_FacePlan> faces;

  static ControllerScene? _scene;
  static int _accentKey = 0;
  static _ScenePlan? _plan;

  static _ScenePlan of(ControllerScene scene, Color accent) {
    final key = accent.toARGB32();
    if (identical(scene, _scene) && key == _accentKey && _plan != null) {
      return _plan!;
    }
    _scene = scene;
    _accentKey = key;
    final built = _build(scene, accent);
    _plan = _ScenePlan._(built.parts, built.faces);
    return _plan!;
  }

  static ({List<_PartPlan> parts, List<_FacePlan> faces}) _build(
    ControllerScene scene,
    Color accent,
  ) {
    const planeZ = ControllerScene.front;
    final parts = <_PartPlan>[];
    final faces = <_FacePlan>[];
    var offset = 0;

    for (final part in scene.parts) {
      var minZ = double.infinity;
      var maxZ = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      // Rayon de la pièce : sert à donner une courbure douce à la coque,
      // comme une surface moulée plutôt qu'une plaque plate.
      var radius = 0.0001;
      for (final v in part.verts) {
        final r = v.x * v.x + v.y * v.y;
        if (r > radius) radius = r;
      }
      radius = math.sqrt(radius);
      for (final v in part.verts) {
        if (v.z < minZ) minZ = v.z;
        if (v.z > maxZ) maxZ = v.z;
        if (v.z > maxY) maxY = v.z;
      }

      final int group;
      if (part.role == 'shell') {
        group = 1;
      } else if (minZ > planeZ - 0.02) {
        group = 2; // posé sur la façade
      } else if (maxZ < planeZ - 0.02) {
        group = 0; // gâchettes, trappe, vis
      } else {
        group = 1;
      }

      final plan = _PartPlan(
        part: part,
        offset: offset,
        group: group,
        elevation: maxY,
        normals: part.smooth ? smoothNormals(part.verts, part.faces) : const [],
      )..curved = part.role == 'shell';
      final glow = part.glow;
      for (final face in part.faces) {
        final base = face.color;
        // Normale de la facette, calculée une fois : le peintre s'en sert
        // pour l'éclairage (Lambert + reflet) à chaque image.
        var nx = 0.0, ny = 0.0, nz = 0.0;
        final ind = face.indices;
        if (ind.length >= 3) {
          final a = part.verts[ind[0]];
          final b = part.verts[ind[1]];
          final c = part.verts[ind[2]];
          final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
          final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
          nx = uy * vz - uz * vy;
          ny = uz * vx - ux * vz;
          nz = ux * vy - uy * vx;
          final len = math.sqrt(nx * nx + ny * ny + nz * nz);
          if (len > 0.000001) {
            nx /= len;
            ny /= len;
            nz /= len;
          }
        }
        var cx = 0.0, cy = 0.0;
        for (final i in ind) {
          cx += part.verts[i].x;
          cy += part.verts[i].y;
        }
        if (ind.isNotEmpty) {
          cx /= ind.length;
          cy /= ind.length;
        }
        final curv = math.sqrt(cx * cx + cy * cy) / radius;

        faces.add(
          _FacePlan(
            owner: plan,
            nx: nx,
            ny: ny,
            nz: nz,
            curv: curv.clamp(0.0, 1.0),
            flat: face.flat,
            offset: offset,
            indices: face.indices,
            layer: face.layer,
            group: group,
            elevation: maxY,
            color: base,
            lit: glow <= 0 ? base : Color.lerp(base, accent, glow)!,
          ),
        );
      }
      parts.add(plan);
      offset += part.verts.length;
    }

    return (parts: parts, faces: faces);
  }
}

class _PartPlan {
  _PartPlan({
    required this.part,
    required this.offset,
    required this.group,
    required this.elevation,
    required this.normals,
  });

  /// Normales lissées par sommet (pièces de révolution uniquement) : c'est
  /// ce qui arrondit les sticks et les capuchons au lieu de les laisser
  /// facettés. Vide pour les pièces plates, éclairées facette par facette.
  final List<V3> normals;

  final Part part;
  final int offset;
  final int group;
  final double elevation;

  /// Pièce en cours d'appui : sa teinte passe à l'accent.
  bool isOn = false;

  /// Coque : seule pièce à recevoir la courbure de surface.
  bool curved = false;
}

/// Une face prête à peindre : indices locaux, teinte au repos et teinte
/// allumée, plus sa clé de tri précalculée.
class _FacePlan {
  _FacePlan({
    required this.owner,
    required this.nx,
    required this.ny,
    required this.nz,
    required this.curv,
    required this.flat,
    required this.offset,
    required this.indices,
    required this.layer,
    required this.group,
    required this.elevation,
    required this.color,
    required this.lit,
  });

  final _PartPlan owner;

  /// Normale unitaire de la facette, en espace objet.
  final double nx;
  final double ny;
  final double nz;

  /// Éloignement du centre de la pièce (0 au centre, 1 au bord) : donne la
  /// courbure des surfaces moulées.
  final double curv;

  /// Aplat mat : ni reflet, ni courbure (dessus de bouton, pavé tactile).
  final bool flat;
  final int offset;
  final List<int> indices;
  final int layer;
  final int group;
  final double elevation;
  final Color color;
  final Color lit;

  double depth = 0;

  /// Facette réduite à un trait à l'écran : inutile de la peindre.
  bool culled = false;
}

/// Projection d'une scène pour une caméra donnée, réutilisée entre les
/// images (aucune allocation par sommet).
class _Projection {
  static final _Projection instance = _Projection._();

  _Projection._();

  late Float64List _sx = Float64List(0);
  late Float64List _sy = Float64List(0);
  late Float64List _sz = Float64List(0);
  int length = 0;
  Offset center = Offset.zero;
  double scale = 1;

  double sinYaw = 0, cosYaw = 1, sinPitch = 0, cosPitch = 1;
  double focal = 3.6;

  void build(
    ControllerScene scene,
    OrbitCamera camera,
    Offset center,
    double scale,
  ) {
    var total = 0;
    for (final part in scene.parts) {
      total += part.verts.length;
    }
    if (_sx.length < total) {
      _sx = Float64List(total);
      _sy = Float64List(total);
      _sz = Float64List(total);
    }
    this.center = center;
    this.scale = scale;
    sinYaw = math.sin(camera.yaw);
    cosYaw = math.cos(camera.yaw);
    sinPitch = math.sin(camera.pitch);
    cosPitch = math.cos(camera.pitch);
    focal = camera.focal;

    var i = 0;
    for (final part in scene.parts) {
      for (final v in part.verts) {
        // Rotation caméra écrite à la main : évite six appels
        // trigonométriques et deux objets par sommet.
        final x1 = v.x * cosYaw + v.z * sinYaw;
        final z1 = -v.x * sinYaw + v.z * cosYaw;
        final y2 = v.y * cosPitch - z1 * sinPitch;
        final z2 = v.y * sinPitch + z1 * cosPitch;
        final s = focal / (focal - z2);
        _sx[i] = center.dx + x1 * scale * s;
        _sy[i] = center.dy - y2 * scale * s;
        _sz[i] = z2;
        i++;
      }
    }
    length = total;
  }

  /// Profondeur caméra d'un point isolé (centres de lot, zones cliquables).
  double depthOf(V3 p) {
    final z1 = -p.x * sinYaw + p.z * cosYaw;
    return p.y * sinPitch + z1 * cosPitch;
  }

  Offset project(V3 p) {
    final x1 = p.x * cosYaw + p.z * sinYaw;
    final z1 = -p.x * sinYaw + p.z * cosYaw;
    final y2 = p.y * cosPitch - z1 * sinPitch;
    final z2 = p.y * sinPitch + z1 * cosPitch;
    final s = focal / (focal - z2);
    return Offset(center.dx + x1 * scale * s, center.dy - y2 * scale * s);
  }
}

class _Controller3DPainter extends CustomPainter {
  _Controller3DPainter({
    required this.scene,
    required this.view,
    required this.state,
    required this.fit,
    required this.accent,
    required this.hits,
    required this.origin,
  }) : super(repaint: view);

  final ControllerScene scene;

  /// Orientation courante : lue à chaque image, ce qui permet de tourner
  /// sans reconstruire le widget.
  final _View view;
  final PadState state;
  final _Fit fit;
  final Color accent;
  final List<_Hit> hits;
  final Offset origin;

  // Caches inter-images : créer un shader ou un TextPainter à chaque image
  // était l'une des dépenses les plus visibles.
  static List<int> _order = const [];
  static final Map<int, Shader> _halo = {};
  static final Map<int, Shader> _shadow = {};
  static final Map<String, TextPainter> _labels = {};
  static final Map<int, Shader> _caps = {};

  static Shader _cached(
    Map<int, Shader> cache,
    int key,
    Shader Function() build,
  ) {
    if (cache.length > 64) cache.clear();
    return cache.putIfAbsent(key, build);
  }

  static TextPainter _label(String key, TextPainter Function() build) {
    if (_labels.length > 48) _labels.clear();
    return _labels.putIfAbsent(key, build);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final camera = OrbitCamera(yaw: view.yaw, pitch: view.pitch);
    final center = origin.translate(0, fit.centerDy);

    // Halo derrière la manette.
    final haloRadius = size.height * 0.46;
    final haloCenter = center.translate(0, -size.height * 0.04);
    // Shader mis en cache dans un repère unitaire, puis placé par la
    // transformation du canevas : c'est ce qui garde le dégradé centré.
    canvas.save();
    canvas.translate(haloCenter.dx, haloCenter.dy);
    canvas.scale(haloRadius / 1.0);
    canvas.drawCircle(
      Offset.zero,
      1.0,
      Paint()
        ..shader = _cached(_halo, accent.toARGB32(), () {
          return RadialGradient(
            colors: [
              accent.withValues(alpha: 0.10),
              accent.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
        }),
    );
    canvas.restore();

    // Ombre au sol : un dégradé radial rend le même flou qu'un MaskFilter
    // sans payer le coût de rasterisation d'un vrai flou.
    final shadowRect = Rect.fromCenter(
      center: center.translate(0, size.height * 0.38),
      width: size.width * 0.92,
      height: size.height * 0.16,
    );
    canvas.save();
    canvas.translate(shadowRect.center.dx, shadowRect.center.dy);
    canvas.scale(shadowRect.width / 2, shadowRect.height / 2);
    canvas.drawOval(
      Rect.fromCircle(center: Offset.zero, radius: 1),
      Paint()
        ..shader = _cached(_shadow, 1, () {
          return const RadialGradient(
            colors: [Color(0x4D000000), Color(0x1A000000), Color(0x00000000)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
        }),
    );
    canvas.restore();

    final proj = _Projection.instance..build(scene, camera, center, fit.scale);
    final plan = _ScenePlan.of(scene, accent);
    final seesFront = camera.rotate(const V3(0, 0, 1)).z > 0;

    // État d'appui : une évaluation par pièce, pas par face.
    for (final part in plan.parts) {
      part.isOn = _intensity(part.part) >= 0.5 || _isFlashing(part.part);
    }

    // Profondeur moyenne de chaque face, lue dans la projection déjà faite.
    // Les facettes vues de chant (moins d'un pixel) sont écartées : leur
    // liseré anti-fentes débordait sur les faces voisines et hachurait les
    // flancs.
    final faces = plan.faces;
    for (final face in faces) {
      final indices = face.indices;
      final base = face.offset;
      var d = 0.0;
      var minX = double.infinity, maxX = double.negativeInfinity;
      var minY = double.infinity, maxY = double.negativeInfinity;
      for (var i = 0; i < indices.length; i++) {
        final k = base + indices[i];
        d += proj._sz[k];
        final x = proj._sx[k];
        final y = proj._sy[k];
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
      face.depth = d / indices.length;
      face.culled = (maxX - minX) < 1.0 && (maxY - minY) < 1.0;
    }

    // Peintre : groupe (derrière / coque / façade), couche, élévation de
    // pose, puis profondeur — exactement l'ordre qui donnait le rendu
    // validé, mais sur des faces déjà dépliées.
    final order = _order.length == faces.length
        ? _order
        : (_order = List<int>.generate(
            faces.length,
            (i) => i,
            growable: false,
          ));
    order.sort((a, b) {
      final fa = faces[a];
      final fb = faces[b];
      final ga = fa.group == 1 ? 1 : (seesFront ? fa.group : 2 - fa.group);
      final gb = fb.group == 1 ? 1 : (seesFront ? fb.group : 2 - fb.group);
      if (ga != gb) return ga.compareTo(gb);
      if (fa.layer != fb.layer) return fa.layer.compareTo(fb.layer);
      if (ga == 2) {
        final e = fa.elevation.compareTo(fb.elevation);
        if (e != 0) return e;
      }
      return fa.depth.compareTo(fb.depth);
    });

    // Sans antialiasing sur les facettes : les triangles voisins se
    // rastérisent jointivement, et l'antialiasing laissait des fentes
    // sombres le long des arêtes. La silhouette est redessinée plus bas.
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final path = Path();

    // Lumière fixe dans le repère caméra : en tournant, les facettes
    // s'éclairent et s'assombrissent comme sur un objet réel, au lieu de
    // porter une teinte figée calculée une fois pour toutes.
    const lx = -0.417, ly = 0.560, lz = 0.717;
    // Demi-vecteur entre la lumière et la caméra (0, 0, 1).
    final hx = lx, hy = ly, hz = lz + 1.0;
    final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
    final uhx = hx / hLen, uhy = hy / hLen, uhz = hz / hLen;

    for (var n = 0; n < order.length; n++) {
      final face = faces[order[n]];
      if (face.culled) continue;
      final albedo = face.owner.isOn ? face.lit : face.color;

      final indices = face.indices;
      final base = face.offset;
      final normals = face.owner.normals;
      var sx = face.nx, sy = face.ny, sz = face.nz;
      if (normals.isNotEmpty) {
        // Pièce de révolution : moyenne des normales de sommet, les facettes
        // se fondent au lieu de marquer des bandes.
        // Lissage à angle limite : on ne mélange que les normales qui
        // restent dans le même « morceau » de surface. Sans ce seuil, le
        // flanc et le dessus d'un stick s'additionnaient et la pièce
        // devenait blanche.
        sx = 0;
        sy = 0;
        sz = 0;
        for (var i = 0; i < indices.length; i++) {
          final nv = normals[indices[i]];
          final d = nv.x * face.nx + nv.y * face.ny + nv.z * face.nz;
          if (d > 0.55) {
            sx += nv.x;
            sy += nv.y;
            sz += nv.z;
          }
        }
        if (sx == 0 && sy == 0 && sz == 0) {
          sx = face.nx;
          sy = face.ny;
          sz = face.nz;
        }
      }

      // Normale passée dans le repère caméra (même rotation que les sommets).
      var n1x = sx * proj.cosYaw + sz * proj.sinYaw;
      var n1z = -sx * proj.sinYaw + sz * proj.cosYaw;
      var ny = sy * proj.cosPitch - n1z * proj.sinPitch;
      var nz = sy * proj.sinPitch + n1z * proj.cosPitch;

      // Le maillage n'a pas d'orientation garantie : on éclaire toujours la
      // face tournée vers l'observateur, sinon la moitié des pièces restait
      // grise.
      if (nz < 0) {
        n1x = -n1x;
        ny = -ny;
        nz = -nz;
      }

      final diff = (n1x * lx + ny * ly + nz * lz).clamp(0.0, 1.0);
      var spec = (n1x * uhx + ny * uhy + nz * uhz).clamp(0.0, 1.0);
      // Puissance 16 sans pow : trois multiplications enchaînées.
      spec *= spec; // 2
      spec *= spec; // 4
      spec *= spec; // 8
      spec *= spec; // 16
      // Courbure : la coque s'assombrit légèrement vers les bords, comme une
      // surface bombée sous une lumière venant du haut-gauche.
      final curve = face.owner.curved
          ? 1.0 - 0.14 * face.curv * face.curv
          : 1.0;
      final k = (0.58 + 0.42 * diff) * curve;
      final sp = face.flat ? 0.0 : spec * 0.085;

      final color = Color.fromARGB(
        (albedo.a * 255).round(),
        ((albedo.r * k + sp) * 255).round().clamp(0, 255),
        ((albedo.g * k + sp) * 255).round().clamp(0, 255),
        ((albedo.b * k + sp) * 255).round().clamp(0, 255),
      );

      path.reset();
      path.moveTo(proj._sx[base + indices[0]], proj._sy[base + indices[0]]);
      for (var i = 1; i < indices.length; i++) {
        final k = base + indices[i];
        path.lineTo(proj._sx[k], proj._sy[k]);
      }
      path.close();

      fill.color = color;
      canvas.drawPath(path, fill);
    }

    // --- éclairage du dessus ------------------------------------------------
    final shell = plan.parts.firstWhere(
      (p) => p.part.role == 'shell',
      orElse: () => plan.parts.first,
    );
    final shellBase = shell.offset;
    final ring = shell.part.ringSize == 0
        ? shell.part.verts.length ~/ 2
        : shell.part.ringSize;
    if (ring > 0) {
      // Anneau le plus proche de la caméra : c'est la silhouette visible.
      var nearest = 0;
      var nearestDepth = double.negativeInfinity;
      for (var r = 0; r * ring < shell.part.verts.length; r++) {
        var depth = 0.0;
        var n = 0;
        for (
          var i = 0;
          i < ring && r * ring + i < shell.part.verts.length;
          i++
        ) {
          depth += proj._sz[shellBase + r * ring + i];
          n++;
        }
        if (n == 0) break;
        depth /= n;
        if (depth > nearestDepth) {
          nearestDepth = depth;
          nearest = r;
        }
      }

      final outline = Path();
      final startIdx = shellBase + nearest * ring;
      var count = 0;
      for (
        var i = 0;
        i < ring && startIdx + i < shellBase + shell.part.verts.length;
        i++
      ) {
        final x = proj._sx[startIdx + i];
        final y = proj._sy[startIdx + i];
        if (i == 0) {
          outline.moveTo(x, y);
        } else {
          outline.lineTo(x, y);
        }
        count++;
      }
      if (count > 2) {
        outline.close();

        canvas.save();
        canvas.clipPath(outline);
        final bounds = outline.getBounds();
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.35, -0.75),
              radius: 1.15,
              colors: [Color(0x2BFFFFFF), Color(0x00FFFFFF)],
            ).createShader(bounds),
        );
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x29000000)],
              stops: [0.48, 1.0],
            ).createShader(bounds),
        );
        canvas.restore();

        final edge = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: 0.28);
        canvas.drawPath(outline, edge);

        canvas.save();
        canvas.clipPath(outline);
        canvas.drawPath(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..color = Colors.white.withValues(alpha: 0.34),
        );
        canvas.restore();
      }
    }

    // --- capuchons de sticks -------------------------------------------------
    final frontFacing = camera.rotate(const V3(0, 0, 1)).z;
    if (frontFacing > 0.12) {
      for (final part in scene.parts) {
        final cap = part.capCenter;
        if (cap == null) continue;
        final at = V3(cap.dx, cap.dy, part.capZ);
        if (proj.depthOf(at) < 0.05) continue;
        final centerScreen = proj.project(at);
        final edge = proj.project(
          V3(cap.dx + part.capRadius, cap.dy, part.capZ),
        );
        final radius = (edge - centerScreen).distance;
        if (radius < 1) continue;
        final r = radius * 1.02;
        canvas.save();
        canvas.translate(centerScreen.dx, centerScreen.dy);
        canvas.scale(r);
        canvas.drawOval(
          Rect.fromCircle(center: Offset.zero, radius: 1),
          Paint()
            ..shader = _cached(_caps, 1, () {
              return const RadialGradient(
                center: Alignment(-0.35, -0.45),
                colors: [
                  Color(0x33FFFFFF),
                  Color(0x05000000),
                  Color(0x4D000000),
                ],
                stops: [0.0, 0.55, 1.0],
              ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
            }),
        );
        canvas.restore();
      }
    }

    // --- liseré lumineux du pavé tactile ------------------------------------
    final touch = scene.parts.where((part) => part.name == 'touchpad');
    if (touch.isNotEmpty && frontFacing > 0.2) {
      final part = touch.first;
      final index = scene.parts.indexOf(part);
      final base = plan.parts[index].offset;
      final ringSize = part.ringSize;
      if (ringSize > 0) {
        final ringPath = Path();
        for (var i = 0; i < ringSize; i++) {
          final x = proj._sx[base + i];
          final y = proj._sy[base + i];
          if (i == 0) {
            ringPath.moveTo(x, y);
          } else {
            ringPath.lineTo(x, y);
          }
        }
        canvas.drawPath(
          ringPath..close(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFFBFD9EA),
        );
      }
    }

    // --- symboles des boutons ------------------------------------------------
    if (frontFacing > 0.12) {
      for (final part in scene.parts) {
        if (part.glyph == null && part.label == null) continue;
        final c = _centroid(part);
        final screen = proj.project(c);
        final persp = camera.perspective(proj.depthOf(c));
        final color = part.labelColor ?? const Color(0xFFE9EDF5);
        // Les lettres sont centrées optiquement : l'ascendante d'une police
        // sans empattement laisse un vide sous la ligne de base.
        if (part.glyph != null) {
          _paintGlyph(
            canvas,
            part.glyph!,
            screen,
            radius: 0.036 * fit.scale * persp,
            color: color,
          );
        } else {
          final fontSize = (0.072 * fit.scale * persp * part.labelScale).clamp(
            7.0,
            30.0,
          );
          final key =
              '${part.label}|${(fontSize * 2).round()}|${color.toARGB32()}';
          final tp = _label(key, () {
            return TextPainter(
              text: TextSpan(
                text: part.label,
                style: TextStyle(
                  fontFamily: PadType.body,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
          });
          tp.paint(canvas, screen - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // --- zones cliquables ----------------------------------------------------
    hits.clear();
    for (final entry in scene.buttons) {
      if (proj.depthOf(entry.center) < -0.02) continue;
      final screen = proj.project(entry.center);
      final persp = camera.perspective(proj.depthOf(entry.center));
      hits.add(_Hit(entry.button, screen, entry.radius * fit.scale * persp));
    }
  }

  double _intensity(Part part) {
    var value = part.button == null ? 0.0 : state.axisForButton(part.button!);
    for (final b in part.buttons) {
      value = math.max(value, state.axisForButton(b));
    }
    return value;
  }

  PadButton? get flashing => view.flashing;

  bool _isFlashing(Part part) {
    final f = flashing;
    if (f == null) return false;
    return f == part.button || part.buttons.contains(f);
  }

  /// Trace une lettre (A, B, X, Y) en traits, sans dépendre d'une police.
  void _paintLetter(
    Canvas canvas,
    String letter,
    Offset center,
    double radius,
    Color color,
  ) {
    final w = radius * 1.05;
    final h = radius * 1.15;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, radius * 0.26)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = Path();
    // Toutes les coordonnées passent par ces deux conversions : mélanger
    // repère normalisé et repère écran enverrait le tracé à l'origine.
    double px(double x) => center.dx + x * w;
    double py(double y) => center.dy - y * h;
    void move(double x, double y) => path.moveTo(px(x), py(y));
    void line(double x, double y) => path.lineTo(px(x), py(y));
    void curve(double cx, double cy, double ex, double ey) =>
        path.quadraticBezierTo(px(cx), py(cy), px(ex), py(ey));

    switch (letter) {
      case 'A':
        move(-0.55, -0.75);
        line(0, 0.75);
        line(0.55, -0.75);
        move(-0.32, -0.02);
        line(0.32, -0.02);
      case 'B':
        move(-0.45, -0.75);
        line(-0.45, 0.75);
        line(0.20, 0.75);
        curve(0.62, 0.75, 0.62, 0.38);
        curve(0.62, 0.02, 0.20, 0.02);
        line(-0.45, 0.02);
        move(0.20, 0.02);
        curve(0.66, 0.02, 0.66, -0.36);
        curve(0.66, -0.75, 0.20, -0.75);
        line(-0.45, -0.75);
      case 'X':
        move(-0.55, -0.75);
        line(0.55, 0.75);
        move(0.55, -0.75);
        line(-0.55, 0.75);
      case 'Y':
        // Deux branches qui se rejoignent au milieu, puis une queue courte :
        // c'est la lettre du vrai pad, pas un « V » barré.
        move(-0.55, -0.72);
        line(0, -0.06);
        line(0.55, -0.72);
        move(0, -0.06);
        line(0, 0.72);
    }
    canvas.drawPath(path, paint);
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
    // Les lettres Xbox sont dessinées en traits, comme les symboles
    // PlayStation : la police de l'interface ne se charge pas toujours dans
    // les rendus hors écran, et une lettre peinte reste lisible partout.
    switch (glyph) {
      case PadGlyph.letterA:
        return _paintLetter(canvas, 'A', center, radius, color);
      case PadGlyph.letterB:
        return _paintLetter(canvas, 'B', center, radius, color);
      case PadGlyph.letterX:
        return _paintLetter(canvas, 'X', center, radius, color);
      case PadGlyph.letterY:
        return _paintLetter(canvas, 'Y', center, radius, color);
      default:
        break;
    }
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
      case PadGlyph.letterA:
      case PadGlyph.letterB:
      case PadGlyph.letterX:
      case PadGlyph.letterY:
        break;
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
      !identical(old.scene, scene) ||
      old.state != state ||
      old.fit.scale != fit.scale ||
      old.fit.centerDy != fit.centerDy ||
      old.accent != accent ||
      !identical(old.view, view);
}

/// Point d'entrée de test : construit le painter avec un cadrage explicite.
@visibleForTesting
CustomPainter debugControllerPainter({
  required ControllerScene scene,
  required OrbitCamera camera,
  required PadState state,
  required Size size,
  required Offset origin,
}) {
  return _Controller3DPainter(
    scene: scene,
    view: _View(yaw: camera.yaw, pitch: camera.pitch),
    state: state,
    fit: _Fit.of(scene, size),
    accent: const Color(0xFF22E6FF),
    hits: [],
    origin: origin,
  );
}
