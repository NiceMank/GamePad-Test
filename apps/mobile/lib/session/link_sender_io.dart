import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pad_core/pad_core.dart';

import 'link_sender_base.dart';

/// Envoie l'état de la manette à PadLab Link (PC) en UDP.
///
/// Débit cible : 250 Hz. Les trames sont **coalescées** : si le téléphone
/// produit 1000 états par seconde, seul le dernier compte, ce qui évite de
/// saturer le Wi-Fi sans ajouter de latence perceptible.
class LinkSenderIo implements LinkSender {
  LinkSenderIo({this.maxHz = 250});

  final int maxHz;

  RawDatagramSocket? _socket;
  InternetAddress? _address;
  int _port = 47833;
  int _code = 0;
  Timer? _sendTimer;
  Timer? _pingTimer;
  int _sequence = 0;
  int _sent = 0;
  int _rttUs = 0;
  int _pingedAtUs = 0;
  bool _pending = false;
  PadState _latest = PadState.idle;
  String? _error;

  @override
  bool get supported => true;
  @override
  bool get running => _socket != null;
  @override
  int get sent => _sent;
  @override
  int get rttUs => _rttUs;
  @override
  String? get error => _error;
  @override
  String? get remote => _address == null ? null : '${_address!.address}:$_port';

  /// État à diffuser (appelé par la session à chaque nouvelle trame).
  @override
  void push(PadState state) => _latest = state;

  @override
  Future<bool> start({
    required String host,
    int port = 47833,
    required int code,
  }) async {
    stop();
    _error = null;
    _port = port;
    _code = code & 0xFFFF;
    try {
      final address = InternetAddress.tryParse(host) ??
          (await InternetAddress.lookup(host)).firstOrNull;
      if (address == null) {
        _error = 'Adresse introuvable : $host';
        return false;
      }
      _address = address;
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram != null) _onData(datagram.data);
      });
      _socket = socket;

      // Bonjour immédiat : le PC sait tout de suite qui parle.
      final hello = ByteData(LinkProtocol.pingPacketSize)
        ..setUint8(0, LinkProtocol.magic[0])
        ..setUint8(1, LinkProtocol.magic[1])
        ..setUint8(2, LinkProtocol.magic[2])
        ..setUint8(3, LinkProtocol.magic[3])
        ..setUint8(4, LinkProtocol.version)
        ..setUint8(5, LinkProtocol.typeHello)
        ..setUint16(6, _code, Endian.little);
      _send(hello.buffer.asUint8List());

      final periodMs = (1000 / maxHz).floor().clamp(1, 1000);
      _sendTimer = Timer.periodic(Duration(milliseconds: periodMs), (_) => _tick());
      _pingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _ping());
      return true;
    } on SocketException catch (e) {
      _error = 'Socket : ${e.message}';
      return false;
    }
  }

  void _tick() {
    if (!_pending) return;
    _pending = false;
    final state = _latest;
    _sequence = (_sequence + 1) & 0xFFFF;
    final packet = LinkStatePacket.fromPadState(
      state,
      token: _code,
      sequence: _sequence,
    );
    _send(packet.encode());
  }

  void _ping() {
    _pingedAtUs = DateTime.now().microsecondsSinceEpoch;
    final data = ByteData(LinkProtocol.pingPacketSize);
    for (var i = 0; i < 4; i++) {
      data.setUint8(i, LinkProtocol.magic[i]);
    }
    data.setUint8(4, LinkProtocol.version);
    data.setUint8(5, LinkProtocol.typePing);
    data.setUint16(6, _code, Endian.little);
    data.setUint32(8, _pingedAtUs & 0xFFFFFFFF, Endian.little);
    _send(data.buffer.asUint8List());
  }

  void _onData(Uint8List bytes) {
    if (bytes.length < LinkProtocol.pingPacketSize) return;
    if (bytes[5] != LinkProtocol.typePong) return;
    final sentAt = ByteData.sublistView(bytes).getUint32(8, Endian.little);
    if (sentAt != (_pingedAtUs & 0xFFFFFFFF)) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    _rttUs = now - _pingedAtUs;
  }

  void _send(Uint8List bytes) {
    final socket = _socket;
    final address = _address;
    if (socket == null || address == null) return;
    socket.send(bytes, address, _port);
    _sent++;
  }

  @override
  void stop() {
    _sendTimer?.cancel();
    _sendTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _socket?.close();
    _socket = null;
    _address = null;
    _pending = false;
    _sent = 0;
    _rttUs = 0;
  }

  /// Marque une nouvelle trame disponible (coalescence).
  @override
  void markDirty() => _pending = true;
}

LinkSender createLinkSender() => LinkSenderIo();
