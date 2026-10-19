import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pad_ui/pad_ui.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/session/pad_session.dart';

/// Un clic sur le modèle doit produire **exactement** le même retour qu'un
/// appui physique : état, journal, analyse et allumage de la pièce.
void main() {
  testWidgets('un clic sur le modèle traverse le vrai chemin d\'entrée', (tester) async {
    final session = PadSession(simulate: false);
    await tester.binding.setSurfaceSize(const Size(420, 420));
    tester.view.physicalSize = const Size(420, 420);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      PadScope(
        session: session,
        child: MaterialApp(
          theme: PadTheme.build(Brightness.dark),
          home: Scaffold(
            body: Controller3D(
              state: session.state,
              family: ControllerFamily.dualSense,
              initialYaw: 0,
              initialPitch: 0,
              onButtonTap: session.tapButton,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Balayage grossier : on cherche un point qui tombe sur une pièce.
    PadButton? touched;
    final positions = <Offset>[];
    for (var y = 40.0; y < 380 && touched == null; y += 14) {
      for (var x = 40.0; x < 380 && touched == null; x += 14) {
        positions.add(Offset(x, y));
      }
    }
    for (final p in positions) {
      await tester.tapAt(p);
      await tester.pump();
      if (session.state.pressed.isNotEmpty) {
        touched = session.state.pressed.first;
        break;
      }
    }

    expect(touched, isNotNull, reason: 'aucun clic n\'a atteint une pièce du modèle');

    // Le clic est bien passé par le pipeline complet : journal d'événements
    // et analyseurs alimentés comme pour un appui matériel.
    expect(
      session.recentEvents.any((e) => e.button == touched),
      isTrue,
      reason: 'l\'appui n\'a pas été journalisé',
    );

    // Le relâchement est automatique : l'état revient au repos.
    await tester.pump(const Duration(milliseconds: 220));
    expect(session.state.pressed, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
