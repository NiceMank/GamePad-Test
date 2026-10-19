import 'package:flutter/material.dart';

import 'theme.dart';

/// Surface de base : carte mate, filet fin, ombre très douce.
///
/// Pas de bordure lumineuse ni de dégradé : sur un écran de mesure, le
/// contenu doit primer sur le décor.
class PadCard extends StatelessWidget {
  const PadCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.onTap,
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: accent ?? c.line, width: accent == null ? 1 : 1.2),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: c.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A101828),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: c.card,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Titre de section : petit, en gris, jamais en majuscules criardes.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.trailing, this.top = 0});

  final String label;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8, left: 2, right: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: c.muted,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bouton principal : plein, sombre en thème clair, clair en thème sombre.
/// Un seul bouton de ce type par écran.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final bg = c.isDark ? c.text : c.text;
    final fg = c.isDark ? const Color(0xFF0A0B0D) : Colors.white;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    color: fg,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 17, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire : contour seul.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: c.text),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile de mesure : label discret, valeur en mono, unité alignée.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.tone,
    this.badge,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? tone;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: c.muted),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (tone ?? c.cyan).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tone ?? c.cyan),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: PadType.mono,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: tone ?? c.text,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: TextStyle(
                    fontFamily: PadType.mono,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: c.muted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Segments avec sélection animée, sans bordure dure.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.compact = false,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(vertical: compact ? 7 : 9),
                  decoration: BoxDecoration(
                    color: i == index ? (c.isDark ? const Color(0xFF2A2D34) : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: i == index && !c.isDark
                        ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                      color: i == index ? c.text : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de diagnostic : pastille de sévérité, libellé, valeur.
class IssueTile extends StatelessWidget {
  const IssueTile({
    super.key,
    required this.title,
    required this.detail,
    this.severity = PadIssueLevel.ok,
  });

  final String title;
  final String detail;
  final PadIssueLevel severity;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = switch (severity) {
      PadIssueLevel.ok => c.green,
      PadIssueLevel.warning => c.amber,
      PadIssueLevel.critical => c.danger,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.text),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 11, height: 1.45, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum PadIssueLevel { ok, warning, critical }

/// Petit pictogramme de manette, utilisé dans les listes.
class ControllerGlyph extends StatelessWidget {
  const ControllerGlyph({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.muted;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(tint, c.line)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.tint, this.line);

  final Color tint;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.24, w * 0.84, h * 0.46),
      Radius.circular(h * 0.22),
    );
    canvas.drawRRect(body, Paint()..color = tint.withValues(alpha: 0.10));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tint.withValues(alpha: 0.55),
    );
    canvas.drawCircle(Offset(w * 0.30, h * 0.47), w * 0.075, Paint()..color = tint.withValues(alpha: 0.75));
    canvas.drawCircle(Offset(w * 0.70, h * 0.47), w * 0.075, Paint()..color = tint.withValues(alpha: 0.75));
    canvas.drawLine(
      Offset(w * 0.40, h * 0.33),
      Offset(w * 0.60, h * 0.33),
      Paint()
        ..color = line
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.tint != tint || old.line != line;
}

/// En-tête d'écran commun : surtitre discret, titre éditorial, sous-titre.
///
/// Tous les onglets partagent ce rythme, sinon chaque écran ressemble à une
/// application différente.
class PadHeader extends StatelessWidget {
  const PadHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.7,
                      color: c.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'InterDisplay',
                    fontSize: 29,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                    color: c.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, height: 1.35, color: c.muted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(top: 6), child: trailing!),
        ],
      ),
    );
  }
}
