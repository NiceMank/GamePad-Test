import 'package:flutter/material.dart';
import 'package:pad_core/pad_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padlab/app/scope.dart';
import 'package:padlab/features/analysis/analysis_screen.dart';
import 'package:padlab/features/battery/battery_screen.dart';
import 'package:padlab/features/home/home_screen.dart';
import 'package:padlab/features/remap/remap_screen.dart';
import 'package:padlab/features/tester/tester_screen.dart';
import 'package:padlab/session/pad_session.dart';
import 'package:pad_ui/pad_ui.dart';

/// Sans manette branchée, l'application doit rester utilisable et **ne rien
/// inventer**. Ces tests verrouillent ce comportement.
void main() {
  Widget wrap(PadSession session, Widget child) => PadScope(
    session: session,
    child: MaterialApp(
      theme: PadTheme.build(Brightness.dark),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('accueil sans manette : invitation explicite', (tester) async {
    final session = PadSession(mode: SourceMode.real);
    await tester.pumpWidget(wrap(session, HomeScreen(onNavigate: (_) {})));
    await tester.pump();

    expect(find.text('Aucune manette branchée'), findsOneWidget);
    expect(find.text('Voir la démonstration'), findsOneWidget);
    // Le badge doit dire la vérité : aucune entrée réelle.
    expect(find.text('Aucun'), findsOneWidget);
    expect(find.text('Réel'), findsNothing);
    expect(find.text('Branchez une manette pour commencer'), findsOneWidget);

    session.dispose();
  });

  test('mode réel sans manette : jamais de démonstration', () async {
    final session = PadSession(mode: SourceMode.real);
    await session.detectHardware();
    expect(session.simulate, isFalse, reason: 'choix explicite respecté');
    expect(session.device, isNull);
    session.dispose();
  });

  testWidgets('les écrans se construisent sans manette', (tester) async {
    final session = PadSession(mode: SourceMode.real);
    for (final screen in <Widget>[
      const TesterScreen(),
      const AnalysisScreen(),
      const BatteryScreen(),
      const RemapScreen(),
    ]) {
      await tester.pumpWidget(wrap(session, screen));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'écran $screen');
    }
    session.dispose();
  });

  testWidgets('accueil avec manette : badge Réel', (tester) async {
    final session = PadSession(mode: SourceMode.real);
    session.setDevice(const PadDevice(
      id: 3,
      name: 'Manchettes',
      vendorId: 0x054C,
      productId: 0x0CE6,
      connection: ConnectionGuess.usb,
      controllerNumber: 1,
      capabilities: PadCapabilities(buttonBits: 0x3FFFFF),
      profileId: 'dualsense',
    ));
    session.ingestRaw(PadState.idle);

    await tester.pumpWidget(wrap(session, HomeScreen(onNavigate: (_) {})));
    await tester.pump();

    expect(find.text('Réel'), findsOneWidget);
    expect(find.text('Aucune manette branchée'), findsNothing);
    // La 3D est bien là quand une manette est connue.
    expect(find.byType(Controller3D), findsOneWidget);

    session.dispose();
  });
}
