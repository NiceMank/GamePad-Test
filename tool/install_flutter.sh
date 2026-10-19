#!/usr/bin/env bash
# Installe Flutter dans la sandbox de travail (hors /home/user, donc non
# versionné). À relancer si `flutter` a disparu entre deux sessions : /opt
# n'est pas conservé d'un message à l'autre.
#
#   ./tool/install_flutter.sh
set -euo pipefail

VERSION="${1:-3.47.7}"
DEST=/opt/flutter-dl

if [ -x /opt/flutter/bin/flutter ]; then
  echo "✓ Flutter déjà présent : $(/opt/flutter/bin/flutter --version | head -1)"
  exit 0
fi

sudo mkdir -p "$DEST"
sudo chown "$(id -u):$(id -g)" "$DEST"
cd "$DEST"

# /tmp est un tmpfs de 1 Go : l'archive fait 1,5 Go, il faut donc la
# télécharger directement dans /opt.
curl -sL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz" -o f.tar.xz
tar xf f.tar.xz
rm -f f.tar.xz
sudo ln -sfn "$DEST/flutter" /opt/flutter

/opt/flutter/bin/flutter --version | head -2
echo "→ export PATH=/opt/flutter/bin:\$PATH"
