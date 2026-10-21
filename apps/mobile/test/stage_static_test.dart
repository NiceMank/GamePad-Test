import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:padlab/features/home/home_screen.dart';
import 'package:pad_ui/pad_ui.dart';

/// Le modèle doit rester immobile tant que l'utilisateur ne demande rien.
/// Une scène qui tourne seule empêche de lire les détails et fatigue l'œil.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: PadTheme.build(Brightness.dark),
    home: Scaffold(body: child),
  );

  testWidgets('la scène est immobile au repos', (tester) async {
    await tester.pumpWidget(
      host(
        ControllerStage(
          state: const PadState(),
          family: ControllerFamily.dualSense,
          onButtonTap: (_) {},
        ),
      ),
    );
    await tester.pump();

    final before = tester.widget<Controller3D>(find.byType(Controller3D));
    expect(before.spinning, isFalse, reason: 'aucune rotation par défaut');
    expect(before.autoRotate, isFalse);

    // Rien ne bouge après plusieurs images.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Tourner » active la rotation, « Stop » l\'arrête', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ControllerStage(
          state: const PadState(),
          family: ControllerFamily.dualSense,
          onButtonTap: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tourner'));
    await tester.pump();
    expect(
      tester.widget<Controller3D>(find.byType(Controller3D)).spinning,
      isTrue,
    );
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(
      tester.widget<Controller3D>(find.byType(Controller3D)).spinning,
      isFalse,
      reason: 'l\'utilisateur reprend la main',
    );
  });

  testWidgets('« Recentrer » envoie bien le signal', (tester) async {
    await tester.pumpWidget(
      host(
        ControllerStage(
          state: const PadState(),
          family: ControllerFamily.dualSense,
          onButtonTap: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Recentrer'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('l\'aide disparaît dès qu\'on touche aux commandes', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ControllerStage(
          state: const PadState(),
          family: ControllerFamily.dualSense,
          onButtonTap: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Glissez pour tourner'), findsOneWidget);
    await tester.tap(find.text('Tourner'));
    await tester.pump();
    expect(find.text('Glissez pour tourner'), findsNothing);
  });
}
