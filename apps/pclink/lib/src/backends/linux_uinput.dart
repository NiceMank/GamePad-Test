import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:pad_core/pad_core.dart';

import '../mapping.dart';
import '../virtual_pad.dart';

// --- structures noyau (linux/input.h, x86_64/aarch64) ---------------------

final class _InputId extends Struct {
  @Uint16()
  external int bustype;
  @Uint16()
  external int vendor;
  @Uint16()
  external int product;
  @Uint16()
  external int version;
}

final class _UinputSetup extends Struct {
  external _InputId id;
  @Array(80)
  external Array<Uint8> name;
  @Uint32()
  external int ffEffectsMax;
}

final class _Timeval extends Struct {
  @Int64()
  external int sec;
  @Int64()
  external int usec;
}

final class _InputEvent extends Struct {
  external _Timeval time;
  @Uint16()
  external int type;
  @Uint16()
  external int code;
  @Int32()
  external int value;
}

final class _AbsInfo extends Struct {
  @Int32()
  external int value;
  @Int32()
  external int minimum;
  @Int32()
  external int maximum;
  @Int32()
  external int fuzz;
  @Int32()
  external int flat;
  @Int32()
  external int resolution;
}

// --- FFI -------------------------------------------------------------------

typedef _OpenNative = Int32 Function(Pointer<Utf8> path, Int32 flags);
typedef _OpenDart = int Function(Pointer<Utf8> path, int flags);

typedef _IoctlNative = Int32 Function(Int32 fd, Uint64 request, Pointer<Void> arg);
typedef _IoctlDart = int Function(int fd, int request, Pointer<Void> arg);

typedef _WriteNative = IntPtr Function(Int32 fd, Pointer<Void> buf, IntPtr count);
typedef _WriteDart = int Function(int fd, Pointer<Void> buf, int count);

typedef _CloseNative = Int32 Function(Int32 fd);
typedef _CloseDart = int Function(int fd);

abstract final class _Ioctl {
  static const setEvBit = 0x40045564;
  static const setKeyBit = 0x40045565;
  static const setAbsBit = 0x40045567;
  static const devSetup = 0x405C5503;
  static const devCreate = 0x5501;
  static const devDestroy = 0x5502;

  /// EVIOCSABS(axis) = _IOW('E', 0xC0 + axis, struct input_absinfo)
  static int setAbsInfo(int axis) => 0x401845C0 | (axis & 0x3F);
}

/// Manette Xbox 360 virtuelle via `/dev/uinput`.
///
/// Aucun driver à installer sur Linux : le noyau expose la manette comme un
/// périphérique evdev standard, reconnu par SDL, Proton, Steam, etc.
class LinuxUinputPad implements VirtualPad {
  int _fd = -1;
  final EvdevEncoder _encoder = EvdevEncoder();
  Pointer<_InputEvent> _event = nullptr;
  Pointer<_UinputSetup> _setup = nullptr;
  String _detail = 'non initialisé';

  @override
  String get backend => 'uinput';

  @override
  bool get ready => _fd >= 0;

  @override
  String get detail => _detail;

  @override
  Future<bool> start() async {
    if (_fd >= 0) return true;

    final libc = DynamicLibrary.process();
    final open = libc.lookupFunction<_OpenNative, _OpenDart>('open');
    final ioctl = libc.lookupFunction<_IoctlNative, _IoctlDart>('ioctl');

    const flags = 0x0001 | 0x0800; // O_WRONLY | O_NONBLOCK
    var fd = -1;
    for (final path in ['/dev/uinput', '/dev/input/uinput']) {
      final native = path.toNativeUtf8();
      fd = open(native, flags);
      malloc.free(native);
      if (fd >= 0) break;
    }
    if (fd < 0) {
      _detail = '/dev/uinput inaccessible (ajoutez votre utilisateur au groupe '
          '"input" ou chargez le module uinput).';
      return false;
    }

    void setBit(int request, int bit) {
      final ptr = calloc<Uint32>();
      ptr.value = bit;
      ioctl(fd, request, ptr.cast());
      calloc.free(ptr);
    }

    setBit(_Ioctl.setEvBit, Evdev.evKey);
    setBit(_Ioctl.setEvBit, Evdev.evAbs);
    setBit(_Ioctl.setEvBit, Evdev.evSyn);
    for (final code in EvdevEncoder.keyCodes) {
      setBit(_Ioctl.setKeyBit, code);
    }

    // Plages : sticks -32768..32767, gâchettes 0..255, croix -1..1.
    final axes = <int, List<int>>{
      Evdev.absX: [-32768, 32767],
      Evdev.absY: [-32768, 32767],
      Evdev.absRx: [-32768, 32767],
      Evdev.absRy: [-32768, 32767],
      Evdev.absZ: [0, 255],
      Evdev.absRz: [0, 255],
      Evdev.absHat0X: [-1, 1],
      Evdev.absHat0Y: [-1, 1],
    };

    final absInfo = calloc<_AbsInfo>();
    for (final entry in axes.entries) {
      setBit(_Ioctl.setAbsBit, entry.key);
      absInfo.ref.minimum = entry.value[0];
      absInfo.ref.maximum = entry.value[1];
      absInfo.ref.fuzz = 0;
      absInfo.ref.flat = 0;
      absInfo.ref.resolution = 0;
      ioctl(fd, _Ioctl.setAbsInfo(entry.key), absInfo.cast());
    }
    calloc.free(absInfo);

    _setup = calloc<_UinputSetup>();
    _setup.ref.id.bustype = 0x03; // BUS_USB
    _setup.ref.id.vendor = 0x045E; // Microsoft
    _setup.ref.id.product = 0x028E; // Xbox 360 Controller
    _setup.ref.id.version = 0x0114;
    final name = utf8.encode('PadLab Virtual Xbox 360 Controller');
    for (var i = 0; i < name.length && i < 80; i++) {
      _setup.ref.name[i] = name[i];
    }
    if (ioctl(fd, _Ioctl.devSetup, _setup.cast()) < 0) {
      _detail = 'UI_DEV_SETUP refusé par le noyau.';
      calloc.free(_setup);
      _setup = nullptr;
      return false;
    }
    if (ioctl(fd, _Ioctl.devCreate, nullptr) < 0) {
      _detail = 'UI_DEV_CREATE refusé.';
      calloc.free(_setup);
      _setup = nullptr;
      return false;
    }

    _event = calloc<_InputEvent>();
    _fd = fd;
    _detail = 'Périphérique evdev créé (045E:028E)';
    // Petit délai : laisse udev publier le nœud /dev/input/eventX.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return true;
  }

  @override
  void submit(PadState state) {
    if (_fd < 0) return;
    final libc = DynamicLibrary.process();
    final write = libc.lookupFunction<_WriteNative, _WriteDart>('write');
    for (final event in _encoder.encode(state)) {
      _event.ref.type = event.type;
      _event.ref.code = event.code;
      _event.ref.value = event.value;
      // L'horodatage à zéro laisse le noyau estampiller l'événement.
      _event.ref.time.sec = 0;
      _event.ref.time.usec = 0;
      write(_fd, _event.cast(), sizeOf<_InputEvent>());
    }
  }

  @override
  Future<void> stop() async {
    if (_fd < 0) return;
    final libc = DynamicLibrary.process();
    final ioctl = libc.lookupFunction<_IoctlNative, _IoctlDart>('ioctl');
    final close = libc.lookupFunction<_CloseNative, _CloseDart>('close');
    ioctl(_fd, _Ioctl.devDestroy, nullptr);
    if (_event != nullptr) {
      calloc.free(_event);
      _event = nullptr;
    }
    if (_setup != nullptr) {
      calloc.free(_setup);
      _setup = nullptr;
    }
    close(_fd);
    _fd = -1;
    _detail = 'périphérique détruit';
  }
}
