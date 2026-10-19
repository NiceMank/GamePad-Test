import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pad_core/pad_core.dart';
import 'package:pclink/src/link_server.dart';

void main() {
  test('paquet d\'état : encodage/décodage stable', () {
    const state = PadState(
      pressed: {PadButton.a, PadButton.l2},
      axes: {
        PadAxis.leftX: 0.5,
        PadAxis.leftY: -0.25,
        PadAxis.rightX: 1,
        PadAxis.rightY: -1,
        PadAxis.leftTrigger: 0.5,
        PadAxis.rightTrigger: 1,
      },
      timestampUs: 123456,
    );
    final packet = LinkStatePacket.fromPadState(state, token: 4242, sequence: 7);
    final bytes = packet.encode();
    expect(bytes.length, LinkProtocol.statePacketSize);

    final decoded = LinkStatePacket.decode(bytes);
    expect(decoded.token, 4242);
    expect(decoded.sequence, 7);
    expect(decoded.toPadState().pressed, state.pressed);
    expect(decoded.leftX, closeTo(0.5, 0.001));
    expect(decoded.leftTrigger, closeTo(0.5, 0.001));
  });

  test('le serveur ignore un mauvais code puis accepte le bon', () async {
    final received = <PadState>[];
    final server = LinkServer(
      port: 0,
      pairingCode: 1234,
      onState: (state, _) => received.add(state),
      onLog: (_) {},
    );
    expect(await server.start(), isTrue);
    addTearDown(server.stop);

    final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(socket.close);
    final address = InternetAddress.loopbackIPv4;
    final port = server.udpPort;

    Uint8List hello(int token) {
      final data = ByteData(LinkProtocol.pingPacketSize);
      for (var i = 0; i < 4; i++) {
        data.setUint8(i, LinkProtocol.magic[i]);
      }
      data.setUint8(4, LinkProtocol.version);
      data.setUint8(5, LinkProtocol.typeHello);
      data.setUint16(6, token, Endian.little);
      return data.buffer.asUint8List();
    }

    // Mauvais code : aucun état ne doit passer.
    socket.send(hello(9999), address, port);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    socket.send(
      LinkStatePacket.fromPadState(
        const PadState(pressed: {PadButton.a}),
        token: 9999,
        sequence: 1,
      ).encode(),
      address,
      port,
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(received, isEmpty);
    expect(server.paired, isFalse);

    // Bon code : l'état passe.
    socket.send(hello(1234), address, port);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(server.paired, isTrue);

    for (var i = 1; i <= 5; i++) {
      socket.send(
        LinkStatePacket.fromPadState(
          PadState(pressed: {PadButton.a}, timestampUs: i * 1000),
          token: 1234,
          sequence: i,
        ).encode(),
        address,
        port,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(received, isNotEmpty);
    expect(received.last.isPressed(PadButton.a), isTrue);
    expect(server.stats.packets, 5);
    expect(server.stats.lost, 0);
  });

  test('les pertes de séquence sont comptées', () async {
    final server = LinkServer(port: 0, pairingCode: 1000, onLog: (_) {});
    await server.start();
    addTearDown(server.stop);

    final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(socket.close);

    final hello = ByteData(LinkProtocol.pingPacketSize);
    for (var i = 0; i < 4; i++) {
      hello.setUint8(i, LinkProtocol.magic[i]);
    }
    hello.setUint8(4, LinkProtocol.version);
    hello.setUint8(5, LinkProtocol.typeHello);
    hello.setUint16(6, 1000, Endian.little);
    socket.send(hello.buffer.asUint8List(), InternetAddress.loopbackIPv4, server.udpPort);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    for (final sequence in [1, 2, 5]) {
      socket.send(
        LinkStatePacket.fromPadState(
          PadState.idle,
          token: 1000,
          sequence: sequence,
        ).encode(),
        InternetAddress.loopbackIPv4,
        server.udpPort,
      );
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    // 3 → 5 : les séquences 3 et 4 manquent.
    expect(server.stats.lost, 2);
    expect(server.stats.packets, 3);
  });
}
