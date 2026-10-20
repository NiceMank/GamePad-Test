import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlab/app/app.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/features/link/link_screen.dart';
import 'package:padlab/session/pad_session.dart';
import 'package:pad_ui/pad_ui.dart';

void main() {
  testWidgets('l\'app démarre et affiche la manette simulée', (tester) async {
    await tester.pumpWidget(const PadLabApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PadLab'), findsWidgets);
    expect(find.text('Lancer le test complet'), findsOneWidget);
  });

  test('les deux thèmes exposent des couleurs différentes', () {
    final dark = PadTheme.build(Brightness.dark);
    final light = PadTheme.build(Brightness.light);
    final darkColors = dark.extension<PadColors>()!;
    final lightColors = light.extension<PadColors>()!;
    expect(darkColors.bg, isNot(lightColors.bg));
    expect(darkColors.cyan, isNot(lightColors.cyan));
  });

  test('la démonstration expose une manette et une batterie', () {
    final session = PadSession(mode: SourceMode.demo);
    expect(session.device, isNotNull);
    expect(session.battery.percent, isNotNull);
    expect(session.simulate, isTrue);
    session.dispose();
  });

  test('le mode auto sans manette annonce la démonstration', () async {
    // Un environnement sans pont natif (test, bureau) ne doit ni planter ni
    // faire croire à du matériel réel.
    final session = PadSession();
    await session.detectHardware();
    expect(session.simulate, isTrue);
    expect(session.device, isNotNull);
    expect(session.sourceNote, isNotNull);
    session.dispose();
  });

  testWidgets('PadLab Link se construit hors de la coquille', (tester) async {
    // Régression : PadScope doit être au-dessus du Navigator, sinon les écrans
    // poussés lèvent « Null check operator used on a null value ».
    final session = PadSession(simulate: false);
    await tester.pumpWidget(
      PadScope(
        session: session,
        child: MaterialApp(
          theme: PadTheme.build(Brightness.dark),
          home: const LinkScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('PadLab Link'), findsWidgets);
    expect(find.text('Diffuser vers le PC'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
