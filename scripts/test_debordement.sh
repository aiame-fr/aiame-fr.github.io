#!/usr/bin/env bash
# test_debordement.sh — preuve par mutation de debordement.py (règle 5 : un garde-fou jamais vu échouer ne prouve rien).
# Sur les pages propres il verdit ; sur une copie dont on retire chaque correctif (le texte long coupé, en français et en anglais)
# il rougit, en NOMMANT la page ; sur un dossier sans page il échoue (un garde qui ne mesure rien ne prouve rien).
#
# Sortie : 0 vert · 1 un cas trahi · 2 ABSTENTION (Playwright ou Chromium absent — jamais un vert).
set -u
RACINE="$(cd "$(dirname "$0")/.." && pwd)"
ATELIER="$(mktemp -d)"; trap 'rm -rf "$ATELIER"' EXIT
ECHECS=0
copie() { rm -rf "$ATELIER/$1"; mkdir -p "$ATELIER/$1/en"; for f in index.html merci.html en/index.html; do cp "$RACINE/$f" "$ATELIER/$1/$f"; done; }
cas() { # <nom> <dossier> <code attendu> <motif attendu>
  local nom="$1" d="$2" attendu="$3" motif="$4" S c
  S="$(python3 "$RACINE/scripts/debordement.py" --racine "$ATELIER/$d" 2>&1)"; c=$?
  if [ "$c" -eq 2 ]; then echo "⚠ ABSTENTION — navigateur absent sur cette machine ($nom)"; exit 2; fi
  if [ "$c" -eq "$attendu" ] && { [ -z "$motif" ] || printf '%s' "$S" | grep -q -- "$motif"; }; then echo "✓ $nom"
  else echo "✗ $nom — code $c (attendu $attendu), motif « $motif »"; printf '%s\n' "$S" | tail -4 | sed 's/^/    | /'; ECHECS=$((ECHECS + 1)); fi
}
muter() { # <dossier> <fichier> <expression sed> — refuse une mutation qui ne change rien
  cp "$ATELIER/$1/$2" "$ATELIER/avant.html"; sed -i "$3" "$ATELIER/$1/$2"
  cmp -s "$ATELIER/avant.html" "$ATELIER/$1/$2" && { echo "✗ la mutation $1/$2 n'a rien changé (motif périmé)"; exit 1; }
}

copie propre
cas "témoin : les pages propres → verdit" propre 0 "aucune ne défile"

copie sans-code; muter sans-code index.html "s/main{overflow-wrap:break-word}//"
cas "mutation : l'adresse ou le chemin trop long n'est plus coupé → rougit, la page est nommée" sans-code 1 "index.html déborde"

copie sans-code-en; muter sans-code-en en/index.html "s/main{overflow-wrap:break-word}//"
cas "mutation : idem sur la page anglaise → rougit, nommée" sans-code-en 1 "en/index.html déborde"

rm -rf "$ATELIER/vide"; mkdir -p "$ATELIER/vide"
cas "un dossier sans page n'est PAS un vert" vide 1 "aucune page"

if [ "$ECHECS" -ne 0 ]; then echo "✗ $ECHECS cas trahis"; exit 1; fi
echo "✅ debordement.py verdit sur les pages propres, et rougit sans texte long coupé (FR, EN), et sur un dossier vide"
