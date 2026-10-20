# PadLab 0.4 — version réelle

## Constat

L'app ne **lit jamais** une vraie manette, même branchée. Dans
`PadSession.detectHardware()` :

```dart
if (devices.isNotEmpty && simulate) {
  // On garde la simulation, mais on connaît la manette présente.
  device ??= devices.first;
}
```

La manette est détectée, son nom s'affiche, mais les entrées restent
générées. Le pont natif Android (`InputDevice`, `MotionEvent`,
`BatteryState`, `VibratorManager`) est complet et compile : il n'est
simplement jamais activé.

## Ce qui change

### 1. Bascule automatique (le cœur)

- Trois modes : **Auto** (défaut), **Réel**, **Démo**.
- Au démarrage : sonde les manettes, passe en réel si l'une est présente.
- Branchement à chaud : passage en réel sans toucher aux réglages.
- Débranchement : retour en démo, avec le motif affiché.
- Les analyses sont remises à zéro au changement de source : des mesures
  de démonstration ne doivent jamais se mêler à des mesures réelles.

### 2. Ce que la version réelle sait lire

| Donnée | Source Android |
|---|---|
| Boutons, croix, épaules | `KeyEvent` (KEYCODE_BUTTON_*) |
| Sticks, gâchettes | `MotionEvent` (AXIS_*) |
| Nom, VID/PID, transport | `InputDevice` |
| Batterie | `InputDevice.getBatteryState()` (API 31+) |
| Vibration | `VibratorManager` (deux canaux) |

### 3. Ce qu'elle ne sait pas faire, et qui doit être dit

- **Batterie** en dessous d'Android 12 : pas d'API publique → l'écran
  l'indique au lieu d'inventer un pourcentage.
- **iOS** : pas de valeurs brutes, pas de VID/PID (voir Apple
  GameController) — non traité dans cette version.
- **Remap système Android** : impossible sans root, comme documenté.

### 4. Affichage

- Accueil : badge **Réel** ou **Démo**, nom de la manette, transport.
- Réglages : sélecteur Auto / Réel / Démo, liste des manettes détectées,
  message d'erreur explicite si le matériel refuse de démarrer.

## Vérification

- Tests Dart avec un faux pont : branchement → réel, débranchement → démo,
  échec matériel → message. **16 tests** dans `apps/mobile`, dont 8 nouveaux.
- `refcount_test` (pad_bridge) : le canal natif survit à l'arrêt de la capture.
- CI : APK réel construit, avec le plugin natif compilé.
- Ce que je ne peux pas vérifier ici : la lecture d'une manette physique.
  Je le dis clairement au lieu de prétendre le contraire.

## Défauts trouvés en chemin, et corrigés

| Défaut | Conséquence réelle |
|---|---|
| `simulate` du constructeur masquait le champ | le mode réel restait bloqué sur « simulation » |
| canal natif fermé avec la capture | une manette rebranchée n'était plus jamais vue |
| file native non vidée sans auditeur | rafale d'événements périmés au branchement |
| permission `VIBRATE` absente | vibration silencieusement refusée |
| historique de batterie fabriqué en réel | pourcentage inventé présenté comme mesure |
| sessions d'accueil codées en dur | faux historique « Xbox Series hier » |
| score de santé sur zéro mesure | « 72/100 » sans avoir rien lu |
| `activeDeviceId = 1` par défaut | identifiant fictif avant toute manette |
