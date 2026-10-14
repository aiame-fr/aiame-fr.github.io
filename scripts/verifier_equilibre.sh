#!/usr/bin/env bash
# equilibre/index.html est GÉNÉRÉ dans aiame-workspace (tools/equilibre/equilibre.py --publier) ; sa somme vit dans
# equilibre/PROVENANCE.json. Retouche à la main, copie sans provenance ou provenance sans copie -> rouge.
# Péremption (copie en retard sur les sources) : `equilibre.py --verifier-publie <ce dépôt>` côté workspace.
#   bash scripts/verifier_equilibre.sh [racine]
set -u
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [ ! -e "$R/equilibre/index.html" ] && [ ! -e "$R/equilibre/PROVENANCE.json" ]; then echo "✓ equilibre : pas publiée ici, rien à vérifier"; exit 0; fi
for f in index.html PROVENANCE.json; do
  [ -f "$R/equilibre/$f" ] || { echo "✗ equilibre/$f absent alors que l'autre fichier existe"; exit 1; }
done
attendu="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["sha256_index_html"])' "$R/equilibre/PROVENANCE.json")" || { echo "✗ PROVENANCE illisible"; exit 1; }
reel="$(sha256sum "$R/equilibre/index.html" | cut -d' ' -f1)"
if [ "$attendu" = "$reel" ]; then echo "✓ equilibre/index.html conforme à sa PROVENANCE"; exit 0; fi
echo "✗ equilibre/index.html a été retouché : somme $reel, PROVENANCE attend $attendu — régénérer depuis aiame-workspace (--publier)"; exit 1
