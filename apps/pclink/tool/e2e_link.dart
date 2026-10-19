// Test de bout en bout du relais : un faux téléphone envoie 30 états,
// le PC les reçoit et les écrit dans la manette virtuelle.
//
//   sudo dart run tool/e2e_link.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pad_core/pad_core.dart';
import 'package:pclink/src/backends/linux_uinput.dart';
import 'package:pclink/src/link_server.dart';

Future<void> main() async {
  const code = 4321;
  final pad = LinuxUinputPad();
  await pad.start();
  stdout.writeln('sortie=${pad.backend} (${pad.detail})');

  final received = <int>[];
  final server = LinkServer(
    port: 47833,
    pairingCode: code,
    onState: (state, packet) {
      received.add(packet.sequence);
      pad.submit(state);
    },
    onLog: (m) => stdout.writeln('PC  $m'),
  );
  await server.start();

  final client = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final hello = ByteData(LinkProtocol.pingPacketSize);
  for (var i = 0; i < 4; i++) {
    hello.setUint8(i, LinkProtocol.magic[i]);
  }
  hello.setUint8(4, LinkProtocol.version);
  hello.setUint8(5, LinkProtocol.typeHello);
  hello.setUint16(6, code, Endian.little);
  client.send(hello.buffer.asUint8List(), InternetAddress.loopbackIPv4, server.udpPort);
  await Future<void>.delayed(const Duration(milliseconds: 50));

  final watch = Stopwatch()..start();
  for (var i = 1; i <= 30; i++) {
    final state = PadState(
      pressed: {if (i.isEven) PadButton.a},
      axes: {PadAxis.leftX: (i / 30) * 2 - 1, PadAxis.leftTrigger: i / 30},
      timestampUs: i * 4000,
      sequence: i,
    );
    client.send(
      LinkStatePacket.fromPadState(state, token: code, sequence: i).encode(),
      InternetAddress.loopbackIPv4,
      server.udpPort,
    );
    await Future<void>.delayed(const Duration(milliseconds: 4));
  }
  await Future<void>.delayed(const Duration(milliseconds: 200));

  stdout.writeln('reçus=${received.length}/30 en ${watch.elapsedMilliseconds} ms');
  stdout.writeln('appairé=${server.paired} perte=${server.stats.lost} '
      'pps=${server.stats.packetsPerSecond.toStringAsFixed(0)} '
      'jitter=${server.stats.jitterMs.toStringAsFixed(2)} ms');

  client.close();
  server.stop();
  await pad.stop();
  exit(received.length == 30 ? 0 : 1);
}
