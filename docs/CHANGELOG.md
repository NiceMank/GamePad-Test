# Journal des versions

## 0.6.1 — les détails qui trahissaient

Trois défauts vus sur les rendus de la 0.6.0, corrigés.

- **Les touches vues s'affichaient en barres pleine largeur.** Un `Container`
  porteur d'un `alignment` s'étire sur la place disponible : dans un `Wrap`,
  chaque touche prenait toute la ligne, avec une lettre au milieu. Ce sont
  maintenant des pastilles compactes alignées sur une grille.
- **Le sous-titre de l'actualisation finissait par « · jamais ».** La phrase
  est construite selon ce qu'on sait, au lieu de coller un horodatage vide.
- **L'interrupteur** est ramené à sa taille réelle et son contraste ne laisse
  plus croire qu'il est éteint quand il est allumé.
- **Angle de repos de la manette** adouci : le modèle est posé face à vous,
  légèrement plongé, au lieu d'être penché.
- La version affichée dans les réglages n'est plus recopiée en dur — elle y
  était restée en 0.5.0 pendant une version.

## 0.6.0 — batterie lue pour de vrai, 3D immobile, nettoyage

Retour d'usage après la 0.5.0 : « des trucs marchaient mais on dirait un
débutant, même les infos de batterie ne s'affichaient pas ». Les trois
reproches étaient fondés.

### La batterie ne s'affichait pas — pourquoi

Deux erreurs dans le code natif, pas un problème de manette :

1. **`InputDevice.getBatteryState()` était appelé sur le thread principal.**
   C'est un appel Binder synchrone qui lit un nœud du noyau : sur une manette
   Bluetooth il peut bloquer plusieurs secondes, et geler l'interface.
2. **Aucun repli.** Beaucoup de manettes ne renseignent pas cette API ; le code
   renvoyait alors « inconnu », sans jamais essayer autre chose.

Corrigé :

* Nouveau `BatteryReader` : lecture **hors thread principal**, une seule à la
  fois, avec cache de 20 s.
* Trois sources essayées dans l'ordre : API Android 12+, puis les nœuds
  noyau `/sys/class/power_supply/*-battery` (les manettes HID y publient leur
  niveau), puis la dernière valeur connue.
* L'appel de `describe()` lisait aussi la batterie → chaque scan des manettes
  bloquait le thread principal. Supprimé.
* Quand aucune valeur n'existe, l'écran dit **pourquoi** et propose
  « Réessayer », au lieu d'afficher un tiret muet.

### La 3D tournait toute seule

* Modèle **immobile par défaut**. Plus d'auto-rotation.
* Deux commandes seulement, en haut à droite du cadre : **Tourner / Stop** et
  **Recentrer**. L'aide « Glissez pour tourner » disparaît dès qu'on s'en sert.
* Test de non-régression : la scène ne bouge pas tant que l'utilisateur ne
  demande rien.

### Ce qui faisait « débutant »

* **« Source des entrées » écrit deux fois** dans les réglages (titre de
  section + titre de carte). Réglages réécrits : trois groupes, aucune
  répétition, plus de carte-dans-carte.
* **Écran de test à moitié vide** : le modèle est plus grand et la couverture
  des touches (« Touches vues, 4/12 ») remplit le bas utilement.
* **« DÉCHARGE » affiché deux fois** sur l'écran batterie ; le temps de charge
  n'apparaît plus que pendant la charge.
* Glyphes `☰` et `▣` rendus en carrés vides selon la police : remplacés par
  des libellés sûrs.
* Étiquettes « Bridge Android · pad_bridge · InputDevice… » — du vocabulaire
  d'implémentation à l'écran. Remplacées par le nom de la manette et son
  transport.

### Tests

**39 tests** dans l'application (+3 sur le chemin batterie, +4 sur la scène
immobile). Tous les paquets analysés sans avertissement.

## 0.5.0 — accueil, logo, actualisation

### Introduction du premier lancement

Quatre écrans, une seule fois, pour répondre à « qu'est-ce que je fais
maintenant ? » avant de montrer un écran vide :

1. Branchez, c'est tout — le vrai modèle 3D de l'application, pas une image.
2. Voyez ce qu'elle envoie — entrées qui s'allument, journal horodaté.
3. Diagnostiquez ses défauts — trace de circularité, dérive, gigue.
4. Jouez sur PC — téléphone, réseau, manette Xbox virtuelle.

« Passer » reste disponible, le choix est mémorisé, et **Réglages → Revoir
l'introduction** permet de la relancer. Chaque écran dit la vérité sur les
limites (batterie Android 12+, manette absente → démonstration).

### Logo

Un seul signe décliné partout : un **P dont le bol est un anneau avec un point
d'acier** — la lettre et le stick analogique sont la même forme. Lisible à
32 px.

* Icône d'application (48 → 192 px) + **icône adaptative** Android 8+ avec
  avant-plan détouré et zone de sécurité respectée.
* Écran de lancement : fond graphite et marque, pour Android 11 et avant
  **et** pour Android 12+ (`windowSplashScreenAnimatedIcon`).
* Marque vectorielle en tête de l'introduction.
* Tout est généré par `tool/padlab_logo.py` : reproductible, versionnable, pas
  un PNG opaque déposé à la main.

### Actualisation automatique

* Interrupteur dans Réglages, **actif par défaut**.
* Manettes relues toutes les 5 s : rattrape un branchement que l'écouteur natif
  aurait manqué (certains adaptateurs USB ne le signalent pas).
* Batterie relue toutes les 10 s (au lieu de 20 s).
* Retour au premier plan : relecture immédiate, manettes + batterie.
* La ligne « il y a 4 s » avance seule : on voit que ça tourne.
* Coupée, le sondage s'arrête et le bouton manuel reste.

### Corrections trouvées en revérifiant le parcours

* **Défaut de la 0.4.0** : en mode « Manette », rebasculer sur « Démo »
  laissait la session marquée « réelle » — le changement n'était appliqué
  qu'après un `await`. L'état bascule maintenant immédiatement, seule la
  capture native est asynchrone.
* Le modèle 3D de l'introduction débordait de 6 px sur un écran 430×900 : il
  se met désormais à l'échelle de la boîte qui le contient.
* Les captures de référence enveloppaient mal les écrans sans session
  (`Directionality` manquant) : corrigé.

### Parcours revérifié, étape par étape

12 tests de bout en bout (`user_journey_test.dart`) : premier lancement,
introduction, accueil, les cinq onglets, test guidé, analyse, batterie sans
manette, remap, Link, les trois modes, l'interrupteur d'actualisation, la
mémoire du choix. Plus 4 tests d'introduction et 8 de la bascule réelle.
Soit **32 tests** dans `apps/mobile`.

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
