import 'package:pad_core/pad_core.dart';

/// Manette virtuelle côté PC.
///
/// `submit` est **synchrone** et sans allocation : il est appelé depuis la
/// boucle de réception UDP, et toute latence ajoutée ici se retrouve dans les
/// jeux. Les implémentations écrivent directement dans le noyau / le driver.
abstract class VirtualPad {
  /// Nom du backend : `ViGEmBus (Xbox 360)`, `uinput`, `simulation`.
  String get backend;

  /// Vrai quand le périphérique virtuel existe réellement.
  bool get ready;

  /// Détail lisible pour l'UI (chemin du device, erreur…).
  String get detail;

  /// Crée le périphérique. À appeler une fois.
  Future<bool> start();

  /// Applique un état complet. Appelé à chaque paquet reçu.
  void submit(PadState state);

  /// Détruit le périphérique virtuel.
  Future<void> stop();
}
