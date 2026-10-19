import 'package:pad_core/pad_core.dart';

import '../mapping.dart';
import '../virtual_pad.dart';

/// Backend sans effet : utilisé sur les plateformes non supportées, en test,
/// et comme repli quand le driver n'est pas installé. Il compte tout de même
/// les rapports pour que l'UI reste vérifiable.
class NullPad implements VirtualPad {
  NullPad({this.reason = 'Aucun backend de manette virtuelle disponible'});

  /// Raison affichée dans l'interface.
  final String reason;

  int reports = 0;
  XboxReport lastReport = const XboxReport();
  PadState lastState = PadState.idle;
  bool _ready = false;

  @override
  String get backend => 'simulation';

  @override
  bool get ready => _ready;

  @override
  String get detail => reason;

  @override
  Future<bool> start() async {
    _ready = true;
    return true;
  }

  @override
  void submit(PadState state) {
    reports++;
    lastState = state;
    lastReport = toXboxReport(state);
  }

  @override
  Future<void> stop() async {
    _ready = false;
  }
}
