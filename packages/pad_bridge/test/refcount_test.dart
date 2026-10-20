import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_bridge/pad_bridge.dart';

/// Régression : couper la capture des entrées coupait aussi l'écoute des
/// branchements. Une manette débranchée puis rebranchée n'était alors plus
/// jamais détectée — c'est le scénario le plus courant en usage réel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = EventChannel('padlab/events');
  late StreamController<dynamic> native;
  var listenCount = 0;
  var cancelCount = 0;
  StreamSubscription<dynamic>? nativeSub;

  setUp(() {
    native = StreamController<dynamic>.broadcast();
    listenCount = 0;
    cancelCount = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          channel,
          MockStreamHandler.inline(
            onListen: (arguments, events) {
              listenCount++;
              nativeSub = native.stream.listen(
                events.success,
                onError: (Object error) => events.error(
                  code: 'stream',
                  message: error.toString(),
                ),
              );
            },
            onCancel: (arguments) {
              cancelCount++;
              nativeSub?.cancel();
              nativeSub = null;
            },
          ),
        );
  });

  tearDown(() async {
    await native.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(channel, null);
  });

  test('le canal reste ouvert tant qu\'un flux écoute', () async {
    final bridge = PadBridgeAndroid();

    final subChanges = bridge.deviceChanges.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(listenCount, 1, reason: 'la veille ouvre le canal natif');

    // Capture des entrées démarrée puis arrêtée, comme lors d\'un
    // débranchement.
    final subEvents = bridge.events.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(listenCount, 1, reason: 'un seul abonnement natif');

    await subEvents.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(cancelCount, 0, reason: 'la veille écoute encore : canal maintenu');

    await subChanges.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cancelCount, 1, reason: 'plus personne : le canal se ferme');

    await bridge.dispose();
  });
}
