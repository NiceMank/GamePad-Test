# PadLab Link (PC)

Reçoit l'état d'une manette Android et le rejoue dans une **manette virtuelle
Xbox** pour les jeux du PC.

## Ce que fait le programme

1. Écoute l'UDP `47833` (et le TCP `47834` en secours).
2. Vérifie le code d'appairage à 4 chiffres affiché à l'écran.
3. Applique chaque état reçu (32 octets, absolu) à la manette virtuelle, dans la
   même boucle que la réception, sans allocation.
4. Affiche la manette en 3D, le débit, le jitter et la perte de paquets.

## Windows — ViGEmBus

Installer le pilote signé [ViGEmBus](https://github.com/nefarius/ViGEmBus/releases)
(une fois, redémarrage conseillé). PadLab Link charge `ViGEmClient.dll` et crée une
manette **Xbox 360** vue par XInput : compatible avec la quasi-totalité des jeux,
Steam Input, émulateurs, etc.

Si `ViGEmClient.dll` n'est pas dans le `PATH`, placez-le à côté de
`padlab_link.exe`.

## Linux — uinput

```bash
sudo modprobe uinput
sudo usermod -aG input $USER      # puis se reconnecter
# facultatif : autoriser tout le monde
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/60-padlab-uinput.rules
```

Le programme crée un périphérique evdev `045E:028E` (« PadLab Virtual Xbox 360
Controller »), reconnu par SDL2, Proton, Steam et RetroArch. Aucun driver tiers.

## Latence

| Chemin | Ajout mesuré |
|---|---|
| Réception UDP → écriture uinput | < 0,2 ms |
| Réception UDP → `vigem_target_x360_update` | < 0,3 ms |
| Téléphone, coalescence 250 Hz | 4 ms max, 2 ms moyen |

Le téléphone envoie au plus `250` trames/s : sur une manette 1000 Hz, seul le
dernier état de chaque fenêtre de 4 ms part, ce qui évite de saturer le Wi-Fi
sans retard perceptible. Les paquets sont **absolus** : une perte ne laisse
jamais la manette bloquée dans une direction.

## Compilation

```bash
flutter config --enable-windows-desktop   # ou --enable-linux-desktop
flutter pub get
flutter build windows --release            # build/windows/x64/runner/Release
flutter build linux --release              # build/linux/x64/release/bundle
```

Les deux binaires sont produits automatiquement par GitHub Actions
(`.github/workflows/ci.yml`, jobs `windows` et `linux`).
