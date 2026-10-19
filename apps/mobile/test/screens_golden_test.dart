import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_ui/pad_ui.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/features/analysis/analysis_screen.dart';
import 'package:padlab/features/battery/battery_screen.dart';
import 'package:padlab/features/home/home_screen.dart';
import 'package:padlab/features/link/link_screen.dart';
import 'package:padlab/features/remap/remap_screen.dart';
import 'package:padlab/features/settings/settings_screen.dart';
import 'package:padlab/features/tester/tester_screen.dart';
import 'package:padlab/session/pad_session.dart';

/// Rendus de référence des écrans, produits hors navigateur.
///
///   PADLAB_GOLDENS=1 flutter test --update-goldens test/screens_golden_test.dart
///
/// Désactivés par défaut : les écrans contiennent de l'horodatage réel
/// (journal, sessions), donc les images ne sont pas reproductibles d'une
/// exécution à l'autre. Ils servent de contrôle visuel local, pas de test
/// de régression bloquant en CI.
void main() {
  final enabled = Platform.environment['PADLAB_GOLDENS'] == '1';

  setUpAll(() async {
    // Charge les vraies polices : sans ça, le moteur de test dessine des
    // rectangles à la place des glyphes.
    // Police d'icônes : indispensable, sinon les IconData s'affichent en
    // carrés vides dans les rendus de test.
    final iconFont = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (iconFont.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(iconFont.readAsBytesSync().buffer)));
      await iconLoader.load();
    }

    const root = '../../packages/pad_ui/assets/fonts';
    for (final entry in {
      'Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
      'InterDisplay': ['InterDisplay-SemiBold', 'InterDisplay-Bold'],
      'JetBrainsMono': ['JetBrainsMono-Regular', 'JetBrainsMono-SemiBold'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        final bytes = File('$root/$file.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    Widget screen,
    String name, {
    Brightness brightness = Brightness.light,
    bool withSession = true,
  }) async {
    final session = PadSession();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 2.0;

    final widget = withSession
        ? PadScope(
            session: session,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: PadTheme.build(brightness),
              home: Scaffold(backgroundColor: PadTheme.build(brightness).scaffoldBackgroundColor, body: screen),
            ),
          )
        : screen;

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 120));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));

    // Démonte l'arbre et arrête la simulation : sinon les minuteurs de la
    // session restent en vie après la fin du test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    session.dispose();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('accueil clair', (t) => shoot(t, HomeScreen(onNavigate: (_) {}), 'home_light'), skip: !enabled);
  testWidgets('accueil sombre', (t) => shoot(t, HomeScreen(onNavigate: (_) {}), 'home_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('test clair', (t) => shoot(t, const TesterScreen(), 'test_light'), skip: !enabled);
  testWidgets('test sombre', (t) => shoot(t, const TesterScreen(), 'test_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('analyse clair', (t) => shoot(t, const AnalysisScreen(), 'analysis_light'), skip: !enabled);
  testWidgets('batterie clair', (t) => shoot(t, const BatteryScreen(), 'battery_light'), skip: !enabled);
  testWidgets('reglages clair', (t) => shoot(t, SettingsScreen(themeMode: ThemeMode.light, onThemeMode: (_) {}), 'settings_light'), skip: !enabled);
  testWidgets('remap clair', (t) => shoot(t, const RemapScreen(), 'remap_light'), skip: !enabled);
  testWidgets('link clair', (t) => shoot(t, const LinkScreen(), 'link_light'), skip: !enabled);
  testWidgets('remap sombre', (t) => shoot(t, const RemapScreen(), 'remap_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('analyse sombre', (t) => shoot(t, const AnalysisScreen(), 'analysis_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('batterie sombre', (t) => shoot(t, const BatteryScreen(), 'battery_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('reglages sombre', (t) => shoot(t, SettingsScreen(themeMode: ThemeMode.dark, onThemeMode: (_) {}), 'settings_dark', brightness: Brightness.dark), skip: !enabled);
  testWidgets('link sombre', (t) => shoot(t, const LinkScreen(), 'link_dark', brightness: Brightness.dark), skip: !enabled);
}
