import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise que l'introduction a déjà été vue.
///
/// Volontairement minuscule : une clé, rien d'autre. Aucun identifiant, aucune
/// donnée d'usage.
class OnboardingState {
  static const _key = 'padlab.onboarding.v1';

  static Future<bool> seen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // Stockage indisponible (web sans localStorage, test isolé) : on ne
      // bloque pas l'application, on montre l'introduction.
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Sans stockage, l'introduction réapparaîtra : gênant, jamais bloquant.
    }
  }

  /// Réinitialise le drapeau, pour « Revoir l'introduction ».
  static Future<void> reset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
