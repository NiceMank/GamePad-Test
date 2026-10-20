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
      // DualSense : plastique clair deux tons, sticks et boutons graphite.
      case ControllerFamily.dualSense:
        return ShellPalette(
          shell: light ? const Color(0xFFEAEBE8) : const Color(0xFFE3E4E1),
          shellSide: light ? const Color(0xFFC8CAC6) : const Color(0xFFBFc1BD),
          shellBack: light ? const Color(0xFFDEDFDB) : const Color(0xFFD6D7D3),
          well: const Color(0xFFA8ABA7),
          stick: const Color(0xFF232428),
          stickTop: const Color(0xFF35363B),
          button: const Color(0xFF2B2D31),
          buttonTop: const Color(0xFF3B3D42),
          accent: const Color(0xFFC8D8E4),
          detail: const Color(0xFF6B6E73),
        );
      // DualShock 4 / 3 : noir mat, plastique plus profond que la DualSense.
      case ControllerFamily.dualShock4:
        return const ShellPalette(
          shell: Color(0xFF26282C),
          shellSide: Color(0xFF17181B),
          shellBack: Color(0xFF1E2024),
          well: Color(0xFF111214),
          stick: Color(0xFF131417),
          stickTop: Color(0xFF24262A),
          button: Color(0xFF34363C),
          buttonTop: Color(0xFF43454B),
          accent: Color(0xFFB9C6D2),
          detail: Color(0xFF5F646B),
        );
      case ControllerFamily.dualShock3:
        return const ShellPalette(
          shell: Color(0xFF32353A),
          shellSide: Color(0xFF212328),
          shellBack: Color(0xFF282A2F),
          well: Color(0xFF16181B),
          stick: Color(0xFF1B1D21),
          stickTop: Color(0xFF2A2C31),
          button: Color(0xFF3E4147),
          buttonTop: Color(0xFF4E5158),
          accent: Color(0xFFB9C6D2),
          detail: Color(0xFF646A72),
        );
      // Xbox : noir carbone, légèrement bleuté.
      case ControllerFamily.xboxSeries:
      case ControllerFamily.xboxOne:
      case ControllerFamily.xbox360:
        return const ShellPalette(
          shell: Color(0xFF212226),
          shellSide: Color(0xFF131417),
          shellBack: Color(0xFF1A1B1F),
          well: Color(0xFF0F1012),
          stick: Color(0xFF121316),
          stickTop: Color(0xFF26282C),
          button: Color(0xFF2A2C31),
          buttonTop: Color(0xFF383A40),
          accent: Color(0xFFDADDE1),
          detail: Color(0xFF575C63),
        );
      case ControllerFamily.switchPro:
        return const ShellPalette(
          shell: Color(0xFF35373C),
          shellSide: Color(0xFF232529),
          shellBack: Color(0xFF2B2D32),
          well: Color(0xFF181A1D),
          stick: Color(0xFF1D1F23),
          stickTop: Color(0xFF313338),
          button: Color(0xFF3A3C42),
          buttonTop: Color(0xFF4A4C53),
          accent: Color(0xFFD6D9DD),
          detail: Color(0xFF666C74),
        );
      case ControllerFamily.joyCon:
        // Rouge et bleu Nintendo, version satinée plutôt que fluo.
        return const ShellPalette(
          shell: Color(0xFFC8453F),
          shellSide: Color(0xFF9E332F),
          shellBack: Color(0xFFB63D38),
          well: Color(0xFF8A2C29),
          stick: Color(0xFF2A2C31),
          stickTop: Color(0xFF3A3D43),
          button: Color(0xFF2F3136),
          buttonTop: Color(0xFF46484F),
          accent: Color(0xFFCBD6DF),
          detail: Color(0xFF6E747C),
        );
      case ControllerFamily.steamDeck:
        return const ShellPalette(
          shell: Color(0xFF2C2E33),
          shellSide: Color(0xFF1A1C20),
          shellBack: Color(0xFF232529),
          well: Color(0xFF131519),
          stick: Color(0xFF121417),
          stickTop: Color(0xFF25272C),
          button: Color(0xFF36383E),
          buttonTop: Color(0xFF464850),
          accent: Color(0xFFBFC9D4),
          detail: Color(0xFF666C74),
        );
      case ControllerFamily.generic:
        return ShellPalette(
          shell: light ? const Color(0xFFE6E7E3) : const Color(0xFF2E3035),
          shellSide: light ? const Color(0xFFC5C7C2) : const Color(0xFF1C1E22),
          shellBack: light ? const Color(0xFFD9DAD5) : const Color(0xFF26282D),
          well: light ? const Color(0xFFAFB2AD) : const Color(0xFF15171A),
          stick: const Color(0xFF26282C),
          stickTop: const Color(0xFF373A40),
          button: const Color(0xFF34363B),
          buttonTop: const Color(0xFF45474D),
          accent: const Color(0xFFC6D2DD),
          detail: const Color(0xFF666C74),
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
          leftStick: Offset(-0.268, 0.114),
          rightStick: Offset(0.268, 0.114),
          dpad: Offset(-0.418, -0.246),
          face: Offset(0.418, -0.246),
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

/// Bandeau central du DualSense : la coque est claire, mais la zone des
/// sticks et du pavé est noire. C'est ce contraste qui rend la manette
/// reconnaissable au premier coup d'œil.
List<Offset> _centrePanel() {
  final half = <Offset>[
    // Bord supérieur : le noir touche la tranche de la coque, comme sur la
    // vraie DualSense où le bandeau forme la visière entre les épaules.
    Offset(0.000, 0.248),
    Offset(0.250, 0.246),
    Offset(0.330, 0.232),
    Offset(0.378, 0.176),
    Offset(0.400, 0.090),
    Offset(0.412, -0.040),
    Offset(0.404, -0.190),
    Offset(0.340, -0.310),
    Offset(0.186, -0.362),
    Offset(0.000, -0.372),
  ];
  final loop = [
    ...half,
    for (var i = half.length - 2; i > 0; i--) Offset(-half[i].dx, half[i].dy),
  ];
  return _smooth(loop, 4);
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

  static const double thickness = 0.150;
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
      smooth: false,
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
      // Sur PlayStation, les sticks sont posés dans le bandeau noir : leur
      // lunette est sombre, pas claire comme sur une manette Xbox.
      final seat = family.isPlayStation
          ? Color.lerp(p.well, Colors.black, 0.35)!
          : Color.lerp(p.shell, p.shellSide, 0.55)!;
      // 1. Lunette d'assise : un anneau qui « reçoit » le stick.
      parts.add(cylinder(
        center: center,
        radius: 0.150,
        zBase: front + 0.004,
        height: 0.004,
        top: seat,
        side: p.shellSide,
        segments: 24,
        name: 'assise',
      ));
      // 2. Creux sombre : lecture immédiate d'un puits.
      parts.add(cylinder(
        center: center,
        radius: 0.138,
        zBase: front + 0.007,
        height: 0.006,
        top: family.isPlayStation ? const Color(0xFF15161A) : p.well,
        side: p.well,
        segments: 24,
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
        segments: 16,
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
        segments: 24,
        name: name,
      );
      cap.capCenter = center;
      cap.capRadius = 0.113;
      cap.capZ = front + 0.132;
      cap.button = click;
      parts.add(cap);
      // 5. Creux central : la surface du capuchon est concave.
      parts.add(cylinder(
        center: center,
        radius: 0.068,
        zBase: front + 0.134,
        height: 0.002,
        top: Color.lerp(p.stick, Colors.black, 0.18)!,
        side: p.stick,
        segments: 16,
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
    final dpadPart = extrude(
      contour: _cross(layout.dpad.dx, layout.dpad.dy, 0.140, 0.052),
      zFront: front + 0.034,
      zBack: front + 0.004,
      front: const Color(0xFF4A4C51),
      side: const Color(0xFF2E3034),
      back: const Color(0xFF26282C),
      name: 'croix',
      smooth: false,
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
      segments: 12,
      name: 'pivot',
    ));
    // Flèches des branches : de petits repères, comme sur le vrai pad.
    for (final (ax, ay) in [(0.0, 1.0), (0.0, -1.0), (-1.0, 0.0), (1.0, 0.0)]) {
      final tip = Offset(
        layout.dpad.dx + ax * 0.086,
        layout.dpad.dy + ay * 0.086,
      );
      parts.add(cylinder(
        center: tip,
        radius: 0.016,
        zBase: front + 0.034,
        height: 0.002,
        top: const Color(0xFFC9CCCF),
        side: const Color(0xFF9A9DA0),
        segments: 8,
        name: 'repère',
      ));
    }
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
      // Elle affleure la coque (0,004 sous la surface) pour ne pas dépasser
      // sur la silhouette quand on regarde de biais.
      parts.add(cylinder(
        center: c,
        radius: 0.068,
        zBase: front - 0.004,
        height: 0.003,
        top: family.isPlayStation
            ? const Color(0xFF141518)
            : Color.lerp(p.shell, p.well, 0.42)!,
        side: p.shellSide,
        segments: 16,
        name: 'cuvette-bouton',
      ));
      final faceButton = cylinder(
        center: c,
        radius: 0.056,
        zBase: front + 0.004,
        height: 0.030,
        top: _buttonFace(btn, family, p),
        side: Color.lerp(_buttonFace(btn, family, p), Colors.black, 0.35)!,
        segments: 20,
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
      // Plaque noire centrale : elle passe avant le pavé et les sticks.
      final centre = extrude(
        contour: _centrePanel(),
        zFront: front + 0.003,
        zBack: front - 0.004,
        front: const Color(0xFF1B1C1F),
        side: const Color(0xFF141518),
        back: const Color(0xFF17181B),
        name: 'bandeau',
        smooth: false,
      );
      parts.insert(parts.length - 1, centre);

      const padY = 0.138;
      const padH = 0.186;
      const padW = 0.448;
      parts.add(extrude(
        contour: _roundedRect(0.0, padY, padW, padH, 0.042),
        zFront: front + 0.016,
        zBack: front + 0.001,
        front: p.shell,
        side: Color.lerp(p.shell, Colors.black, 0.35)!,
        back: p.shellSide,
        name: 'touchpad',
        smooth: false,
      ));

      // Grille du haut-parleur : quatre fentes sous le pavé, comme sur la
      // DualSense.
      for (var i = -2; i <= 2; i++) {
        parts.add(extrude(
          contour: _roundedRect(i * 0.026, 0.006, 0.014, 0.004, 0.002),
          zFront: front + 0.004,
          zBack: front + 0.001,
          front: const Color(0xFF2A2B2F),
          side: const Color(0xFF1E1F23),
          back: const Color(0xFF232427),
          name: 'grille',
        smooth: false,
        ));
      }
      // Le liseré lumineux est tracé par le painter (trait), pas par des
      // barres extrudées : trois rectangles semblaient posés sur le pavé.

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
        segments: 16,
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
        smooth: false,
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
        segments: 16,
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
          segments: 12,
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
      // Vert, brique, bleu et laiton : les quatre teintes du vrai pad, en
      // version mate.
      return switch (button) {
        PadButton.a => const Color(0xFF4F7C5E),
        PadButton.b => const Color(0xFF8E4E4A),
        PadButton.x => const Color(0xFF40618C),
        _ => const Color(0xFFA88A45),
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
        PadButton.a => const Color(0xFF7E97B8), // croix
        PadButton.b => const Color(0xFFB4797C), // rond
        PadButton.x => const Color(0xFFAE8BAA), // carré
        PadButton.y => const Color(0xFF7FA790), // triangle
        _ => const Color(0xFFE4E6E9),
      };
    }
    if (family.isXbox) {
      // Lettres claires, discrètes sur les capuchons colorés.
      return switch (button) {
        PadButton.a => const Color(0xFFDCE8DF),
        PadButton.b => const Color(0xFFE8D9D7),
        PadButton.x => const Color(0xFFD8E0EA),
        PadButton.y => const Color(0xFFE8E2D2),
        _ => const Color(0xFFE4E6E9),
      };
    }
    return const Color(0xFFEDF1F8);
  }
}
