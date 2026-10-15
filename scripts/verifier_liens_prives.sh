#!/usr/bin/env bash
# verifier_liens_prives.sh [RACINE] — aucune page publiée ne lie un dépôt PRIVÉ de l'organisation.
#
# Pourquoi : un lien vers github.com/aiame-fr/<dépôt privé> est mort pour le public (404) ET confirme que le dépôt existe
# (nom, chemin, document). Constaté le 2026-10-15 : 10 liens de ce genre sur 4 pages (transparence FR/EN, note miroir FR/EN)
# et 1 sur la page Carburant de Focus. Ce garde nomme chaque lien fautif.
#
# La liste des dépôts PUBLICS est courte et écrite ici : si un dépôt devient public, on l'ajoute ICI, par décision.
# Le profil de l'organisation (github.com/aiame-fr) reste permis : il ne liste que les dépôts publics.
#
# Sortie 0 = conforme · 1 = au moins un lien vers un dépôt non listé.
set -uo pipefail
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PUBLICS='aiame-fr\.github\.io|changedetection\.io'
FAIL=0
while IFS= read -r f; do
  rel="${f#$R/}"
  while IFS= read -r l; do
    echo "VIOLATION: $rel : lien vers un dépôt non public — $l"; FAIL=1
  done < <(grep -o -i -E "https?://(www\.)?github\.com/aiame-fr/[A-Za-z0-9._-]+[^\"' <>)]*" "$f" | grep -v -i -E "github\.com/aiame-fr/($PUBLICS)([/#?]|\$)" | sort -u)
done < <(find "$R" -type f \( -name '*.html' -o -name '*.json' -o -name '*.js' -o -name '*.md' \) -not -path '*/.git/*' -not -path '*/.claude/*' -not -path '*/node_modules/*' | sort)
[ "$FAIL" -eq 0 ] && echo "OK : aucun lien vers un dépôt privé de l'organisation"
exit $FAIL
