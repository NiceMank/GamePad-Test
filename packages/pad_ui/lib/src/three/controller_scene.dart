import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';

import 'scene.dart';
import 'vec.dart';

/// Palette « physique » d'un modèle de manette : ce sont les couleurs du
/// produit, pas celles de l'interface, pour que la 3D reste crédible.
class ShellPalette {
  const ShellPalette({
    required this.shell,
    required this.shellSide,
    required this.shellBack,
    required this.well,
    required this.stick,
    required this.stickTop,
    required this.button,
    required this.buttonTop,
    required this.accent,
    this.bumper,
    this.detail,
  });

  final Color shell;
  final Color shellSide;
  final Color shellBack;
  final Color well;
  final Color stick;
  final Color stickTop;
  final Color button;
  final Color buttonTop;
  final Color accent;
  final Color? bumper;

  /// Gris de commande (croix, boutons centraux) : contraste garanti avec la
  /// coque, claire comme sombre.
  final Color? detail;

  static ShellPalette of(ControllerFamily family, Brightness brightness) {
    final light = brightness == Brightness.light;
    switch (family) {
      case ControllerFamily.dualSense:
        return ShellPalette(
          shell: light ? const Color(0xFFEDEFF4) : const Color(0xFFE4E7EE),
          shellSide: light ? const Color(0xFFD3D8E2) : const Color(0xFFC6CBD7),
          shellBack: light ? const Color(0xFFE2E6ED) : const Color(0xFFD5DAE4),
          well: const Color(0xFFB9BFCB),
          stick: const Color(0xFF2A2E36),
          stickTop: const Color(0xFF3A3F49),
          button: const Color(0xFF3A3F49),
          buttonTop: const Color(0xFF4B515D),
          accent: const Color(0xFF35C7FF),
          detail: Color(0xFF6C727E),
        );
      case ControllerFamily.dualShock4:
        return const ShellPalette(
          shell: Color(0xFF2E323A),
          shellSide: Color(0xFF1E2128),
          shellBack: Color(0xFF25282F),
          well: Color(0xFF141619),
          stick: Color(0xFF131519),
          stickTop: Color(0xFF23262C),
          button: Color(0xFF3A3F4A),
          buttonTop: Color(0xFF4A505C),
          accent: Color(0xFF3B82F6),
        );
      case ControllerFamily.dualShock3:
        return const ShellPalette(
          shell: Color(0xFF3A3D45),
          shellSide: Color(0xFF262930),
          shellBack: Color(0xFF2D3037),
          well: Color(0xFF191B21),
          stick: Color(0xFF1B1D22),
          stickTop: Color(0xFF2A2E36),
          button: Color(0xFF454B57),
          buttonTop: Color(0xFF565D6B),
          accent: Color(0xFF60A5FA),
        );
      case ControllerFamily.xboxSeries:
      case ControllerFamily.xboxOne:
      case ControllerFamily.xbox360:
        return const ShellPalette(
          shell: Color(0xFF26292F),
          shellSide: Color(0xFF15171B),
          shellBack: Color(0xFF1D2025),
          well: Color(0xFF101215),
          stick: Color(0xFF121417),
          stickTop: Color(0xFF2A2E35),
          button: Color(0xFF2B2F37),
          buttonTop: Color(0xFF3A3F49),
          accent: Color(0xFF52E39B),
          detail: Color(0xFF585F6A),
        );
      case ControllerFamily.switchPro:
        return const ShellPalette(
          shell: Color(0xFF3C414A),
          shellSide: Color(0xFF262A31),
          shellBack: Color(0xFF30343C),
          well: Color(0xFF1A1D22),
          stick: Color(0xFF1E2126),
          stickTop: Color(0xFF33373F),
          button: Color(0xFF3B4048),
          buttonTop: Color(0xFF4C525C),
          accent: Color(0xFFFF5A6E),
          detail: Color(0xFF69707C),
        );
      case ControllerFamily.joyCon:
        return const ShellPalette(
          shell: Color(0xFFFF6D8A),
          shellSide: Color(0xFFD14561),
          shellBack: Color(0xFFE85C79),
          well: Color(0xFFB93A55),
          stick: Color(0xFF2A2D33),
          stickTop: Color(0xFF3A3E46),
          button: Color(0xFF2F333A),
          buttonTop: Color(0xFF474D57),
          accent: Color(0xFF3AC7F0),
        );
      case ControllerFamily.steamDeck:
        return const ShellPalette(
          shell: Color(0xFF30343B),
          shellSide: Color(0xFF1C1F24),
          shellBack: Color(0xFF262A30),
          well: Color(0xFF14171B),
          stick: Color(0xFF131519),
          stickTop: Color(0xFF2A2E35),
          button: Color(0xFF3A3F47),
          buttonTop: Color(0xFF4A5059),
          accent: Color(0xFF7B8CFF),
        );
      case ControllerFamily.generic:
        return ShellPalette(
          shell: light ? const Color(0xFFE9EBEF) : const Color(0xFF34383F),
          shellSide: light ? const Color(0xFFC9CDD5) : const Color(0xFF1F2227),
          shellBack: light ? const Color(0xFFDDE0E6) : const Color(0xFF292C32),
          well: light ? const Color(0xFFB4B9C2) : const Color(0xFF17191E),
          stick: const Color(0xFF2A2D33),
          stickTop: const Color(0xFF3B3F47),
          button: const Color(0xFF3A3F49),
          buttonTop: const Color(0xFF4B515D),
          accent: const Color(0xFF5AC8FA),
          detail: Color(0xFF69707C),
        );
    }
  }
}

/// Positions propres à une famille : c'est ce qui rend le modèle
/// reconnaissable (sticks décalés sur Xbox, symétriques sur PlayStation…).
class _Layout {
  const _Layout({
    required this.leftStick,
    required this.rightStick,
    required this.dpad,
    required this.face,
    required this.symmetric,
  });

  final Offset leftStick;
  final Offset rightStick;
  final Offset dpad;
  final Offset face;

  /// Vrai quand croix et boutons sont alignés en haut (PlayStation,
  /// Switch), faux quand la croix descend sous le stick gauche (Xbox).
  final bool symmetric;

  static _Layout of(ControllerFamily family) {
    switch (family) {
      case ControllerFamily.xboxSeries:
      case ControllerFamily.xboxOne:
      case ControllerFamily.xbox360:
        return const _Layout(
          leftStick: Offset(-0.372, 0.103),
          rightStick: Offset(0.238, -0.238),
          dpad: Offset(-0.372, -0.238),
          face: Offset(0.372, 0.103),
          symmetric: false,
        );
      case ControllerFamily.switchPro:
        return const _Layout(
          leftStick: Offset(-0.312, -0.192),
          rightStick: Offset(0.312, -0.192),
          dpad: Offset(-0.596, 0.070),
          face: Offset(0.596, 0.070),
          symmetric: true,
        );
      case ControllerFamily.steamDeck:
        return const _Layout(
          leftStick: Offset(-0.352, 0.096),
          rightStick: Offset(0.352, 0.096),
          dpad: Offset(-0.612, -0.302),
          face: Offset(0.612, -0.302),
          symmetric: true,
        );
      default:
        return const _Layout(
          leftStick: Offset(-0.276, -0.170),
          rightStick: Offset(0.276, -0.170),
          dpad: Offset(-0.566, 0.064),
          face: Offset(0.566, 0.064),
          symmetric: true,
        );
    }
  }
}

/// Contour du boîtier, moitié droite puis miroir.
///
/// Les épaules montent doucement vers les ailes, les poignées descendent en
/// s'écartant, et l'arc central entre les deux poignées remonte haut : c'est
/// ce creux qui distingue une manette d'une simple « savonnette ».
List<Offset> _outline(ControllerFamily family) {
  final (width, grip, rise, spread) = switch (family) {
    ControllerFamily.xboxSeries ||
    ControllerFamily.xboxOne ||
    ControllerFamily.xbox360 =>
      (1.00, 1.02, 1.03, 1.05),
    ControllerFamily.switchPro => (0.94, 0.90, 0.97, 0.95),
    ControllerFamily.joyCon => (0.88, 0.86, 0.96, 0.90),
    ControllerFamily.steamDeck => (1.12, 1.04, 1.06, 1.10),
    _ => (1.0, 1.0, 1.0, 1.0),
  };

  final half = <Offset>[
    // Bord supérieur, du centre vers l'aile droite.
    Offset(0.000, 0.246 * rise),
    Offset(0.090 * spread, 0.252 * rise),
    Offset(0.200 * spread, 0.258 * rise),
    Offset(0.335 * spread, 0.266 * rise),
    Offset(0.470 * spread, 0.272 * rise),
    Offset(0.600 * spread, 0.272 * rise),
    Offset(0.715 * spread, 0.258 * rise),
    Offset(0.828 * spread, 0.219 * rise),
    Offset(0.906 * width, 0.131),
    Offset(0.955 * width, 0.010),
    Offset(0.980 * width, -0.140),
    Offset(0.975 * width, -0.300),
    Offset(0.952 * width, -0.455 * grip),
    // Poignée : elle s'écarte en descendant, puis s'arrondit.
    Offset(0.918 * width, -0.605 * grip),
    Offset(0.862 * width, -0.745 * grip),
    Offset(0.792 * width, -0.850 * grip),
    Offset(0.712 * width, -0.918 * grip),
    Offset(0.632 * width, -0.944 * grip),
    Offset(0.559 * width, -0.914 * grip),
    Offset(0.512 * width, -0.844 * grip),
    Offset(0.484 * width, -0.738 * grip),
    Offset(0.468 * width, -0.648 * grip),
    // Arc central entre les poignées.
    Offset(0.442 * width, -0.592 * grip),
    Offset(0.406 * width, -0.548 * grip),
    Offset(0.354 * width, -0.514 * grip),
    Offset(0.282 * width, -0.490 * grip),
    Offset(0.182 * width, -0.476 * grip),
    Offset(0.078 * width, -0.470 * grip),
    Offset(0.000, -0.468 * grip),
  ];

  // Le miroir se fait sur les points de contrôle, puis on lisse la boucle
  // complète : lisser chaque moitié séparément créait une couture au centre.
  final loop = [
    ...half,
    for (var i = half.length - 2; i > 0; i--) Offset(-half[i].dx, half[i].dy),
  ];
  return _smooth(loop, 8);
}

/// Lissage Catmull-Rom : le contour reste organique sans être bruité.
List<Offset> _smooth(List<Offset> pts, int samples) {
  final out = <Offset>[];
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    for (var s = 0; s < samples; s++) {
      final t = s / samples;
      final t2 = t * t;
      final t3 = t2 * t;
      out.add(Offset(
        0.5 * (2 * p1.dx + (-p0.dx + p2.dx) * t + (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 + (-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3),
        0.5 * (2 * p1.dy + (-p0.dy + p2.dy) * t + (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 + (-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3),
      ));
    }
  }
  return out;
}

List<Offset> _roundedRect(double cx, double cy, double w, double h, double r) {
  final hw = w / 2, hh = h / 2;
  final rr = math.min(r, math.min(hw, hh));
  final pts = <Offset>[];
  void arc(double ox, double oy, double start, double end) {
    for (var i = 0; i <= 4; i++) {
      final a = start + (end - start) * i / 4;
      pts.add(Offset(cx + ox + math.cos(a) * rr, cy + oy + math.sin(a) * rr));
    }
  }

  arc(hw - rr, hh - rr, 0, math.pi / 2);
  arc(-(hw - rr), hh - rr, math.pi / 2, math.pi);
  arc(-(hw - rr), -(hh - rr), math.pi, 3 * math.pi / 2);
  arc(hw - rr, -(hh - rr), 3 * math.pi / 2, 2 * math.pi);
  return pts;
}

/// Croix directionnelle : quatre branches chanfreinées, pas une croix
/// « plate » aux angles droits.
List<Offset> _cross(double cx, double cy, double arm, double thick) {
  const c = 0.016; // chanfrein
  return [
    Offset(cx - thick + c, cy + arm),
    Offset(cx + thick - c, cy + arm),
    Offset(cx + thick, cy + arm - c),
    Offset(cx + thick, cy + thick),
    Offset(cx + arm - c, cy + thick),
    Offset(cx + arm, cy + thick - c),
    Offset(cx + arm, cy - thick + c),
    Offset(cx + arm - c, cy - thick),
    Offset(cx + thick, cy - thick),
    Offset(cx + thick, cy - arm + c),
    Offset(cx + thick - c, cy - arm),
    Offset(cx - thick + c, cy - arm),
    Offset(cx - thick, cy - arm + c),
    Offset(cx - thick, cy - thick),
    Offset(cx - arm + c, cy - thick),
    Offset(cx - arm, cy - thick + c),
    Offset(cx - arm, cy + thick - c),
    Offset(cx - arm + c, cy + thick),
    Offset(cx - thick, cy + thick),
    Offset(cx - thick, cy + arm - c),
  ];
}

/// Scène complète : corps, sticks, boutons, gâchettes, détails.
class ControllerScene {
  ControllerScene({required this.parts, required this.buttons});

  final List<Part> parts;

  /// Boutons cliquables : nom logique + centre monde + rayon.
  final List<({PadButton button, V3 center, double radius})> buttons;

  static const double thickness = 0.100;
  static const double front = thickness;

  static ControllerScene build(ControllerFamily family, Brightness brightness) {
    final p = ShellPalette.of(family, brightness);
    final layout = _Layout.of(family);
    final outline = _outline(family);
    final parts = <Part>[];
    final buttons = <({PadButton button, V3 center, double radius})>[];

    // --- coque -------------------------------------------------------------
    // L'arête médiane sépare la coque haute (claire) de la coque basse : un
    // vrai boîtier de manette a toujours ce plan de joint.
    final shell = extrude(
      contour: outline,
      zFront: front,
      zMid: 0,
      zBack: -thickness,
      front: p.shell,
      side: p.shellSide,
      sideBack: Color.lerp(p.shellBack, Colors.black, 0.10),
      back: p.shellBack,
      name: 'corps',
    );
    shell.role = 'shell';
    parts.add(shell);

    // --- épaules et gâchettes ----------------------------------------------
    // Une épaule n'est pas un bloc posé sur le dessus : c'est une bande qui
    // vient coiffer l'arête de la coque. On la construit donc à partir du
    // contour du boîtier, décalé vers l'extérieur.
    List<Offset> shoulderBand(double sign, double grow, double fromX) {
      final pivot = Offset(sign * 0.40, 0.02);
      final inner = [
        for (final q in outline)
          if (q.dx * sign > fromX && q.dx * sign < 0.90 && q.dy > -0.03) q,
      ];
      // L'épaisseur s'annule aux deux extrémités : l'épaule se fond dans la
      // coque au lieu de s'arrêter sur une arête franche.
      final n = inner.length;
      final outer = <Offset>[];
      for (var i = 0; i < n; i++) {
        final t = n == 1 ? 0.0 : i / (n - 1);
        final taper =
            (0.30 + 0.70 * math.sin(math.pi * t)).clamp(0.30, 1.0);
        final v = inner[i] - pivot;
        final d = v.distance == 0 ? 1.0 : v.distance;
        outer.add(pivot + v * ((d + grow * taper) / d));
      }
      return [...inner, ...outer.reversed];
    }

    final hasTriggers = family != ControllerFamily.joyCon;
    for (final (sign, bumper, trigger) in [
      (-1.0, PadButton.l1, PadButton.l2),
      (1.0, PadButton.r1, PadButton.r2),
    ]) {
      if (hasTriggers) {
        final triggerPart = extrude(
          contour: shoulderBand(sign, 0.042, 0.46),
          zFront: -0.012,
          zBack: -0.082,
          front: Color.lerp(p.button, Colors.black, 0.18)!,
          side: Color.lerp(p.button, Colors.black, 0.30)!,
          sideBack: Color.lerp(p.button, Colors.black, 0.42)!,
          back: p.shellBack,
          name: 'gâchette',
        );
        triggerPart
          ..button = trigger
          ..glow = 0.34;
        parts.add(triggerPart);
        buttons.add((
          button: trigger,
          center: V3(sign * 0.66, 0.34, -0.10),
          radius: 0.105,
        ));
      }

      final bumperPart = extrude(
        contour: shoulderBand(sign, 0.036, 0.33),
        zFront: front + 0.020,
        zBack: -0.070,
        front: p.bumper ?? p.buttonTop,
        side: p.button,
        sideBack: Color.lerp(p.button, Colors.black, 0.25),
        back: p.button,
        name: 'épaule',
      );
      bumperPart
        ..button = bumper
        ..glow = 0.34;
      parts.add(bumperPart);
      buttons.add((
        button: bumper,
        center: V3(sign * 0.68, 0.30, front + 0.030),
        radius: 0.095,
      ));
    }

    // --- sticks ------------------------------------------------------------
    void addStick(Offset center, String name, PadButton click) {
      // 1. Lunette d'assise : un anneau clair qui « reçoit » le stick.
      parts.add(cylinder(
        center: center,
        radius: 0.150,
        zBase: front + 0.004,
        height: 0.004,
        top: Color.lerp(p.shell, p.shellSide, 0.55)!,
        side: p.shellSide,
        segments: 34,
        name: 'assise',
      ));
      // 2. Creux sombre : lecture immédiate d'un puits.
      parts.add(cylinder(
        center: center,
        radius: 0.138,
        zBase: front + 0.007,
        height: 0.006,
        top: p.well,
        side: p.well,
        segments: 34,
        name: 'puits',
      ));
      // 3. Fût fin : la tige est bien plus étroite que le capuchon.
      parts.add(cylinder(
        center: center,
        radius: 0.064,
        zBase: front + 0.008,
        height: 0.086,
        top: p.stick,
        side: Color.lerp(p.stick, Colors.black, 0.25)!,
        segments: 20,
        name: 'fût',
      ));
      // 4. Capuchon bombé.
      final cap = cylinder(
        center: center,
        radius: 0.113,
        zBase: front + 0.082,
        height: 0.050,
        top: p.stickTop,
        side: p.stick,
        segments: 34,
        name: name,
      );
      cap.capCenter = center;
      cap.capRadius = 0.113;
      cap.capZ = front + 0.132;
      cap.button = click;
      parts.add(cap);
      // 5. Rebord du capuchon + creux central (la surface est concave).
      parts.add(cylinder(
        center: center,
        radius: 0.094,
        zBase: front + 0.132,
        height: 0.003,
        top: Color.lerp(p.stickTop, Colors.white, 0.10)!,
        side: p.stick,
        segments: 30,
        name: 'rebord',
      ));
      parts.add(cylinder(
        center: center,
        radius: 0.068,
        zBase: front + 0.134,
        height: 0.002,
        top: Color.lerp(p.stick, Colors.black, 0.18)!,
        side: p.stick,
        segments: 26,
        name: 'creux',
      ));
      buttons.add((
        button: click,
        center: V3(center.dx, center.dy, front + 0.140),
        radius: 0.150,
      ));
    }

    addStick(layout.leftStick, 'LS', PadButton.l3);
    addStick(layout.rightStick, 'RS', PadButton.r3);

    // --- croix directionnelle ----------------------------------------------
    final plate = _roundedRect(
      layout.dpad.dx,
      layout.dpad.dy,
      0.340,
      0.340,
      0.076,
    );
    parts.add(extrude(
      contour: plate,
      zFront: front + 0.002,
      zBack: front - 0.001,
      front: Color.lerp(p.shell, p.well, 0.16)!,
      side: p.shellSide,
      back: p.well,
      name: 'assise-croix',
    ));
    final dpadPart = extrude(
      contour: _cross(layout.dpad.dx, layout.dpad.dy, 0.140, 0.052),
      zFront: front + 0.034,
      zBack: front + 0.004,
      front: p.detail ?? p.stickTop,
      side: Color.lerp(p.detail ?? p.stickTop, Colors.black, 0.45)!,
      back: p.stick,
      name: 'croix',
    );
    dpadPart
      ..buttons = const [
        PadButton.dpadUp,
        PadButton.dpadDown,
        PadButton.dpadLeft,
        PadButton.dpadRight,
      ]
      ..glow = 0.38;
    parts.add(dpadPart);
    parts.add(cylinder(
      center: layout.dpad,
      radius: 0.050,
      zBase: front + 0.034,
      height: 0.003,
      top: Color.lerp(p.detail ?? p.stickTop, Colors.black, 0.32)!,
      side: p.stick,
      segments: 22,
      name: 'pivot',
    ));
    for (final (dx, dy, btn) in [
      (0.0, 1.0, PadButton.dpadUp),
      (0.0, -1.0, PadButton.dpadDown),
      (-1.0, 0.0, PadButton.dpadLeft),
      (1.0, 0.0, PadButton.dpadRight),
    ]) {
      buttons.add((
        button: btn,
        center: V3(
          layout.dpad.dx + dx * 0.108,
          layout.dpad.dy + dy * 0.108,
          front + 0.040,
        ),
        radius: 0.072,
      ));
    }

    // --- boutons de façade -------------------------------------------------
    final diamond = layout.symmetric ? 0.104 : 0.098;
    const faceButtons = [
      (PadButton.y, 0.0, 1.0),
      (PadButton.a, 0.0, -1.0),
      (PadButton.x, -1.0, 0.0),
      (PadButton.b, 1.0, 0.0),
    ];
    for (final (btn, dx, dy) in faceButtons) {
      final c = Offset(
        layout.face.dx + dx * diamond,
        layout.face.dy + dy * diamond,
      );
      // Cuvette sombre autour du bouton : le bouton est en creux, pas collé.
      parts.add(cylinder(
        center: c,
        radius: 0.072,
        zBase: front + 0.001,
        height: 0.003,
        top: Color.lerp(p.shell, p.well, 0.42)!,
        side: p.shellSide,
        segments: 22,
        name: 'cuvette-bouton',
      ));
      final faceButton = cylinder(
        center: c,
        radius: 0.056,
        zBase: front + 0.004,
        height: 0.030,
        top: _buttonFace(btn, family, p),
        side: Color.lerp(_buttonFace(btn, family, p), Colors.black, 0.35)!,
        segments: 26,
        name: 'face-$btn',
      );
      faceButton.button = btn;
      if (family.isPlayStation) {
        faceButton.glyph = switch (btn) {
          PadButton.a => PadGlyph.cross,
          PadButton.b => PadGlyph.circle,
          PadButton.x => PadGlyph.square,
          _ => PadGlyph.triangle,
        };
        faceButton.glyphColor = _glyphColor(btn, family);
      } else {
        faceButton.label = btn.glyph(family.layout);
        faceButton.labelColor = _glyphColor(btn, family);
        faceButton.labelScale = 0.92;
      }
      parts.add(faceButton);
      buttons.add((
        button: btn,
        center: V3(c.dx, c.dy, front + 0.040),
        radius: 0.080,
      ));
    }

    // --- pavé tactile / boutons centraux ------------------------------------
    if (family.isPlayStation) {
      const padY = 0.138;
      const padH = 0.186;
      const padW = 0.448;
      parts.add(extrude(
        contour: _roundedRect(0.0, padY, padW, padH, 0.042),
        zFront: front + 0.016,
        zBack: front + 0.001,
        front: Color.lerp(p.shell, p.shellSide, 0.55)!,
        side: p.shellSide,
        back: p.shellSide,
        name: 'touchpad',
      ));
      // Liseré lumineux qui encadre le pavé (light bar DualSense).
      for (final (cx, cy, w, h) in [
        (0.0, padY + padH / 2 + 0.010, padW + 0.030, 0.014),
        (-(padW / 2 + 0.014), padY, 0.014, padH + 0.016),
        (padW / 2 + 0.014, padY, 0.014, padH + 0.016),
      ]) {
        parts.add(extrude(
          contour: _roundedRect(cx, cy, w, h, 0.010),
          zFront: front + 0.012,
          zBack: front + 0.004,
          front: p.accent,
          side: p.accent,
          back: p.accent,
          name: 'lightbar',
        ));
      }
      final tp = parts.firstWhere((x) => x.name == 'touchpad');
      tp
        ..button = PadButton.touchpad
        ..glow = 0.26;
      buttons.add((
        button: PadButton.touchpad,
        center: V3(0, padY, front + 0.024),
        radius: 0.215,
      ));

      // Bouton PS entre les sticks, bouton muet sous le pavé.
      final guide = cylinder(
        center: const Offset(0.0, -0.006),
        radius: 0.046,
        zBase: front + 0.002,
        height: 0.016,
        top: p.detail ?? p.buttonTop,
        side: p.button,
        segments: 20,
        name: 'guide',
      );
      guide.button = PadButton.guide;
      parts.add(guide);
      parts.add(extrude(
        contour: _roundedRect(0.0, 0.036, 0.104, 0.019, 0.008),
        zFront: front + 0.006,
        zBack: front + 0.001,
        front: p.detail ?? p.buttonTop,
        side: p.button,
        back: p.button,
        name: 'muet',
      ));
      buttons.add((
        button: PadButton.guide,
        center: const V3(0, -0.006, front + 0.022),
        radius: 0.050,
      ));
    } else {
      final guide = cylinder(
        center: const Offset(0.0, 0.226),
        radius: 0.048,
        zBase: front,
        height: 0.026,
        top: p.detail ?? p.buttonTop,
        side: p.button,
        segments: 20,
        name: 'guide',
      );
      guide.button = PadButton.guide;
      parts.add(guide);
      for (final (cx, btn, name) in [
        (-0.170, PadButton.select, 'select'),
        (0.170, PadButton.start, 'start'),
      ]) {
        final part = cylinder(
          center: Offset(cx, 0.226),
          radius: 0.040,
          zBase: front,
          height: 0.022,
          top: p.detail ?? p.buttonTop,
          side: p.button,
          segments: 18,
          name: name,
        );
        part.button = btn;
        parts.add(part);
        buttons.add((
          button: btn,
          center: V3(cx, 0.226, front + 0.030),
          radius: 0.046,
        ));
      }
      buttons.add((
        button: PadButton.guide,
        center: const V3(0, 0.226, front + 0.034),
        radius: 0.052,
      ));
    }

    // --- dos -----------------------------------------------------------------
    // Trappe à batterie et vis : la face arrière existe vraiment, autant
    // qu'elle ait de quoi se lire quand on fait un tour complet.
    final backZ = -thickness - 0.004;
    parts.add(extrude(
      contour: _roundedRect(0.0, -0.150, 0.560, 0.300, 0.070),
      zFront: -thickness,
      zBack: backZ,
      front: Color.lerp(p.shellBack, Colors.black, 0.05)!,
      side: Color.lerp(p.shellBack, Colors.black, 0.18)!,
      back: Color.lerp(p.shellBack, Colors.black, 0.10)!,
      name: 'trappe',
    ));
    return ControllerScene(parts: parts, buttons: buttons);
  }

  /// Couleur du capuchon d'un bouton de façade.
  static Color _buttonFace(PadButton button, ControllerFamily family, ShellPalette p) {
    if (family.isXbox) {
      return switch (button) {
        PadButton.a => const Color(0xFF2E7D4F),
        PadButton.b => const Color(0xFF9B2C33),
        PadButton.x => const Color(0xFF22508F),
        _ => const Color(0xFF9A7A17),
      };
    }
    if (family.isPlayStation) {
      // Capuchons gris translucides, symboles colorés.
      return const Color(0xFF3D434E);
    }
    return p.buttonTop;
  }

  static Color _glyphColor(PadButton button, ControllerFamily family) {
    if (family.isPlayStation) {
      return switch (button) {
        PadButton.a => const Color(0xFF6EA8FF), // croix
        PadButton.b => const Color(0xFFFF6B7A), // rond
        PadButton.x => const Color(0xFFE58BE6), // carré
        PadButton.y => const Color(0xFF63E6B6), // triangle
        _ => const Color(0xFFE9EDF5),
      };
    }
    if (family.isXbox) {
      return switch (button) {
        PadButton.a => const Color(0xFFB8F5CE),
        PadButton.b => const Color(0xFFFFC2C2),
        PadButton.x => const Color(0xFFBED9FF),
        PadButton.y => const Color(0xFFFFE9A6),
        _ => const Color(0xFFE9EDF5),
      };
    }
    return const Color(0xFFEDF1F8);
  }
}
