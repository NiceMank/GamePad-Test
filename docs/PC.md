# PadLab Link — la version PC

PadLab a deux applications :

| Application | Où | Ce qu'elle fait |
|---|---|---|
| **PadLab** (mobile) | `apps/mobile` | test, analyse, batterie, remapping, rendu 3D |
| **PadLab Link** (PC) | `apps/pclink` | reçoit la manette du téléphone et la rejoue dans une **manette Xbox 360 virtuelle** pour les jeux |

## Télécharger

Les binaires sont produits à chaque build vert par GitHub Actions, et attachés à
la release :

* **Windows x64** — [release v0.2.0](https://github.com/NiceMank/GamePad-Test/releases/tag/v0.2.0)
  (`PadLab-Link-0.2.0-windows-x64.zip`)
* **Linux x64** — même release (`PadLab-Link-0.2.0-linux-x64.tar.gz`)
* artefacts bruts : onglet **Actions** → dernier run vert → *Artifacts*
  (`padlab-link-windows`, `padlab-link-linux`)

## Windows

1. Décompresser l'archive **en entier** (l'exe ne fonctionne pas seul : il lui
   faut `flutter_windows.dll` et le dossier `data/`).
2. Installer une fois le pilote signé [ViGEmBus](https://github.com/nefarius/ViGEmBus/releases).
   Redémarrage conseillé. C'est lui qui crée le périphérique Xbox vu par les jeux.
3. Lancer `pclink.exe`.
4. Sur le téléphone : onglet **PadLab Link**, saisir l'adresse IP du PC et le
   code à 4 chiffres affiché par le programme, puis **Diffuser vers le PC**.

`ViGEmClient.dll` est compilé pendant la CI et livré à côté de l'exécutable
(licence MIT, fichier `ViGEmClient-LICENSE.txt`). Rien à télécharger à part le
pilote.

Les jeux voient une **manette Xbox 360** : XInput, DirectInput via le mode
compatibilité, Steam Input en source « Xbox 360 », émulateurs, Proton…

## Linux

```bash
sudo modprobe uinput
sudo usermod -aG input "$USER"     # puis se reconnecter
tar xzf PadLab-Link-0.2.0-linux-x64.tar.gz
./pclink
```

Le programme crée un périphérique evdev `045E:028E`
(« PadLab Virtual Xbox 360 Controller »), reconnu par SDL2, Steam, Proton et
RetroArch. Aucun pilote tiers.

## Latence

| Chemin | Ajout mesuré |
|---|---|
| UDP → écriture `uinput` | < 0,2 ms |
| UDP → `vigem_target_x360_update` | < 0,3 ms |
| Téléphone, coalescence 250 Hz | 4 ms max, 2 ms moyen |

Les trames sont **absolues** (32 octets) : une perte UDP ne laisse jamais la
manette bloquée dans une direction.

## Compiler soi-même

```bash
cd apps/pclink
flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release     # build/windows/x64/runner/Release
```

```bash
cd apps/pclink
flutter config --enable-linux-desktop
flutter pub get
flutter build linux --release       # build/linux/x64/release/bundle
```
