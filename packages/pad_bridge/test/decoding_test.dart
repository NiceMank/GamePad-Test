import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pad_bridge/pad_bridge.dart';
import 'package:pad_core/pad_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('padlab/bridge');
  const eventChannel = EventChannel('padlab/events');

  late PadBridgeAndroid bridge;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    bridge = PadBridgeAndroid(
      methodChannel: methodChannel,
      eventChannel: eventChannel,
    );
  });

  tearDown(() async {
    await bridge.dispose();
    messenger.setMockMethodCallHandler(methodChannel, null);
  });

  test('decode un lot d\'événements natifs', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

    final events = <PadBridgeEvent>[];
    final sub = bridge.events.listen(events.add);

    // Simule l'émission d'un lot par le natif.
    final codec = const StandardMethodCodec();
    final payload = codec.encodeSuccessEnvelope([
      {
        'type': 'buttonDown',
        'deviceId': 1,
        'buttonIndex': PadButton.a.index,
        'code': 96,
        'timestampUs': 1000000,
      },
      {
        'type': 'axis',
        'deviceId': 1,
        'axis': 'leftTrigger',
        'code': 17,
        'value': 0.75,
        'rawValue': 191.0,
        'timestampUs': 1004000,
      },
      {
        'type': 'axis',
        'deviceId': 1,
        'axis': 'unknownAxis',
        'value': 1.0,
      },
    ]);

    await messenger.handlePlatformMessage(
      'padlab/events',
      payload,
      (_) {},
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(events.length, 2);
    expect(events.first.type, PadEventType.buttonDown);
    expect(events.first.button, PadButton.a);
    expect(events.last.axis, PadAxis.leftTrigger);
    expect(events.last.value, 0.75);
    expect(events.last.rawValue, 191.0);

    // Application à un état.
    var state = PadState.idle;
    state = events[0].applyTo(state, 1);
    state = events[1].applyTo(state, 2);
    expect(state.pressed, {PadButton.a});
    expect(state.axis(PadAxis.leftTrigger), 0.75);
    expect(state.rawAxis(PadAxis.leftTrigger), 191.0);

    await sub.cancel();
  });

  test('listDevices renvoie une liste vide si le natif manque', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw MissingPluginException('absent');
    });
    expect(await bridge.listDevices(), isEmpty);
    expect(await bridge.vibrate(deviceId: 1), isFalse);
    expect(await bridge.battery(1), isNull);
  });

  test('listDevices décode un appareil complet', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method != 'listDevices') return null;
      return [
        {
          'id': 3,
          'name': 'DualSense Wireless Controller',
          'vendorId': 1356,
          'productId': 3302,
          'controllerNumber': 1,
          'connection': 'bluetooth',
          'capabilities': {
            'buttonBits': 0x3FFFFF,
            'vibratorCount': 2,
            'hasBattery': true,
            'axes': [
              {'axis': 'leftX', 'min': -1.0, 'max': 1.0, 'flat': 0.05},
            ],
          },
          'battery': {'percent': 78.0, 'status': 'discharging'},
        }
      ];
    });

    final devices = await bridge.listDevices();
    expect(devices.length, 1);
    expect(devices.first.name, 'DualSense Wireless Controller');
    expect(devices.first.vendorId, 1356);
    expect(devices.first.connection, ConnectionGuess.bluetooth);
    expect(devices.first.capabilities.vibratorCount, 2);
    expect(devices.first.capabilities.hasBattery, isTrue);
    expect(devices.first.capabilities.axes.single.axis, PadAxis.leftX);
    expect(devices.first.capabilities.buttons.length, 22);
  });
}
