import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pad_core/pad_core.dart';

/// Statistiques de liaison, mises à jour à chaque paquet.
class LinkStats {
  int packets = 0;
  int lost = 0;
  int duplicates = 0;
  int outOfOrder = 0;
  double jitterMs = 0;
  double packetsPerSecond = 0;
  int? lastSequence;
  int? batteryPercent;
  BatteryStatus batteryStatus = BatteryStatus.unknown;
  DateTime? lastPacketAt;
  DateTime? pairedAt;
  String? remote;

  int _windowCount = 0;
  DateTime _windowStart = DateTime.now();

  Duration? get age => lastPacketAt == null
      ? null
      : DateTime.now().difference(lastPacketAt!);

  bool get streaming =>
      lastPacketAt != null && DateTime.now().difference(lastPacketAt!) < const Duration(seconds: 2);

  void reset() {
    packets = 0;
    lost = 0;
    duplicates = 0;
    outOfOrder = 0;
    jitterMs = 0;
    packetsPerSecond = 0;
    lastSequence = null;
    lastPacketAt = null;
    pairedAt = null;
  }

  void accountSequence(int sequence, int timestampUs, DateTime arrival) {
    final previous = lastSequence;
    if (previous != null) {
      final delta = (sequence - previous) & 0xFFFF;
      if (delta == 0) {
        duplicates++;
        return;
      }
      if (delta < 0x8000) {
        if (delta > 1) lost += delta - 1;
      } else {
        outOfOrder++;
        return;
      }
    }
    lastSequence = sequence;
    lastPacketAt = arrival;
    packets++;
    _windowCount++;

    final elapsed = arrival.difference(_windowStart);
    if (elapsed.inMilliseconds >= 1000) {
      packetsPerSecond = _windowCount * 1000 / elapsed.inMilliseconds;
      _windowCount = 0;
      _windowStart = arrival;
    }
  }

  /// Jitter RFC 3550 simplifié, calculé sur les écarts d'arrivée.
  void accountJitter(Duration arrivalDelta, int timestampDeltaUs) {
    final transit = arrivalDelta.inMicroseconds - timestampDeltaUs;
    jitterMs += ((transit / 1000.0).abs() - jitterMs) / 16.0;
  }
}

/// Serveur PadLab Link : reçoit l'état d'une manette Android et le pousse vers
/// une manette virtuelle Xbox.
///
/// - UDP 47833 : paquets d'état (priorité latence, ~250–1000 Hz).
/// - TCP 47834 : secours quand l'UDP est filtré (même format, préfixé d'une
///   longueur 16 bits).
/// - Appairage : les paquets d'état doivent porter le code affiché.
class LinkServer {
  LinkServer({
    this.port = 47833,
    this.requirePairing = true,
    this.onState,
    this.onLog,
    int? pairingCode,
  }) : pairingCode = pairingCode ?? (1000 + math.Random().nextInt(9000));

  final int port;
  final bool requirePairing;
  void Function(PadState state, LinkStatePacket packet)? onState;
  final void Function(String message)? onLog;

  final int pairingCode;
  final LinkStats stats = LinkStats();

  RawDatagramSocket? _udp;
  ServerSocket? _tcp;
  final List<Socket> _tcpClients = [];
  bool _paired = false;
  int? _pairedToken;

  bool get running => _udp != null;
  bool get paired => _paired;

  /// Port UDP réellement utilisé (utile quand [port] vaut 0 en test).
  int get udpPort => _udp?.port ?? port;

  /// Port TCP réellement utilisé, 0 si indisponible.
  int get tcpPort => _tcp?.port ?? 0;

  Future<bool> start() async {
    if (_udp != null) return true;
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      udp.broadcastEnabled = true;
      udp.listen(_handleUdpEvent);
      _udp = udp;

      if (port == 0) {
        _log('Port éphémère : secours TCP désactivé en test.');
        return true;
      }
      try {
        _tcp = await ServerSocket.bind(InternetAddress.anyIPv4, port + 1);
        _tcp!.listen(_handleTcpClient, onError: (Object e) => _log('TCP: $e'));
      } on SocketException catch (e) {
        _log('TCP indisponible : ${e.message}');
      }

      _log('Écoute UDP $udpPort · TCP ${port + 1} · code ${pairingCode.toString().padLeft(4, '0')}');
      return true;
    } on SocketException catch (e) {
      _log('Impossible d\'écouter sur le port $port : ${e.message}');
      return false;
    }
  }

  void stop() {
    _udp?.close();
    _udp = null;
    _tcp?.close();
    _tcp = null;
    for (final socket in _tcpClients) {
      socket.destroy();
    }
    _tcpClients.clear();
    _paired = false;
    _pairedToken = null;
  }

  /// Réinitialise l'appairage (bouton « Oublier la manette »).
  void unpair() {
    _paired = false;
    _pairedToken = null;
    stats.reset();
    _log('Appairage réinitialisé');
  }

  // --- UDP -----------------------------------------------------------------

  void _handleUdpEvent(RawSocketEvent event) {
    final socket = _udp;
    if (socket == null || event != RawSocketEvent.read) return;
    Datagram? datagram;
    while ((datagram = socket.receive()) != null) {
      _handlePacket(datagram!.data, datagram.address, datagram.port, _replyUdp);
    }
  }

  void _replyUdp(Uint8List bytes, InternetAddress address, int port) {
    _udp?.send(bytes, address, port);
  }

  // --- TCP -----------------------------------------------------------------

  void _handleTcpClient(Socket socket) {
    _tcpClients.add(socket);
    final pending = <int>[];
    socket.listen(
      (List<int> data) {
        pending.addAll(data);
        var consumed = 0;
        while (pending.length - consumed >= 2) {
          final length = pending[consumed] | (pending[consumed + 1] << 8);
          if (pending.length - consumed - 2 < length) break;
          final frame = Uint8List.fromList(
            pending.sublist(consumed + 2, consumed + 2 + length),
          );
          _handlePacket(
            frame,
            socket.remoteAddress,
            socket.remotePort,
            (reply, _, _) => socket.add(_frame(reply)),
            isTcp: true,
          );
          consumed += 2 + length;
        }
        if (consumed > 0) pending.removeRange(0, consumed);
      },
      onDone: () => _tcpClients.remove(socket),
      onError: (Object _) {
        _tcpClients.remove(socket);
        socket.destroy();
      },
    );
  }

  static Uint8List _frame(Uint8List payload) {
    final data = ByteData(payload.length + 2)
      ..setUint16(0, payload.length, Endian.little);
    data.buffer.asUint8List().setRange(2, payload.length + 2, payload);
    return data.buffer.asUint8List();
  }

  // --- traitement ----------------------------------------------------------

  void _handlePacket(
    Uint8List bytes,
    InternetAddress address,
    int sourcePort,
    void Function(Uint8List bytes, InternetAddress address, int port) reply, {
    bool isTcp = false,
  }) {
    if (bytes.length < LinkProtocol.pingPacketSize) return;
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != LinkProtocol.magic[i]) return;
    }
    if (bytes[4] != LinkProtocol.version) return;

    final type = bytes[5];
    final token = bytes[6] | (bytes[7] << 8);
    final arrival = DateTime.now();

    switch (type) {
      case LinkProtocol.typeHello:
        if (token == pairingCode) {
          _paired = true;
          _pairedToken = token;
          stats.pairedAt = arrival;
          stats.remote = '${address.address}:$sourcePort';
          _log('Manette appairée depuis ${stats.remote}');
        } else {
          _log('Code d\'appairage refusé ($token)');
        }
        reply(_pong(token, 0, LinkProtocol.typePong), address, sourcePort);

      case LinkProtocol.typePing:
        final clientTimeUs = ByteData.sublistView(bytes).getUint32(8, Endian.little);
        reply(_pong(token, clientTimeUs, LinkProtocol.typePong), address, sourcePort);

      case LinkProtocol.typeState:
        if (requirePairing && !_paired) return;
        if (_pairedToken != null && token != _pairedToken) return;
        if (bytes.length < LinkProtocol.statePacketSize) return;

        final packet = LinkStatePacket.decode(bytes);
        final previousArrival = stats.lastPacketAt;
        final previousTimestamp = _lastTimestampUs;
        if (previousArrival != null && previousTimestamp != null) {
          final seqDelta = (packet.sequence - (stats.lastSequence ?? 0)) & 0xFFFF;
          if (seqDelta > 0 && seqDelta < 0x8000) {
            stats.accountJitter(
              arrival.difference(previousArrival),
              packet.timestampUs - previousTimestamp,
            );
          }
        }
        stats.accountSequence(packet.sequence, packet.timestampUs, arrival);
        stats.batteryPercent = packet.batteryPercent;
        stats.batteryStatus = packet.batteryStatus;
        _lastTimestampUs = packet.timestampUs;
        onState?.call(packet.toPadState(), packet);
    }
  }

  int? _lastTimestampUs;

  static Uint8List _pong(int token, int clientTimeUs, int type) {
    final data = ByteData(LinkProtocol.pingPacketSize);
    for (var i = 0; i < 4; i++) {
      data.setUint8(i, LinkProtocol.magic[i]);
    }
    data.setUint8(4, LinkProtocol.version);
    data.setUint8(5, type);
    data.setUint16(6, token, Endian.little);
    data.setUint32(8, clientTimeUs & 0xFFFFFFFF, Endian.little);
    return data.buffer.asUint8List();
  }

  void _log(String message) => onLog?.call(message);
}
