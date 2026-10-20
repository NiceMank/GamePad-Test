import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';

import 'vec.dart';

/// Une face polygonale convexe, peinte à plat.
class Face {
  const Face(
    this.indices,
    this.color, {
    this.lit = true,
    this.stroke,
    this.layer = 1,
    this.flat = false,
  });

  final List<int> indices;
  final Color color;
  final bool lit;
  final Color? stroke;

  /// Facette d'un aplat (dessus de bouton, pavé) : elle ne reçoit ni reflet
  /// spéculaire ni courbure, sinon un plastique mat se lit comme du verre.
  final bool flat;

  /// Ordre de peinture interne à une pièce : 0 = arrière, 1 = flancs,
  /// 2 = avant. Sans ça, la face arrière d'une coque opaque ressortait
  /// au-dessus de la face avant près de la silhouette.
  final int layer;
}

/// Symbole gravé sur un bouton de façade.
enum PadGlyph { circle, cross, square, triangle, letterA, letterB, letterX, letterY }

/// Morceau de manette (corps, stick, bouton…) avec ses faces.
class Part {
  Part({this.name, this.button, this.center, this.hitRadius = 0, this.sensitivity = 1});

  final String? name;

  /// Bouton logique associé (pour l'allumage et le clic).
  PadButton? button;

  /// Plusieurs boutons pilotent la même pièce (la croix s'allume dès qu'une
  /// direction est enfoncée).
  List<PadButton> buttons = const [];

  /// Rôle de la pièce, pour les finitions du painter (couture, reflet…).
  String? role;

  /// Anneau de couture (jonction coque haute / coque basse), s'il existe.
  List<V3> seam = const [];

  /// Vrai pour les pièces de révolution (sticks, boutons) : le peintre y
  /// utilise des normales lissées, ce qui arrondit la pièce.
  bool smooth = false;

  /// Nombre de sommets d'un anneau de contour (extrude en pose trois : avant,
  /// joint, arrière). Le painter s'en sert pour retrouver les anneaux.
  int ringSize = 0;

  /// Symbole vectoriel à graver au centre de la pièce.
  PadGlyph? glyph;
  Color? glyphColor;

  /// Hauteur du capuchon (sticks) pour le dégradé du painter.
  double capZ = 0;

  /// Intensité de l'allumage quand le bouton est actif (1 = plein).
  /// Les grandes pièces (épaule, croix) restent plus discrètes.
  double glow = 0.62;
  final V3? center;
  final double hitRadius;

  /// Intensité de l'allumage quand le bouton est actif (1 = plein).
  final double sensitivity;

  final List<V3> verts = [];
  final List<Face> faces = [];

  /// Texte dessiné au centre (glyphe du bouton), dans le plan avant.
  String? label;

  /// Si renseigné, un dégradé radial est appliqué au capuchon (sticks).
  Offset? capCenter;
  double capRadius = 0;
  Color? labelColor;
  double labelScale = 1;

  int addVertex(V3 v) {
    verts.add(v);
    return verts.length - 1;
  }
}

/// Normales lissées par sommet (moyenne des normales de facettes, pondérée
/// par l'aire). Sans elles, un cylindre reste une suite de facettes et la
/// manette garde un aspect « facetté » de dessin vectoriel.
List<V3> smoothNormals(List<V3> verts, List<Face> faces) {
  final out = List<V3>.filled(verts.length, V3.zero);
  for (final face in faces) {
    final ind = face.indices;
    if (ind.length < 3) continue;
    final a = verts[ind[0]];
    final b = verts[ind[1]];
    final c = verts[ind[2]];
    final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
    final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
    // Normale non normalisée : sa longueur vaut deux fois l'aire.
    final nx = uy * vz - uz * vy;
    final ny = uz * vx - ux * vz;
    final nz = ux * vy - uy * vx;
    for (final i in ind) {
      final v = out[i];
      out[i] = V3(v.x + nx, v.y + ny, v.z + nz);
    }
  }
  for (var i = 0; i < out.length; i++) {
    final v = out[i];
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    out[i] = len > 0.000001 ? V3(v.x / len, v.y / len, v.z / len) : const V3(0, 0, 1);
  }
  return out;
}

/// Lumière directionnelle fixe dans l'espace caméra.
const _light = V3(-0.45, -0.65, -0.62);

Color shade(Color base, V3 normal) {
  final n = normal.normalized;
  final lambert = math.max(0.0, n.dot(_light * -1));
  // 0,55 d'ambiante + 0,45 de diffus : jamais noir, jamais plat.
  final k = 0.55 + 0.45 * lambert;
  return Color.from(
    alpha: base.a,
    red: (base.r * k).clamp(0.0, 1.0),
    green: (base.g * k).clamp(0.0, 1.0),
    blue: (base.b * k).clamp(0.0, 1.0),
  );
}

/// Construit un prisme extrudé à partir d'un contour 2D (fermé, non croisé).
///
/// Le contour doit être donné dans le plan (x, y) ; l'extrusion se fait sur z
/// entre [zBack] et [zFront]. Utilisé pour le corps et les pièces plates.
Part extrude({
  required List<Offset> contour,
  required double zFront,
  required double zBack,
  required Color front,
  required Color side,
  required Color back,
  Color? sideBack,
  double? zMid,
  String? name,
  double scale = 1,
  bool smooth = true,
}) {
  final part = Part(name: name)..smooth = smooth;
  final n = contour.length;
  part.ringSize = n;

  // Faces avant / arrière (index dans l'ordre du contour).
  final frontStart = part.verts.length;
  for (final p in contour) {
    part.addVertex(V3(p.dx * scale, p.dy * scale, zFront));
  }
  int? midStart;
  if (zMid != null) {
    midStart = part.verts.length;
    for (final p in contour) {
      part.addVertex(V3(p.dx * scale, p.dy * scale, zMid));
      part.seam = part.seam.isEmpty
          ? [V3(p.dx * scale, p.dy * scale, zMid)]
          : [...part.seam, V3(p.dx * scale, p.dy * scale, zMid)];
    }
  }
  final backStart = part.verts.length;
  for (final p in contour) {
    part.addVertex(V3(p.dx * scale, p.dy * scale, zBack));
  }

  // La face avant est découpée en éventail depuis son centre : triée d'un
  // bloc, elle avait une profondeur moyenne et recouvrait les pièces du bas
  // (croix Xbox) lors d'une vue en plongée.
  final centerFront = part.addVertex(V3(
    contour.map((o) => o.dx).reduce((a, b) => a + b) / n * scale,
    contour.map((o) => o.dy).reduce((a, b) => a + b) / n * scale,
    zFront,
  ));
  for (var i = 0; i < n; i++) {
    part.faces.add(Face(
      [centerFront, frontStart + i, frontStart + (i + 1) % n],
      front,
      lit: false,
      layer: 2,
      flat: true,
    ));
  }
  final centerBack = part.addVertex(V3(
    contour.map((o) => o.dx).reduce((a, b) => a + b) / n * scale,
    contour.map((o) => o.dy).reduce((a, b) => a + b) / n * scale,
    zBack,
  ));
  for (var i = 0; i < n; i++) {
    part.faces.add(Face(
      [centerBack, backStart + (i + 1) % n, backStart + i],
      back,
      lit: false,
      layer: 0,
      flat: true,
    ));
  }

  // Si une arête médiane existe, le flanc est coupé en deux bandes : c'est la
  // ligne de joint entre la coque haute et la coque basse.
  final bands = midStart == null
      ? [(frontStart, backStart, side)]
      : [(frontStart, midStart, side), (midStart, backStart, sideBack ?? side)];
  for (final (loStart, hiStart, bandColor) in bands) {
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      part.faces.add(Face(
        [loStart + i, loStart + j, hiStart + j, hiStart + i],
        bandColor,
        lit: false,
      ));
    }
  }
  return part;
}

/// Cylindre vertical (sticks, boutons), avec sommet distinct.
Part cylinder({
  required Offset center,
  required double radius,
  required double zBase,
  required double height,
  required Color top,
  required Color side,
  int segments = 22,
  String? name,
  String? label,
  Color? labelColor,
  double labelScale = 1,
}) {
  final part = Part(name: name)..smooth = true;
  final base = part.verts.length;
  for (var i = 0; i < segments; i++) {
    final a = i * 2 * math.pi / segments;
    part.addVertex(V3(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius, zBase));
  }
  final topStart = part.verts.length;
  for (var i = 0; i < segments; i++) {
    final a = i * 2 * math.pi / segments;
    part.addVertex(
      V3(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius, zBase + height),
    );
  }
  part.faces.add(Face(
    [for (var i = 0; i < segments; i++) topStart + i],
    top,
    lit: false,
    layer: 2,
    flat: true,
  ));
  for (var i = 0; i < segments; i++) {
    final j = (i + 1) % segments;
    part.faces.add(Face(
      [base + i, base + j, topStart + j, topStart + i],
      side,
      lit: false,
    ));
  }
  if (label != null) {
    part.label = label;
    part.labelColor = labelColor ?? top;
    part.labelScale = labelScale;
  }
  return part;
}
