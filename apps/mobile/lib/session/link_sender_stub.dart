import 'package:pad_core/pad_core.dart';

import 'link_sender_base.dart';

/// Implémentation neutre (web) : aucun socket disponible.
class LinkSenderStub implements LinkSender {
  @override
  bool get supported => false;

  @override
  bool get running => false;

  @override
  int get sent => 0;

  @override
  int get rttUs => 0;

  @override
  String? get error => 'Envoi réseau indisponible sur cette plateforme.';

  @override
  String? get remote => null;

  @override
  void push(PadState state) {}

  @override
  void markDirty() {}

  @override
  Future<bool> start({
    required String host,
    int port = 47833,
    required int code,
  }) async => false;

  @override
  void stop() {}
}

LinkSender createLinkSender() => LinkSenderStub();
