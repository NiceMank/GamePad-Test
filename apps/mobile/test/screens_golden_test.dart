import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/features/analysis/analysis_screen.dart';
import 'package:padlab/features/battery/battery_screen.dart';
import 'package:padlab/features/home/home_screen.dart';
import 'package:padlab/features/link/link_screen.dart';
import 'package:padlab/features/onboarding/onboarding_screen.dart';
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
      'packages/pad_ui/Inter': ['Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold'],
      'packages/pad_ui/InterDisplay': ['InterDisplay-SemiBold', 'InterDisplay-Bold'],
      'packages/pad_ui/JetBrainsMono': ['JetBrainsMono-Regular', 'JetBrainsMono-SemiBold'],
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
    void Function(PadSession)? setup,
    Future<void> Function()? beforeShot,
  }) async {
    final session = PadSession(mode: setup == null ? SourceMode.demo : SourceMode.real);
    setup?.call(session);
    await tester.binding.setSurfaceSize(const Size(430, 900));
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 2.0;

    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PadTheme.build(brightness),
      home: Scaffold(
        backgroundColor: PadTheme.build(brightness).scaffoldBackgroundColor,
        body: screen,
      ),
    );
    final widget = withSession ? PadScope(session: session, child: app) : app;

    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 120));
    if (beforeShot != null) await beforeShot();
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

  /// Mode réel : une manette branchée, badge vert et entrées matérielles.
  testWidgets(
    'accueil réel',
    (t) => shoot(
      t,
      HomeScreen(onNavigate: (_) {}),
      'home_real_dark',
      brightness: Brightness.dark,
      setup: (session) {
        session.setDevice(const PadDevice(
          id: 5,
          name: 'DualSense Wireless Controller',
          vendorId: 0x054C,
          productId: 0x0CE6,
          connection: ConnectionGuess.bluetooth,
          controllerNumber: 1,
          capabilities: PadCapabilities(buttonBits: 0x3FFFFF, vibratorCount: 2),
          profileId: 'dualsense',
        ));
        session.setBattery(BatteryReading(
          at: DateTime.now(),
          status: BatteryStatus.discharging,
          percent: 68,
        ));
      },
    ),
    skip: !enabled,
  );

  /// Introduction du premier lancement : quatre étapes, deux thèmes.
  testWidgets(
    'onboarding 1',
    (t) => shoot(
      t,
      OnboardingScreen(onDone: () {}),
      'onboarding_1_dark',
      brightness: Brightness.dark,
      withSession: false,
    ),
    skip: !enabled,
  );
  testWidgets(
    'onboarding 1 clair',
    (t) => shoot(
      t,
      OnboardingScreen(onDone: () {}),
      'onboarding_1_light',
      withSession: false,
    ),
    skip: !enabled,
  );
  testWidgets(
    'onboarding 4',
    (t) async {
      await shoot(
        t,
        OnboardingScreen(onDone: () {}),
        'onboarding_4_dark',
        brightness: Brightness.dark,
        withSession: false,
        beforeShot: () async {
          for (var i = 0; i < 3; i++) {
            await t.tap(find.text('Suivant'));
            await t.pumpAndSettle();
          }
        },
      );
    },
    skip: !enabled,
  );

  /// Aucune manette : l'application doit le dire, pas inventer une manette.
  testWidgets(
    'accueil sans manette',
    (t) => shoot(
      t,
      HomeScreen(onNavigate: (_) {}),
      'home_empty_dark',
      brightness: Brightness.dark,
      setup: (session) {},
    ),
    skip: !enabled,
  );
}
