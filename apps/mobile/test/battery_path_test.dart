import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pad_bridge/pad_bridge.dart';
import 'package:pad_core/pad_core.dart';
import 'package:padlab/session/hardware_source.dart';
import 'package:padlab/session/pad_session.dart';

/// Le défaut signalé : « les infos de la batterie ne s'affichaient pas ».
/// On vérifie ici les trois cas possibles, sans téléphone.
class _Bridge implements PadBridgeAndroid {
  _Bridge({required this.payload});

  Map<String, Object?>? payload;

  /// Source annoncée par le pont natif (`android`, `kernel`, `none`).
  String reportedSource = 'android';

  static const device = PadDevice(
    id: 4,
    name: 'DualSense',
    vendorId: 0x054C,
    productId: 0x0CE6,
    connection: ConnectionGuess.bluetooth,
    controllerNumber: 1,
    capabilities: PadCapabilities(buttonBits: 0xFF),
    profileId: 'dualsense',
  );

  @override
  String? lastBatterySource = 'android';

  @override
  Stream<PadBridgeEvent> get events => const Stream.empty();

  @override
  Stream<void> get deviceChanges => const Stream.empty();

  @override
  Future<List<PadDevice>> listDevices() async => const [device];

  @override
  Future<PadDevice?> capabilities(int id) async => device;

  @override
  Future<BatteryReading?> battery(int id) async {
    lastBatterySource = reportedSource;
    if (payload == null) return null;
    final percent = (payload!['percent'] as num?)?.toDouble();
    return BatteryReading(
      at: DateTime.now(),
      status: BatteryStatus.values.firstWhere(
        (s) => s.name == payload!['status'],
        orElse: () => BatteryStatus.unknown,
      ),
      percent: percent,
    );
  }

  @override
  Future<Map<String, Object?>> batteryDiagnostics() async =>
      const {'officialApi': true, 'sysfsReadable': false};

  @override
  Future<bool> vibrate({
    required int deviceId,
    double strong = 1,
    double weak = 1,
    int durationMs = 300,
  }) async => true;

  @override
  Future<void> stopVibration(int deviceId) async {}

  @override
  Future<Map<String, Object?>> platformInfo() async => const {};

  @override
  Future<void> dispose() async {}
}

void main() {
  test('une valeur native s\'affiche', () async {
    final bridge = _Bridge(payload: {'percent': 63.0, 'status': 'discharging'});
    final session = PadSession(mode: SourceMode.real);
    final source = HardwareSource(session, bridge: bridge);
    session.hardware = source;

    await session.startHardware();
    await source.refreshBattery();

    expect(session.battery.percent, 63.0);
    expect(session.batteryUnavailableReason, isNull);
    session.dispose();
  });

  test('une absence de valeur s\'explique, elle ne se tait pas', () async {
    final bridge = _Bridge(payload: {'percent': null, 'status': 'unknown'});
    final session = PadSession(mode: SourceMode.real);
    final source = HardwareSource(session, bridge: bridge);
    session.hardware = source;

    await session.startHardware();
    await source.refreshBattery();

    expect(session.battery.percent, isNull);
    expect(session.batteryUnavailableReason, isNotNull);
    expect(session.batteryUnavailableReason, contains('ne fournit pas'));
    session.dispose();
  });

  test('une lecture ratée ne fait pas disparaître une valeur connue', () async {
    final bridge = _Bridge(payload: {'percent': 80.0, 'status': 'discharging'});
    final session = PadSession(mode: SourceMode.real);
    final source = HardwareSource(session, bridge: bridge);
    session.hardware = source;

    await session.startHardware();
    await source.refreshBattery();
    expect(session.battery.percent, 80.0);

    // La manette cesse de répondre : on garde la dernière valeur.
    bridge.payload = null;
    await source.refreshBattery();
    expect(session.battery.percent, 80.0);
    expect(session.batteryUnavailableReason, isNotNull);

    session.dispose();
  });
}
