import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pad_bridge/pad_bridge.dart';
import 'package:pad_core/pad_core.dart';

import 'pad_session.dart';

/// Relie une manette Android **réelle** à la session.
///
/// Le natif regroupe les événements (~120 Hz), ce qui borne le coût du pont
/// sans perdre les timestamps de capture. L'UI n'est rafraîchie qu'à ~60 Hz,
/// même quand la manette émet à 1000 Hz : les analyseurs, eux, voient tout.
class HardwareSource {
  HardwareSource(this.session, {PadBridgeAndroid? bridge})
    : _bridge = bridge ?? PadBridgeAndroid();

  final PadSession session;
  final PadBridgeAndroid _bridge;

  StreamSubscription<PadBridgeEvent>? _events;
  StreamSubscription<void>? _changes;
  Timer? _batteryTimer;
  Timer? _uiTimer;

  PadState _state = PadState.idle;
  int _sequence = 0;
  bool _running = false;

  /// Dernière erreur rencontrée (null = tout va bien).
  String? lastError;

  /// Statistiques de liaison.
  int eventsReceived = 0;
  int batchesReceived = 0;
  DateTime? startedAt;
  final List<double> _latencyMs = <double>[];

  bool get running => _running;
  bool get hasDevice => session.device != null;

  List<double> get latencies => List<double>.unmodifiable(_latencyMs);
  double get latencyP50 => _percentile(0.50);
  double get latencyP95 => _percentile(0.95);

  double _percentile(double p) {
    if (_latencyMs.isEmpty) return 0;
    final sorted = [..._latencyMs]..sort();
    final index = ((sorted.length - 1) * p).round();
    return sorted[index];
  }

  /// Démarre la capture. Renvoie `null` en cas de succès, sinon un message.
  Future<String?> start() async {
    if (_running) return null;
    startedAt = DateTime.now();
    lastError = null;
    _state = PadState.idle;
    _sequence = 0;

    _events = _bridge.events.listen(
      _onEvent,
      onError: (Object error) {
        lastError = 'Flux natif interrompu : $error';
      },
    );
    _changes = _bridge.deviceChanges.listen((_) => unawaited(refreshDevices()));

    // L'UI suit à 60 Hz : inutile de reconstruire plus vite qu'un écran.
    _uiTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (session.hardwareDirty) session.pulse();
    });

    await refreshDevices();
    if (session.device == null) {
      lastError = 'Aucune manette détectée. Branchez une manette puis réessayez.';
      return lastError;
    }

    _batteryTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(refreshBattery()),
    );
    _running = true;
    return null;
  }

  Future<void> stop() async {
    _running = false;
    _uiTimer?.cancel();
    _uiTimer = null;
    _batteryTimer?.cancel();
    _batteryTimer = null;
    await _events?.cancel();
    await _changes?.cancel();
    _events = null;
    _changes = null;
  }

  /// Relit la liste des manettes et sélectionne la manette courante.
  Future<void> refreshDevices() async {
    final devices = await _bridge.listDevices();
    session.hardwareDevices = devices;
    if (devices.isEmpty) {
      session.setDevice(null);
      return;
    }
    final current = devices
        .where((d) => d.id == session.activeDeviceId)
        .firstOrNull;
    final chosen = current ?? devices.first;
    final described = await _bridge.capabilities(chosen.id);
    session.setDevice(described ?? chosen);
    await refreshBattery();
    lastError = null;
  }

  Future<void> refreshBattery() async {
    final id = session.activeDeviceId;
    if (id == 0) return;
    final reading = await _bridge.battery(id);
    if (reading != null) session.setBattery(reading);
  }

  Future<Map<String, Object?>> platformInfo() => _bridge.platformInfo();

  /// Liste les manettes présentes sans démarrer la capture.
  Future<List<PadDevice>> listDevices() => _bridge.listDevices();

  Future<bool> vibrate({
    double strong = 1.0,
    double weak = 1.0,
    int durationMs = 300,
  }) async {
    final id = session.activeDeviceId;
    if (id == 0) return false;
    final ok = await _bridge.vibrate(
      deviceId: id,
      strong: strong,
      weak: weak,
      durationMs: durationMs,
    );
    if (!ok) lastError = 'Vibration refusée par la manette.';
    return ok;
  }

  Future<void> stopVibration() async {
    final id = session.activeDeviceId;
    if (id != 0) await _bridge.stopVibration(id);
  }

  void _onEvent(PadBridgeEvent event) {
    eventsReceived++;
    final latency = _latency(event);
    if (latency != null) {
      _latencyMs.add(latency);
      if (_latencyMs.length > 192) _latencyMs.removeAt(0);
    }
    _state = event.applyTo(_state, ++_sequence);
    // notify: false → le timer 60 Hz s'occupe du rendu.
    session.ingestRaw(_state, notify: false);
    session.hardwareDirty = true;
  }

  double? _latency(PadBridgeEvent event) {
    if (event.timestampUs <= 0) return null;
    final us = DateTime.now().microsecondsSinceEpoch - event.timestampUs;
    if (us < 0 || us > 500000) return null;
    return us / 1000.0;
  }

  @visibleForTesting
  int get sequence => _sequence;

  Future<void> dispose() => stop();
}
