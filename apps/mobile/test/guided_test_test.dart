import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';

import 'package:padlab/app/scope.dart';
import 'package:padlab/features/tester/guided_test_screen.dart';
import 'package:padlab/session/pad_session.dart';

void main() {
  testWidgets('le test guidé avance étape par étape', (tester) async {
    // Sans simulation : l'état doit venir uniquement des appuis du test,
    // sinon la manette virtuelle écrit par-dessus.
    final session = PadSession(simulate: false);
    await tester.pumpWidget(
      PadScope(
        session: session,
        child: MaterialApp(
          theme: PadTheme.build(Brightness.dark),
          home: const Scaffold(body: GuidedTestScreen(embedded: true)),
        ),
      ),
    );
    await tester.pump();

    // Départ : première étape, croix directionnelle.
    expect(find.text('Étape 1 sur 7'), findsOneWidget);
    expect(find.textContaining('Croix directionnelle'), findsOneWidget);

    // Une entrée de croix valide l'étape et fait avancer d'un cran.
    // On injecte l'état brut puis on laisse le minuteur de surveillance
    // tourner : c'est le vrai chemin (appui -> état -> validation).
    // L'étape demande les quatre directions : on les presse une par une.
    for (final b in [
      PadButton.dpadUp,
      PadButton.dpadDown,
      PadButton.dpadLeft,
      PadButton.dpadRight,
    ]) {
      session.ingestRaw(PadState(pressed: {b}));
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(find.text('Étape 2 sur 7'), findsOneWidget);

    // « Passer » saute l'étape sans la valider.
    await tester.tap(find.text('Passer'));
    await tester.pump();
    expect(find.text('Étape 3 sur 7'), findsOneWidget);
  });
}
