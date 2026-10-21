import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pad_bridge/pad_bridge.dart';
import 'package:pad_core/pad_core.dart';

import 'package:padlab/session/hardware_source.dart';
import 'package:padlab/session/pad_session.dart';

/// Pont factice : rejoue ce que le natif Android renverrait, sans téléphone.
///
/// C'est ce qui permet de vérifier la bascule réelle/démo en test, alors
/// qu'aucune manette n'est branchée sur la machine.
class _FakeBridge implements PadBridgeAndroid {
  _FakeBridge({this.devices = const []});

  List<PadDevice> devices;
  final _events = StreamController<PadBridgeEvent>.broadcast();
  final _changes = StreamController<void>.broadcast();

  int vibrateCalls = 0;

  @override
  String? lastBatterySource = 'test';

  @override
  Future<Map<String, Object?>> batteryDiagnostics() async =>
      const {'officialApi': true, 'sysfsReadable': false};

  static const dualSense = PadDevice(
    id: 7,
    name: 'DualSense Wireless Controller',
    vendorId: 0x054C,
    productId: 0x0CE6,
    connection: ConnectionGuess.bluetooth,
    controllerNumber: 1,
    capabilities: PadCapabilities(
      buttonBits: 0x3FFFFF,
      vibratorCount: 2,
      hasBattery: true,
      hasLight: true,
      hasMotion: true,
      hasTouchpad: true,
    ),
    profileId: 'dualsense',
  );

  @override
  Stream<PadBridgeEvent> get events => _events.stream;

  @override
  Stream<void> get deviceChanges => _changes.stream;

  @override
  Future<List<PadDevice>> listDevices() async => devices;

  @override
  Future<PadDevice?> capabilities(int deviceId) async =>
      devices.where((d) => d.id == deviceId).firstOrNull;

  @override
  Future<BatteryReading?> battery(int deviceId) async => BatteryReading(
    at: DateTime.now(),
    status: BatteryStatus.discharging,
    percent: 63,
  );

  @override
  Future<bool> vibrate({
    required int deviceId,
    double strong = 1,
    double weak = 1,
    int durationMs = 300,
  }) async {
    vibrateCalls++;
    return true;
  }

  @override
  Future<void> stopVibration(int deviceId) async {}

  @override
  Future<Map<String, Object?>> platformInfo() async => const {'abi': 'test'};

  @override
  Future<void> dispose() async {
    await _events.close();
    await _changes.close();
  }

  /// Simule un appui bouton, comme le ferait `dispatchKeyEvent`.
  void press(PadButton button) {
    _events.add(PadBridgeEvent(
      type: PadEventType.buttonDown,
      deviceId: 7,
      button: button,
      value: 1,
      timestampUs: DateTime.now().microsecondsSinceEpoch,
    ));
  }

  /// Simule un branchement/débranchement.
  Future<void> plug(bool connected) async {
    devices = connected ? const [dualSense] : const [];
    _changes.add(null);
  }
}

PadSession _sessionWith(_FakeBridge bridge) {
  final session = PadSession(mode: SourceMode.real);
  session.hardware = HardwareSource(session, bridge: bridge);
  return session;
}

void main() {
  test('manette présente : la session lit le matériel', () async {
    final bridge = _FakeBridge(devices: const [_FakeBridge.dualSense]);
    final session = _sessionWith(bridge);
    session.hardware = HardwareSource(session, bridge: bridge);

    await session.startHardware();

    expect(session.simulate, isFalse, reason: 'les entrées doivent être réelles');
    expect(session.isReal, isTrue);
    expect(session.device?.name, contains('DualSense'));
    expect(session.hardwareError, isNull);

    session.dispose();
  });

  test('sans manette : la démonstration prend le relais', () async {
    final bridge = _FakeBridge();
    final session = PadSession(mode: SourceMode.auto);
    session.hardware = HardwareSource(session, bridge: bridge);

    await session.detectHardware();

    expect(session.simulate, isTrue);
    expect(session.sourceNote, contains('Aucune manette'));
    session.dispose();
  });

  test('branchement à chaud : on passe en réel', () async {
    final bridge = _FakeBridge();
    final session = PadSession(mode: SourceMode.auto);
    session.hardware = HardwareSource(session, bridge: bridge);

    await session.detectHardware();
    expect(session.simulate, isTrue);

    await bridge.plug(true);
    // Laisse le cycle asynchrone du pont se dérouler.
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(session.simulate, isFalse, reason: 'une manette vient d\'être branchée');
    expect(session.device, isNotNull);

    session.dispose();
  });

  test('débranchement : retour à la démonstration', () async {
    final bridge = _FakeBridge(devices: const [_FakeBridge.dualSense]);
    final session = PadSession(mode: SourceMode.auto);
    session.hardware = HardwareSource(session, bridge: bridge);

    await session.detectHardware();
    expect(session.isReal, isTrue);

    await bridge.plug(false);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(session.simulate, isTrue);
    expect(session.sourceNote, contains('débranchée'));

    session.dispose();
  });

  test('les événements natifs arrivent bien dans l\'état', () async {
    final bridge = _FakeBridge(devices: const [_FakeBridge.dualSense]);
    final session = _sessionWith(bridge);
    await session.startHardware();

    bridge.press(PadButton.a);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(session.state.isPressed(PadButton.a), isTrue);
    session.dispose();
  });
}
