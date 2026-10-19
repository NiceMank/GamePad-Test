import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:pad_core/pad_core.dart';

import '../mapping.dart';
import '../virtual_pad.dart';

/// XUSB_REPORT (12 octets, passé **par valeur** à ViGEmClient).
final class _XusbReport extends Struct {
  @Uint16()
  external int wButtons;
  @Uint8()
  external int bLeftTrigger;
  @Uint8()
  external int bRightTrigger;
  @Int16()
  external int sThumbLX;
  @Int16()
  external int sThumbLY;
  @Int16()
  external int sThumbRX;
  @Int16()
  external int sThumbRY;
}

typedef _EmptyNative = Pointer<Void> Function();
typedef _EmptyDart = Pointer<Void> Function();

typedef _ErrorOneNative = Int32 Function(Pointer<Void>);
typedef _ErrorOneDart = int Function(Pointer<Void>);

typedef _ErrorTwoNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _ErrorTwoDart = int Function(Pointer<Void>, Pointer<Void>);

typedef _FreeNative = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);

typedef _X360UpdateNative = Int32 Function(Pointer<Void>, Pointer<Void>, _XusbReport);
typedef _X360UpdateDart = int Function(Pointer<Void>, Pointer<Void>, _XusbReport);

/// Manette Xbox 360 virtuelle via **ViGEmBus** (Windows).
///
/// ViGEmBus installe un pilote noyau signé ; les jeux voient une manette
/// XInput standard, donc la compatibilité est maximale (XInput, DirectInput via
/// le mode compatibilité, Steam Input en source « Xbox 360 »).
class WindowsViGEmPad implements VirtualPad {
  Pointer<Void> _client = nullptr;
  Pointer<Void> _target = nullptr;
  Pointer<_XusbReport> _report = nullptr;

  late _ErrorOneDart _connect;
  late _ErrorTwoDart _targetAdd;
  late _X360UpdateDart _update;
  late _ErrorTwoDart _targetRemove;
  late _FreeDart _targetFree;
  late _FreeDart _clientFree;

  String _detail = 'non initialisé';

  @override
  String get backend => 'ViGEmBus';

  @override
  bool get ready => _target != nullptr && _client != nullptr;

  @override
  String get detail => _detail;

  static DynamicLibrary? _load() {
    final candidates = <String>[
      'ViGEmClient.dll',
      '${File(Platform.resolvedExecutable).parent.path}\\ViGEmClient.dll',
      '${Directory.current.path}\\ViGEmClient.dll',
      'C:\\Program Files\\ViGEmBus\\ViGEmClient.dll',
    ];
    for (final candidate in candidates) {
      try {
        return DynamicLibrary.open(candidate);
      } on ArgumentError {
        continue;
      }
    }
    return null;
  }

  @override
  Future<bool> start() async {
    if (ready) return true;

    final lib = _load();
    if (lib == null) {
      _detail = 'ViGEmClient.dll introuvable. Installez ViGEmBus '
          '(github.com/nefarius/ViGEmBus) puis relancez PadLab Link.';
      return false;
    }

    try {
      final allocClient = lib.lookupFunction<_EmptyNative, _EmptyDart>('vigem_alloc');
      final allocTarget =
          lib.lookupFunction<_EmptyNative, _EmptyDart>('vigem_target_x360_alloc');
      _connect = lib.lookupFunction<_ErrorOneNative, _ErrorOneDart>('vigem_connect');
      _targetAdd = lib.lookupFunction<_ErrorTwoNative, _ErrorTwoDart>('vigem_target_add');
      _update = lib.lookupFunction<_X360UpdateNative, _X360UpdateDart>('vigem_target_x360_update');
      _targetRemove =
          lib.lookupFunction<_ErrorTwoNative, _ErrorTwoDart>('vigem_target_remove');
      _targetFree = lib.lookupFunction<_FreeNative, _FreeDart>('vigem_target_free');
      _clientFree = lib.lookupFunction<_FreeNative, _FreeDart>('vigem_free');

      final client = allocClient();
      if (client == nullptr) {
        _detail = 'vigem_alloc a échoué.';
        return false;
      }
      final connectError = _connect(client);
      if (connectError != 0) {
        _detail = 'vigem_connect : erreur $connectError (le pilote ViGEmBus '
            'est-il installé et le service démarré ?)';
        _clientFree(client);
        return false;
      }

      final target = allocTarget();
      if (target == nullptr) {
        _detail = 'vigem_target_x360_alloc a échoué.';
        _clientFree(client);
        return false;
      }
      final addError = _targetAdd(client, target);
      if (addError != 0) {
        _detail = 'vigem_target_add : erreur $addError '
            '(une manette virtuelle est peut-être déjà occupée).';
        _targetFree(target);
        _clientFree(client);
        return false;
      }

      _client = client;
      _target = target;
      _report = calloc<_XusbReport>();
      _detail = 'Manette Xbox 360 virtuelle branchée (ViGEmBus).';
      return true;
    } on ArgumentError catch (e) {
      _detail = 'Symboles ViGEmClient manquants : $e';
      return false;
    }
  }

  @override
  void submit(PadState state) {
    if (!ready || _report == nullptr) return;
    final report = toXboxReport(state);
    final ref = _report.ref;
    ref.wButtons = report.buttons;
    ref.bLeftTrigger = report.leftTrigger;
    ref.bRightTrigger = report.rightTrigger;
    ref.sThumbLX = report.leftX;
    ref.sThumbLY = report.leftY;
    ref.sThumbRX = report.rightX;
    ref.sThumbRY = report.rightY;
    _update(_client, _target, ref);
  }

  @override
  Future<void> stop() async {
    if (_report != nullptr) {
      calloc.free(_report);
      _report = nullptr;
    }
    if (_target != nullptr && _client != nullptr) {
      _targetRemove(_client, _target);
    }
    if (_target != nullptr) {
      _targetFree(_target);
      _target = nullptr;
    }
    if (_client != nullptr) {
      _clientFree(_client);
      _client = nullptr;
    }
    _detail = 'manette virtuelle retirée';
  }
}
