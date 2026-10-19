/// Envoi des trames PadLab Link.
///
/// Sur le web, `dart:io` n'existe pas : l'export conditionnel fournit une
/// implémentation neutre qui signale simplement que l'envoi n'est pas
/// disponible. Sur Android/desktop, c'est la vraie socket UDP.
library;

export 'link_sender_base.dart';
export 'link_sender_stub.dart' if (dart.library.io) 'link_sender_io.dart'
    show createLinkSender;
