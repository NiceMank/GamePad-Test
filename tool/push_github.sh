#!/usr/bin/env bash
# Pousse le dépôt local vers GitHub sans jamais écrire le token sur disque
# ni dans .git/config.
#
#   ./tool/push_github.sh /chemin/token.txt owner/repo [branche]
#
# Le token doit avoir « Contents: read/write » (fine-grained) ou le scope
# « repo » (classique). Il est lu, utilisé pour un seul push, puis oublié.
set -euo pipefail

TOKEN_FILE="${1:-/home/user/github_token.txt}"
REPO="${2:-}"
BRANCH="${3:-main}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "✗ Fichier de token introuvable : $TOKEN_FILE" >&2
  exit 1
fi

# Accepte : token brut, "GITHUB_TOKEN=xxx", ou un JSON {"token": "xxx"}.
read_token() {
  local file="$1"
  case "$file" in
    *.json)
      python3 - "$file" <<'PYJSON'
import json, sys
data = json.load(open(sys.argv[1]))
for key in ("token", "github_token", "GITHUB_TOKEN", "access_token"):
    if isinstance(data, dict) and data.get(key):
        print(str(data[key]).strip())
        break
PYJSON
      ;;
    *)
      tr -d '[:space:]' < "$file" | sed -E 's/^[A-Za-z_]+=//'
      ;;
  esac
}

TOKEN="$(read_token "$TOKEN_FILE")"
if [ -z "$TOKEN" ]; then
  echo "✗ Fichier de token vide." >&2
  exit 1
fi

if [ -z "$REPO" ]; then
  REPO="$(git -C "$ROOT" remote get-url origin 2>/dev/null \
    | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?#\1#' || true)"
fi
if [ -z "$REPO" ]; then
  echo "Usage : $0 [fichier_token] owner/repo [branche]" >&2
  exit 1
fi

cd "$ROOT"

# Branche locale -> nom distant
git branch -M "$BRANCH" 2>/dev/null || true

git remote remove origin >/dev/null 2>&1 || true
git remote add origin "https://github.com/${REPO}.git"

AUTH="$(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"

echo "→ Push de $(git rev-list --count HEAD) commit(s) vers ${REPO}:${BRANCH}"
if ! GIT_TERMINAL_PROMPT=0 git \
    -c http.extraHeader="AUTHORIZATION: basic ${AUTH}" \
    push -u origin "$BRANCH" 2>&1 | sed "s/${TOKEN}/***/g"; then
  echo "→ Push refusé : le dépôt distant contient probablement des commits." >&2
  echo "  Récupération et fusion sans historique commun…" >&2
  GIT_TERMINAL_PROMPT=0 git \
    -c http.extraHeader="AUTHORIZATION: basic ${AUTH}" \
    fetch origin "$BRANCH" 2>&1 | sed "s/${TOKEN}/***/g" || true
  git merge --allow-unrelated-histories --no-edit "origin/${BRANCH}" || {
    echo "✗ Fusion impossible automatiquement. Résous les conflits puis relance." >&2
    exit 1
  }
  GIT_TERMINAL_PROMPT=0 git \
    -c http.extraHeader="AUTHORIZATION: basic ${AUTH}" \
    push -u origin "$BRANCH" 2>&1 | sed "s/${TOKEN}/***/g"
fi

echo "✓ Poussé : https://github.com/${REPO}"
