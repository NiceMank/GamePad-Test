# PadLab 0.3 — réalisme du modèle + tests pas à pas

## Objectif

1. Le modèle 3D doit se lire comme un **objet manufacturé**, pas comme un
   dessin vectoriel : matière, lumière, bords arrondis, boutons bombés.
2. La palette « néon vert / rouge / cyan » disparaît au profit de couleurs de
   produit (blanc cassé, graphite, symboles désaturés).
3. Les tests se déroulent **étape par étape** : un geste demandé, validé, puis
   le suivant — au lieu de tout afficher d'un coup.

## 1. Matière et lumière

- Éclairage par facette : Lambert + spéculaire (Blinn-Phong) calculé à partir
  de la normale, lumière fixe en haut à gauche. Les teintes de base redeviennent
  des albédos, l'ombre et le reflet sont calculés, plus dessinés à la main.
- Passe « matière » par-dessus le maillage : reflet haut-gauche, occlusion en
  bas, grain plastique fin (texture 64 px répétée, opacité faible).
- Bords de coque arrondis : anneau de raccord entre le flanc et la façade, pour
  que la tranche capte la lumière.
- Boutons et sticks bombés (dôme + cuvette), au lieu de cylindres à plat.

## 2. Palette produit

- UI : graphite neutre, un seul accent bleu acier désaturé. Sémantique
  (batterie, alerte) conservée mais en tons matière : sauge, laiton, brique.
- Modèles : DualSense blanc cassé / graphite, Xbox noir mat, Switch graphite,
  Joy-Con rouge et bleu Nintendo atténués. Symboles PlayStation en bleu acier,
  brique, rose ancien, sauge — plus de fluo.
- Les LED d'appui deviennent un blanc chaud, comme sur une vraie manette.

## 3. Tests guidés

Nouvel écran, une étape à la fois :

1. boutons de façade (les quatre, un par un) ;
2. croix directionnelle (quatre directions) ;
3. sticks gauche et droit (quatre directions chacun) ;
4. gâchettes (course > 90 %) ;
5. épaules ;
6. boutons centraux ;
7. vibration (impulsion) ;
8. récapitulatif avec score et liste des manques.

Chaque étape se valide par l'entrée réelle (ou simulée), avec « Passer » et
« Recommencer ». L'onglet Test garde le panneau libre pour le diagnostic fin.

## Livraison

CI verte, APK + paquets PC publiés en `v0.3.0`, captures avant/après.
