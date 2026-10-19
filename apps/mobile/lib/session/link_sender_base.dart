import 'package:pad_core/pad_core.dart';

/// Contrat d'envoi des trames PadLab Link.
///
/// L'implémentation réelle (socket UDP) ou neutre (web) est choisie à la
/// compilation via `link_sender.dart`. La session ne connaît que ce contrat,
/// ce qui garde le code identique sur toutes les plateformes.
abstract class LinkSender {
  bool get supported;
  bool get running;
  int get sent;
  int get rttUs;
  String? get error;
  String? get remote;

  /// Nouvel état à diffuser.
  void push(PadState state);

  /// Indique qu'une trame est disponible (coalescence au débit d'envoi).
  void markDirty();

  Future<bool> start({required String host, int port, required int code});

  void stop();
}
