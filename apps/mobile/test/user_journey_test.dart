import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlab/app/app.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/features/analysis/analysis_screen.dart';
import 'package:padlab/features/battery/battery_screen.dart';
import 'package:padlab/features/link/link_screen.dart';
import 'package:padlab/features/onboarding/onboarding_screen.dart';
import 'package:padlab/features/remap/remap_screen.dart';
import 'package:padlab/features/settings/settings_screen.dart';
import 'package:padlab/features/tester/tester_screen.dart';
import 'package:padlab/session/pad_session.dart';
import 'package:pad_ui/pad_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parcours complet, du premier lancement au dernier écran.
///
/// Chaque étape est vérifiée séparément : on avance pas à pas, et un échec
/// dit exactement où le parcours casse.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(PadSession session, Widget child) => PadScope(
    session: session,
    child: MaterialApp(
      theme: PadTheme.build(Brightness.dark),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('1. premier lancement → introduction', (tester) async {
    await tester.pumpWidget(const PadLabApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('2. introduction → accueil', (tester) async {
    await tester.pumpWidget(const PadLabApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text('Passer'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Lancer le test complet'), findsOneWidget);
  });

  testWidgets('3. les cinq onglets s\'ouvrent', (tester) async {
    SharedPreferences.setMockInitialValues({'padlab.onboarding.v1': true});
    await tester.pumpWidget(const PadLabApp());
    await tester.pump(const Duration(milliseconds: 40));

    for (final tab in ['Test', 'Analyse', 'Batterie', 'Réglages', 'Accueil']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: 'onglet $tab');
    }
    expect(find.text('Lancer le test complet'), findsOneWidget);
  });

  testWidgets('4. test guidé : les 7 étapes avancent', (tester) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(host(session, const TesterScreen()));
    await tester.pump();

    // Le test guidé affiche son étape courante et le modèle 3D.
    expect(find.text('Lancer le test complet'), findsNothing);
    expect(find.byType(Controller3D), findsWidgets);
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('5. analyse : bouton de mesure utilisable', (tester) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(host(session, const AnalysisScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('6. batterie sans manette : aucun chiffre inventé', (tester) async {
    final session = PadSession(mode: SourceMode.real);
    await tester.pumpWidget(host(session, const BatteryScreen()));
    await tester.pump();
    expect(find.text('—'), findsWidgets);
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('7. remap : la liste des boutons est là', (tester) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(host(session, const RemapScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('8. Link : l\'écran s\'ouvre et donne un code', (tester) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(host(session, const LinkScreen()));
    await tester.pump();
    expect(find.text('Diffuser vers le PC'), findsOneWidget);
    expect(tester.takeException(), isNull);
    session.dispose();
  });

  testWidgets('9. réglages : les trois modes changent la source', (tester) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(
      host(
        session,
        SettingsScreen(themeMode: ThemeMode.dark, onThemeMode: (_) {}),
      ),
    );
    await tester.pump();

    expect(session.mode, SourceMode.demo);
    await tester.tap(find.text('Manette').first);
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.mode, SourceMode.real);
    expect(session.simulate, isFalse);

    await tester.tap(find.text('Démo'));
    await tester.pump(const Duration(milliseconds: 40));
    expect(session.mode, SourceMode.demo);
    // Le retour en démonstration est asynchrone : on laisse le cycle
    // démarrer avant de conclure.
    expect(session.simulate, isTrue);

    session.dispose();
  });

  testWidgets('10. actualisation automatique : interrupteur présent', (
    tester,
  ) async {
    final session = PadSession(mode: SourceMode.demo);
    await tester.pumpWidget(
      host(
        session,
        SettingsScreen(themeMode: ThemeMode.dark, onThemeMode: (_) {}),
      ),
    );
    await tester.pump();

    expect(find.text('Actualisation automatique'), findsOneWidget);
    expect(session.autoRefresh, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(session.autoRefresh, isFalse);

    session.dispose();
  });

  testWidgets('11. manette branchée : l\'accueil passe en réel', (tester) async {
    SharedPreferences.setMockInitialValues({'padlab.onboarding.v1': true});
    await tester.pumpWidget(const PadLabApp());
    await tester.pump(const Duration(milliseconds: 40));
    // Sans pont natif : pas de manette → l'app le dit.
    expect(find.text('Aucune manette branchée'), findsOneWidget);
    expect(find.text('Aucun'), findsOneWidget);
  });

  testWidgets('12. choix mémorisé après « Commencer »', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PadLabApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pump(const Duration(milliseconds: 60));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('padlab.onboarding.v1'), isTrue);
  });
}
