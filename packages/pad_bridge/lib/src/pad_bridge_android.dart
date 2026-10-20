import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pad_core/pad_core.dart';

/// Pont vers le plugin Android.
///
/// Toutes les méthodes sont sûres : si le natif n'est pas disponible (test,
/// web, desktop), on renvoie une liste vide ou `null` plutôt que de lever.
class PadBridgeAndroid {
  PadBridgeAndroid({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _method = methodChannel ?? const MethodChannel('padlab/bridge'),
      _events = eventChannel ?? const EventChannel('padlab/events');

  final MethodChannel _method;
  final EventChannel _events;

  StreamController<PadBridgeEvent>? _controller;
  StreamController<void>? _deviceChanges;
  StreamSubscription<dynamic>? _subscription;

  /// Nombre d'abonnés sur les deux flux.
  ///
  /// Le canal natif ne doit s'arrêter que lorsque **plus personne** n'écoute :
  /// sinon couper la capture des entrées tuerait aussi la veille des
  /// branchements, et une manette rebranchée ne serait plus jamais vue.
  int _refCount = 0;

  void _listen() {
    _refCount++;
    if (_subscription == null) _start();
  }

  void _unlisten() {
    _refCount--;
    if (_refCount <= 0) {
      _refCount = 0;
      unawaited(_stop());
    }
  }

  /// Événements natifs décodés, un par changement.
  Stream<PadBridgeEvent> get events {
    _controller ??= StreamController<PadBridgeEvent>.broadcast(
      onListen: _listen,
      onCancel: _unlisten,
    );
    return _controller!.stream;
  }

  /// Émis quand une manette est branchée/débranchée (côté natif).
  Stream<void> get deviceChanges {
    _deviceChanges ??= StreamController<void>.broadcast(
      onListen: _listen,
      onCancel: _unlisten,
    );
    return _deviceChanges!.stream;
  }

  void _start() {
    _subscription?.cancel();
    _subscription = _events.receiveBroadcastStream().listen(
      (dynamic payload) {
        if (payload is! List) return;
        for (final raw in payload) {
          if (raw is! Map) continue;
          if (raw['type'] == 'devicesChanged') {
            if (!(_deviceChanges?.isClosed ?? true)) _deviceChanges!.add(null);
            continue;
          }
          final event = _decode(raw);
          if (event != null) _controller?.add(event);
        }
      },
      onError: (Object error) {
        _controller?.addError(error);
      },
    );
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<List<PadDevice>> listDevices() async {
    try {
      final raw = await _method.invokeMethod<List<Object?>>('listDevices');
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map) PadDevice.fromJson(item),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<PadDevice?> capabilities(int deviceId) async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>(
        'capabilities',
        {'deviceId': deviceId},
      );
      if (raw == null) return null;
      return PadDevice.fromJson(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<BatteryReading?> battery(int deviceId) async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>(
        'battery',
        {'deviceId': deviceId},
      );
      if (raw == null) return null;
      final percent = (raw['percent'] as num?)?.toDouble();
      return BatteryReading(
        at: DateTime.now(),
        status: BatteryStatus.values.firstWhere(
          (s) => s.name == raw['status'],
          orElse: () => BatteryStatus.unknown,
        ),
        percent: percent,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> vibrate({
    required int deviceId,
    double strong = 1.0,
    double weak = 1.0,
    int durationMs = 300,
  }) async {
    try {
      return await _method.invokeMethod<bool>('vibrate', {
            'deviceId': deviceId,
            'strong': strong,
            'weak': weak,
            'durationMs': durationMs,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> stopVibration(int deviceId) async {
    try {
      await _method.invokeMethod<void>('stopVibration', {'deviceId': deviceId});
    } on PlatformException {
      // ignoré
    } on MissingPluginException {
      // ignoré
    }
  }

  Future<Map<String, Object?>> platformInfo() async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>('platformInfo');
      return raw?.cast<String, Object?>() ?? const {};
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  PadBridgeEvent? _decode(Map<Object?, Object?> raw) {
    final type = raw['type'] as String?;
    final timestampUs = (raw['timestampUs'] as num?)?.toInt() ?? 0;
    final deviceId = (raw['deviceId'] as num?)?.toInt() ?? 0;
    final code = (raw['code'] as num?)?.toInt() ?? 0;

    switch (type) {
      case 'buttonDown':
      case 'buttonUp':
        final index = (raw['buttonIndex'] as num?)?.toInt();
        if (index == null || index < 0 || index >= PadButton.values.length) {
          return null;
        }
        return PadBridgeEvent(
          type: type == 'buttonDown' ? PadEventType.buttonDown : PadEventType.buttonUp,
          timestampUs: timestampUs,
          deviceId: deviceId,
          code: code,
          button: PadButton.values[index],
        );
      case 'axis':
        final axisName = raw['axis'] as String?;
        final axis = PadAxis.values.where((a) => a.name == axisName).firstOrNull;
        if (axis == null) return null;
        return PadBridgeEvent(
          type: PadEventType.axis,
          timestampUs: timestampUs,
          deviceId: deviceId,
          code: code,
          axis: axis,
          value: (raw['value'] as num?)?.toDouble() ?? 0,
          rawValue: (raw['rawValue'] as num?)?.toDouble(),
        );
      default:
        return null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
    await _deviceChanges?.close();
    _deviceChanges = null;
  }
}

class PadBridgeEvent {
  const PadBridgeEvent({
    required this.type,
    required this.timestampUs,
    required this.deviceId,
    this.button,
    this.axis,
    this.value = 0,
    this.rawValue,
    this.code = 0,
  });

  final PadEventType type;
  final int timestampUs;
  final int deviceId;
  final PadButton? button;
  final PadAxis? axis;
  final double value;
  final double? rawValue;
  final int code;

  /// Applique l'événement à un état existant.
  PadState applyTo(PadState state, int sequence) {
    if (type == PadEventType.buttonDown || type == PadEventType.buttonUp) {
      return state.merge(
        pressedButton: button,
        isDown: type == PadEventType.buttonDown,
        timestampUs: timestampUs,
        sequence: sequence,
      );
    }
    return state.merge(
      axis: axis,
      value: value,
      rawValue: rawValue,
      timestampUs: timestampUs,
      sequence: sequence,
    );
  }
}
