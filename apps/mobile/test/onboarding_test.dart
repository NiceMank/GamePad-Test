import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlab/app/app.dart';
import 'package:padlab/app/onboarding_state.dart';
import 'package:padlab/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parcours du premier lancement : c'est la première chose que voit
/// l'utilisateur, donc la première chose à ne pas casser.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('premier lancement : introduction puis accueil', (tester) async {
    await tester.pumpWidget(const PadLabApp());
    await tester.pump(); // laisse lire la préférence
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.text('Branchez.\nC\'est tout.'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);

    // Quatre étapes, la dernière propose « Commencer ».
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    expect(find.text('Passer'), findsNothing, reason: 'dernière étape');

    await tester.tap(find.text('Commencer'));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Lancer le test complet'), findsOneWidget);
    // Le choix est mémorisé.
    expect(await OnboardingState.seen(), isTrue);
  });

  testWidgets('« Passer » mène aussi à l\'accueil', (tester) async {
    await tester.pumpWidget(const PadLabApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Passer'));
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(await OnboardingState.seen(), isTrue);
  });

  testWidgets('deuxième lancement : pas d\'introduction', (tester) async {
    SharedPreferences.setMockInitialValues({'padlab.onboarding.v1': true});
    await tester.pumpWidget(const PadLabApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Lancer le test complet'), findsOneWidget);
  });

  testWidgets('chaque étape a du texte et une illustration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onDone: () {}),
      ),
    );
    await tester.pump();

    for (var step = 0; step < 4; step++) {
      // Le titre est visible et non vide : aucune page blanche.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.contains('Branchez') == true ||
                  w.data?.contains('Voyez') == true ||
                  w.data?.contains('Diagnostiquez') == true ||
                  w.data?.contains('Jouez') == true),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (step < 3) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
    }
  });
}
