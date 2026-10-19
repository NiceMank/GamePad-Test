#!/usr/bin/env bash
# Suit le dernier build GitHub Actions et télécharge les artefacts.
#
#   ./tool/ci_status.sh /chemin/token.txt owner/repo [--download]
set -euo pipefail

TOKEN_FILE="${1:-/home/user/github_token.txt}"
REPO="${2:-}"
DOWNLOAD="${3:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$TOKEN_FILE" ] || { echo "✗ Token introuvable : $TOKEN_FILE" >&2; exit 1; }
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
[ -n "$REPO" ] || { echo "Usage : $0 fichier_token owner/repo [--download]" >&2; exit 1; }

auth=(-H "Authorization: Bearer ${TOKEN}" -H "Accept: application/vnd.github+json")

run_json="$(curl -fsSL "${auth[@]}" \
  "https://api.github.com/repos/${REPO}/actions/runs?per_page=1")"

python3 - "$run_json" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
runs = data.get("workflow_runs", [])
if not runs:
    print("Aucun run pour l'instant (le workflow démarre au premier push).")
    raise SystemExit(0)
run = runs[0]
print(f"Run #{run['run_number']} · {run['name']} · {run['status']}/{run['conclusion']}")
print(f"  {run['html_url']}")
PY

if [ "$DOWNLOAD" = "--download" ]; then
  run_id="$(python3 -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["workflow_runs"][0]["id"] if d["workflow_runs"] else "")' "$run_json")"
  [ -n "$run_id" ] || exit 0
  mkdir -p "$ROOT/artifacts"
  curl -fsSL "${auth[@]}" \
    "https://api.github.com/repos/${REPO}/actions/runs/${run_id}/artifacts" \
    | python3 -c 'import json,sys
for a in json.load(sys.stdin).get("artifacts", []):
    print(a["name"], a["archive_download_url"])' \
    | while read -r name url; do
        echo "↓ ${name}"
        curl -fsSL -H "Authorization: Bearer ${TOKEN}" -o "$ROOT/artifacts/${name}.zip" "$url"
      done
  ls -lh "$ROOT/artifacts"
fi
