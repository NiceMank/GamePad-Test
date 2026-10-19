import 'dart:typed_data';

import '../models/battery.dart';
import '../models/pad_axis.dart';
import '../models/pad_button.dart';
import '../models/pad_state.dart';

/// Protocole binaire PadLab Link (mobile → PC).
///
/// Format figé, identique côté C# et Dart :
///   magic 4 | version 1 | type 1 | token 2 | payload
/// Les paquets d'état sont **absolus** (pas de deltas) : une perte UDP ne
/// désynchronise jamais la manette virtuelle.
class LinkProtocol {
  static const List<int> magic = [0x50, 0x4C, 0x4B, 0x31]; // "PLK1"
  static const int version = 1;

  static const int typeState = 1;
  static const int typePing = 2;
  static const int typePong = 3;
  static const int typeHello = 4;

  static const int statePacketSize = 32;
  static const int pingPacketSize = 16;

  static int encodeBatteryFlag(BatteryStatus status) => status.index & 0x0F;
  static BatteryStatus decodeBatteryFlag(int raw) =>
      BatteryStatus.values[raw & 0x0F];
}

class LinkStatePacket {
  const LinkStatePacket({
    required this.token,
    required this.sequence,
    required this.timestampUs,
    required this.buttons,
    required this.leftX,
    required this.leftY,
    required this.rightX,
    required this.rightY,
    required this.leftTrigger,
    required this.rightTrigger,
    this.batteryPercent = 0xFF,
    this.batteryStatus = BatteryStatus.unknown,
  });

  final int token;
  final int sequence;
  final int timestampUs;
  final int buttons;
  final double leftX;
  final double leftY;
  final double rightX;
  final double rightY;
  final double leftTrigger;
  final double rightTrigger;

  /// 0xFF = non exposé.
  final int batteryPercent;
  final BatteryStatus batteryStatus;

  factory LinkStatePacket.fromPadState(
    PadState state, {
    required int token,
    required int sequence,
    int batteryPercent = 0xFF,
    BatteryStatus batteryStatus = BatteryStatus.unknown,
  }) {
    var buttons = 0;
    for (final b in state.pressed) {
      buttons |= padButtonBit(b);
    }
    return LinkStatePacket(
      token: token,
      sequence: sequence & 0xFFFF,
      timestampUs: state.timestampUs & 0xFFFFFFFF,
      buttons: buttons,
      leftX: state.axis(PadAxis.leftX),
      leftY: state.axis(PadAxis.leftY),
      rightX: state.axis(PadAxis.rightX),
      rightY: state.axis(PadAxis.rightY),
      leftTrigger: state.axis(PadAxis.leftTrigger),
      rightTrigger: state.axis(PadAxis.rightTrigger),
      batteryPercent: batteryPercent,
      batteryStatus: batteryStatus,
    );
  }

  PadState toPadState() {
    final pressed = <PadButton>{
      for (final b in PadButton.values)
        if (buttons & padButtonBit(b) != 0) b,
    };
    return PadState(
      pressed: pressed,
      axes: {
        PadAxis.leftX: leftX,
        PadAxis.leftY: leftY,
        PadAxis.rightX: rightX,
        PadAxis.rightY: rightY,
        PadAxis.leftTrigger: leftTrigger,
        PadAxis.rightTrigger: rightTrigger,
      },
      rawAxes: const {},
      timestampUs: timestampUs,
      sequence: sequence,
    );
  }

  Uint8List encode() {
    final data = ByteData(LinkProtocol.statePacketSize);
    for (var i = 0; i < 4; i++) {
      data.setUint8(i, LinkProtocol.magic[i]);
    }
    data.setUint8(4, LinkProtocol.version);
    data.setUint8(5, LinkProtocol.typeState);
    data.setUint16(6, token, Endian.little);
    data.setUint16(8, sequence, Endian.little);
    data.setUint32(10, timestampUs, Endian.little);
    data.setUint32(14, buttons, Endian.little);
    data.setInt16(18, _toI16(leftX), Endian.little);
    data.setInt16(20, _toI16(leftY), Endian.little);
    data.setInt16(22, _toI16(rightX), Endian.little);
    data.setInt16(24, _toI16(rightY), Endian.little);
    data.setUint16(26, _toU16(leftTrigger), Endian.little);
    data.setUint16(28, _toU16(rightTrigger), Endian.little);
    data.setUint8(30, batteryPercent);
    data.setUint8(31, LinkProtocol.encodeBatteryFlag(batteryStatus));
    return data.buffer.asUint8List();
  }

  static LinkStatePacket decode(Uint8List bytes) {
    if (bytes.lengthInBytes < LinkProtocol.statePacketSize) {
      throw const FormatException('Paquet d\'état trop court');
    }
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < 4; i++) {
      if (data.getUint8(i) != LinkProtocol.magic[i]) {
        throw const FormatException('Magic invalide');
      }
    }
    if (data.getUint8(4) != LinkProtocol.version) {
      throw const FormatException('Version de protocole non supportée');
    }
    if (data.getUint8(5) != LinkProtocol.typeState) {
      throw const FormatException('Type de paquet inattendu');
    }
    return LinkStatePacket(
      token: data.getUint16(6, Endian.little),
      sequence: data.getUint16(8, Endian.little),
      timestampUs: data.getUint32(10, Endian.little),
      buttons: data.getUint32(14, Endian.little),
      leftX: data.getInt16(18, Endian.little) / 32767.0,
      leftY: data.getInt16(20, Endian.little) / 32767.0,
      rightX: data.getInt16(22, Endian.little) / 32767.0,
      rightY: data.getInt16(24, Endian.little) / 32767.0,
      leftTrigger: data.getUint16(26, Endian.little) / 65535.0,
      rightTrigger: data.getUint16(28, Endian.little) / 65535.0,
      batteryPercent: data.getUint8(30),
      batteryStatus: LinkProtocol.decodeBatteryFlag(data.getUint8(31)),
    );
  }

  static int _toI16(double value) => (value.clamp(-1.0, 1.0) * 32767).round();
  static int _toU16(double value) => (value.clamp(0.0, 1.0) * 65535).round();
}

/// Ping/pong pour mesurer le RTT et le jitter affichés dans PadLab Link.
class LinkPingPacket {
  const LinkPingPacket({
    required this.token,
    required this.clientTimeUs,
    this.type = LinkProtocol.typePing,
  });

  final int token;
  final int clientTimeUs;
  final int type;

  Uint8List encode() {
    final data = ByteData(LinkProtocol.pingPacketSize);
    for (var i = 0; i < 4; i++) {
      data.setUint8(i, LinkProtocol.magic[i]);
    }
    data.setUint8(4, LinkProtocol.version);
    data.setUint8(5, type);
    data.setUint16(6, token, Endian.little);
    data.setUint32(8, clientTimeUs & 0xFFFFFFFF, Endian.little);
    // 2 octets de réserve pour rester alignés sur 16 octets.
    data.setUint16(12, 0, Endian.little);
    data.setUint16(14, 0, Endian.little);
    return data.buffer.asUint8List();
  }

  static LinkPingPacket decode(Uint8List bytes) {
    if (bytes.lengthInBytes < LinkProtocol.pingPacketSize) {
      throw const FormatException('Paquet ping trop court');
    }
    final data = ByteData.sublistView(bytes);
    return LinkPingPacket(
      token: data.getUint16(6, Endian.little),
      clientTimeUs: data.getUint32(8, Endian.little),
      type: data.getUint8(5),
    );
  }
}
