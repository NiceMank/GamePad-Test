import 'package:flutter/material.dart';

/// Couleurs sémantiques. Deux jeux complets, pensés comme un produit
/// matériel : fonds neutres, un seul accent, aucune couleur décorative.
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

  /// Accent principal : un seul, réservé aux données vivantes.
  Color get accent => cyan;

  static const dark = PadColors(
    bg: Color(0xFF0A0B0D),
    surface: Color(0xFF121316),
    card: Color(0xFF17191D),
    line: Color(0xFF26282E),
    text: Color(0xFFF2F3F5),
    muted: Color(0xFF8B9099),
    cyan: Color(0xFF3DDCC0),
    blue: Color(0xFF6C9BFF),
    magenta: Color(0xFFFF7BA8),
    green: Color(0xFF57D68C),
    amber: Color(0xFFFFC15E),
    danger: Color(0xFFFF6B6B),
    gradient: [Color(0xFF3DDCC0), Color(0xFF6C9BFF)],
    isDark: true,
  );

  static const light = PadColors(
    bg: Color(0xFFF4F4F1),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFE4E4DE),
    text: Color(0xFF15171A),
    muted: Color(0xFF6E7480),
    cyan: Color(0xFF0E9C88),
    blue: Color(0xFF3A62D6),
    magenta: Color(0xFFC22D62),
    green: Color(0xFF1B8A55),
    amber: Color(0xFF9A6A00),
    danger: Color(0xFFB33A3A),
    gradient: [Color(0xFF0E9C88), Color(0xFF3A62D6)],
    isDark: false,
  );

  static PadColors of(Brightness b) => b == Brightness.dark ? dark : light;

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

/// Typographie : Inter pour l'interface, JetBrains Mono pour les mesures.
class PadType {
  const PadType._();

  // Flutter expose les polices déclarées par un paquet sous le nom
  // « packages/<paquet>/<famille> » : sans ce préfixe, l'application
  // retombait silencieusement sur la police par défaut du système.
  static const display = 'packages/pad_ui/InterDisplay';
  static const body = 'packages/pad_ui/Inter';
  static const mono = 'packages/pad_ui/JetBrainsMono';
}

/// Thème PadLab.
class PadTheme {
  const PadTheme._();

  static ThemeData build(Brightness brightness) {
    final c = PadColors.of(brightness);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      fontFamily: PadType.body,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.cyan,
        brightness: brightness,
        primary: c.cyan,
        secondary: c.blue,
        surface: c.card,
        error: c.danger,
      ),
    );

    TextStyle t(double size, FontWeight w, {double height = 1.25, double tracking = -0.2, Color? color}) =>
        TextStyle(
          fontFamily: PadType.body,
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: tracking,
          color: color ?? c.text,
        );

    return base.copyWith(
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: c.text,
        titleTextStyle: TextStyle(
          fontFamily: PadType.display,
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: t(30, FontWeight.w600, height: 1.08, tracking: -1.0),
        headlineMedium: t(24, FontWeight.w600, height: 1.15, tracking: -0.8),
        headlineSmall: t(20, FontWeight.w600, height: 1.2, tracking: -0.5),
        titleLarge: t(17, FontWeight.w600, tracking: -0.35),
        titleMedium: t(14.5, FontWeight.w600, tracking: -0.15),
        titleSmall: t(12.5, FontWeight.w600, tracking: -0.1),
        bodyLarge: t(14, FontWeight.w400, height: 1.5, tracking: -0.05),
        bodyMedium: t(12.5, FontWeight.w400, height: 1.5, tracking: 0),
        bodySmall: t(11, FontWeight.w400, height: 1.45, tracking: 0.05, color: c.muted),
        labelLarge: t(13, FontWeight.w600, tracking: 0),
        labelSmall: t(9.5, FontWeight.w600, tracking: 0.6, color: c.muted),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.cyan,
        inactiveTrackColor: c.line,
        thumbColor: c.isDark ? Colors.white : c.text,
        overlayColor: c.cyan.withValues(alpha: 0.10),
        trackHeight: 6,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (c.isDark ? const Color(0xFF0A0B0D) : Colors.white)
              : c.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.cyan : c.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.isDark ? const Color(0xFF23262C) : const Color(0xFF23262C),
        contentTextStyle: const TextStyle(fontFamily: PadType.body, color: Colors.white, fontSize: 12.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.cyan, selectionColor: c.cyan.withValues(alpha: 0.25)),
    );
  }
}

/// Styles de texte partagés (raccourcis d'usage courant).
class PadText {
  const PadText._();

  static const mono = TextStyle(
    fontFamily: PadType.mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Petite étiquette de section : discrète, sans effet « tech ».
  static TextStyle eyebrow(BuildContext context) => TextStyle(
    fontFamily: PadType.body,
    fontSize: 11,
    letterSpacing: 0.4,
    fontWeight: FontWeight.w600,
    color: context.colors.muted,
  );

  /// Chiffre mis en avant.
  static TextStyle value(BuildContext context, {double size = 22}) => TextStyle(
    fontFamily: PadType.mono,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: context.colors.text,
  );
}
