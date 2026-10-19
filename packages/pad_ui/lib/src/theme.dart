import 'package:flutter/material.dart';

/// Couleurs sémantiques, avec deux jeux complets (sombre / clair).
@immutable
class PadColors extends ThemeExtension<PadColors> {
  const PadColors({
    required this.bg,
    required this.surface,
    required this.card,
    required this.line,
    required this.text,
    required this.muted,
    required this.cyan,
    required this.blue,
    required this.magenta,
    required this.green,
    required this.amber,
    required this.danger,
    required this.gradient,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color card;
  final Color line;
  final Color text;
  final Color muted;
  final Color cyan;
  final Color blue;
  final Color magenta;
  final Color green;
  final Color amber;
  final Color danger;
  final List<Color> gradient;
  final bool isDark;

  static const dark = PadColors(
    bg: Color(0xFF05070D),
    surface: Color(0xFF0B101C),
    card: Color(0xFF101828),
    line: Color(0xFF1D2940),
    text: Color(0xFFE9F1FF),
    muted: Color(0xFF8494AC),
    cyan: Color(0xFF22E6FF),
    blue: Color(0xFF4C7DFF),
    magenta: Color(0xFFFF3D9A),
    green: Color(0xFF46F0A0),
    amber: Color(0xFFFFC857),
    danger: Color(0xFFFF5C6C),
    gradient: [Color(0xFF22E6FF), Color(0xFF4C7DFF)],
    isDark: true,
  );

  static const light = PadColors(
    bg: Color(0xFFF8FBFE),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE2EAF4),
    text: Color(0xFF0E1929),
    muted: Color(0xFF65778E),
    cyan: Color(0xFF0A8AA6),
    blue: Color(0xFF2F5FE0),
    magenta: Color(0xFFD31C67),
    green: Color(0xFF0B8C5E),
    amber: Color(0xFFA87300),
    danger: Color(0xFFC9343F),
    gradient: [Color(0xFF0A8AA6), Color(0xFF2F5FE0)],
    isDark: false,
  );

  @override
  PadColors copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? line,
    Color? text,
    Color? muted,
    Color? cyan,
    Color? blue,
    Color? magenta,
    Color? green,
    Color? amber,
    Color? danger,
    List<Color>? gradient,
    bool? isDark,
  }) => PadColors(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    line: line ?? this.line,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    cyan: cyan ?? this.cyan,
    blue: blue ?? this.blue,
    magenta: magenta ?? this.magenta,
    green: green ?? this.green,
    amber: amber ?? this.amber,
    danger: danger ?? this.danger,
    gradient: gradient ?? this.gradient,
    isDark: isDark ?? this.isDark,
  );

  @override
  PadColors lerp(ThemeExtension<PadColors>? other, double t) {
    if (other is! PadColors) return this;
    return PadColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      line: Color.lerp(line, other.line, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      magenta: Color.lerp(magenta, other.magenta, t)!,
      green: Color.lerp(green, other.green, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      gradient: [
        Color.lerp(gradient[0], other.gradient[0], t)!,
        Color.lerp(gradient[1], other.gradient[1], t)!,
      ],
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension PadColorsContext on BuildContext {
  PadColors get colors => Theme.of(this).extension<PadColors>() ?? PadColors.dark;
}

/// Thème PadLab complet. Le mode suit le système par défaut.
class PadTheme {
  const PadTheme._();

  static ThemeData build(Brightness brightness) {
    final c = brightness == Brightness.dark ? PadColors.dark : PadColors.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.cyan,
        brightness: brightness,
        primary: c.cyan,
        secondary: c.magenta,
        surface: c.card,
        error: c.danger,
      ),
    );

    return base.copyWith(
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: c.text,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: c.text,
        displayColor: c.text,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.cyan,
        inactiveTrackColor: c.line,
        thumbColor: Colors.white,
        overlayColor: c.cyan.withValues(alpha: 0.12),
        trackHeight: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.cyan : c.line,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Styles de texte partagés.
class PadText {
  const PadText._();

  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextStyle eyebrow(BuildContext context) => TextStyle(
    fontSize: 11,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w800,
    color: context.colors.muted,
  );

  static TextStyle value(BuildContext context, {double size = 20}) => mono.copyWith(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: context.colors.text,
  );
}
