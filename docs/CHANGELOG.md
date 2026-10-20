# Journal des versions

## 0.4.0 — la première version qui lit une vraie manette

Jusqu'ici, PadLab savait parler aux manettes mais ne le faisait pas : la session
démarrait en simulation et y restait, même quand une manette était branchée.
Le nom de la manette s'affichait, les entrées étaient inventées. C'est corrigé.

### La lecture réelle devient le chemin principal

* Au démarrage, PadLab cherche une manette. Si elle est là, **ses entrées sont
  lues directement** (boutons, sticks, gâchettes), sans manipulation.
* Brancher une manette à chaud bascule l'application en réel toute seule.
* La débrancher ramène à la démonstration, avec le motif affiché.
* Au retour au premier plan, la détection est relancée : une manette appairée
  pendant que l'application était en arrière-plan est vue.
* Trois modes dans Réglages : **Auto**, **Manette**, **Démo**.

### Ce qui n'est plus inventé

* **Historique de sessions** : les trois lignes « DualSense hier 19:07 »
  étaient codées en dur. Elles sont remplacées par un journal de sessions
  réellement lues (durée, date, score), vide au premier lancement.
* **Batterie** : l'historique de décharge était fabriqué même en mode réel.
  En réel, seules les lectures natives comptent ; sans lecture, l'écran
  affiche « non exposée » au lieu d'un pourcentage.
* **Score de santé** : affiché « — » tant que les sticks n'ont pas bougé,
  plutôt qu'un score calculé sur zéro mesure.
* **Accueil sans manette** : plus de contrôleur 3D fictif à la place du
  matériel de l'utilisateur. Un panneau explique quoi brancher.

### Corrections de fond

* **Manette débranchée puis rebranchée** : le canal natif était fermé en même
  temps que la capture, donc plus aucun branchement n'était détecté ensuite.
  Un compteur de références garde le canal ouvert tant que quelqu'un écoute.
* **Permission `VIBRATE`** absente du manifeste : la vibration échouait en
  silence sur un vrai téléphone.
* **Paramètre masquant** : dans le constructeur de `PadSession`, le paramètre
  nommé `simulate` masquait le champ du même nom ; l'affectation ne faisait
  rien. Le corps passe par une méthode d'initialisation.
* **Événements périmés** : la file native est vidée au moment où Dart
  s'abonne, et à chaque vidage sans auditeur.
* La veille des branchements reste active après l'arrêt de la capture, y
  compris en mode « Manette » sans manette présente.

### Tests

* `source_switch_test` : manette présente → réel, branchement à chaud,
  débranchement, absence de matériel, événements natifs → état.
* `no_device_test` : écrans utilisables sans manette, badge « Aucun »,
  mode réel qui n'invente pas de démonstration.
* `refcount_test` : le canal natif survit à l'arrêt de la capture.
* Deux nouveaux rendus de référence : accueil en réel et accueil vide.

### Limites assumées

* Batterie : API Android 12+ ; en dessous, la valeur n'est pas exposée.
* Remapping système Android : impossible sans root (inchangé).
* iOS : pas de valeurs brutes ni de VID/PID — hors périmètre.
* La lecture d'une manette physique n'a pas pu être vérifiée sur matériel
  dans l'environnement de développement ; les tests couvrent le chemin
  complet avec un pont simulé, et la CI compile le plugin natif.

## 0.3.1 — touches séparées, modèles distincts

* Épaule et gâchette sont deux pièces distinctes sur le modèle 3D.
* Modèles Xbox, Switch Pro et Steam Deck réellement différenciés
  (tailles de sticks, croix, glyphes, écran et pavés tactiles).
* Rendu 2,650 ms/image.

## 0.3.0 et avant

Voir l'historique Git : refonte visuelle, manette 3D par familles, analyse des
sticks, batterie, remapping, PadLab Link (Windows/Linux).
