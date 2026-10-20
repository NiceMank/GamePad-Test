# PadLab 0.5 — accueil du premier lancement, logo, rafraîchissement

## 1. Onboarding

Quatre écrans, une seule fois, au premier lancement :

1. **Branchez. C'est tout.** — la manette est détectée et lue, sans réglage.
2. **Voyez ce qu'elle envoie** — boutons, sticks, gâchettes, journal.
3. **Diagnostiquez** — dérive, circularité, course des gâchettes, batterie.
4. **Jouez sur PC** — PadLab Link, manette Xbox virtuelle.

Détails qui comptent :

- « Passer » toujours visible ; la dernière page dit « Commencer ».
- Choix mémorisé (`shared_preferences`) : pas de réintroduction au 2ᵉ lancement.
- « Revoir l'introduction » dans les réglages, pour ne pas l'imposer sans issue.
- L'écran reste vrai : il ne promet pas la batterie sous Android 12, ni le
  remap système Android.

## 2. Logo de lancement

Un seul signe, décliné partout :

- **Marque** : tuile graphite arrondie, monogramme **P** géométrique dont le
  bol est un **anneau avec un point d'acier au centre** — la lettre et le
  stick analogique sont la même forme. Lisible à 48 px.
- **Icône d'application** : mipmaps 48 → 192 px + icône adaptative (avant-plan
  détouré, fond graphite) pour Android 8+.
- **Écran de lancement** : fond #0B0C0E, marque centrée, wordmark PadLab
  dessous ; thème Android 12 (`windowSplashScreenAnimatedIcon`) et thème
  historique (`launch_background`).
- **Dans l'application** : même marque en tête de l'onboarding.

Tout est généré par un script (`tool/padlab_logo.py`) : le logo est
reproductible, pas un PNG opaque déposé à la main.

## 3. Actualisation automatique

Aujourd'hui il faut parfois appuyer sur « rafraîchir » pour voir une manette
ou une batterie à jour.

- Interrupteur **Actualisation automatique** (actif par défaut) dans Réglages.
- Manette absente : nouvelle recherche toutes les 5 s (filet de sécurité si
  l'écouteur natif rate un branchement).
- Batterie : relecture toutes les 10 s (au lieu de 20 s).
- Retour au premier plan : relecture immédiate.
- La ligne « Actualisé à … » avance seule : on voit que ça tourne.
- Interrupteur coupé : plus de sondage, le bouton manuel reste.

## 4. Revérifier toute la voie d'utilisation

Parcours complet, testé étape par étape :

| Étape | Ce qui doit être vrai |
|---|---|
| Premier lancement | onboarding affiché |
| « Commencer » | accueil, onboarding mémorisé |
| Deuxième lancement | pas d'onboarding |
| Manette branchée | accueil en `Réel`, entrées vivantes |
| Aucune manette | accueil en `Aucun`, pas de modèle fictif |
| Les 5 onglets | aucun écran vide ni exception |
| Remap, Link | s'ouvrent depuis l'accueil |
| Test guidé | les 7 étapes avancent |
| Réglages | source, actualisation, « revoir l'introduction » |

Plus : captures de référence (onboarding clair/sombre, écran de lancement).

## Livraison

Version **0.5.0** : APK + binaires PC, release GitHub, CI verte.
