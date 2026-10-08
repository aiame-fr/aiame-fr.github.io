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
copie() { rm -rf "$ATELIER/$1"; mkdir -p "$ATELIER/$1/en/divulgation" "$ATELIER/$1/divulgation"; for f in divulgation/index.html merci.html en/divulgation/index.html; do cp "$RACINE/$f" "$ATELIER/$1/$f"; done; }
cas() { # <nom> <dossier> <code attendu> <motif attendu>
  local nom="$1" d="$2" attendu="$3" motif="$4" S c
  S="$(env ${ENVX:-A=1} python3 "${DEB:-$RACINE/scripts/debordement.py}" --racine "$ATELIER/$d" 2>&1)"; c=$?
  if [ "$c" -eq 2 ]; then echo "⚠ ABSTENTION — navigateur absent sur cette machine ($nom)"; exit 2; fi
  if [ "$c" -eq "$attendu" ] && { [ -z "$motif" ] || printf '%s' "$S" | grep -q -- "$motif"; }; then echo "✓ $nom"
  else echo "✗ $nom — code $c (attendu $attendu), motif « $motif »"; printf '%s\n' "$S" | tail -4 | sed 's/^/    | /'; ECHECS=$((ECHECS + 1)); fi
}
rouge() { # <nom> <dossier> <code attendu du BON comportement> <motif> : le cas bon doit ÉCHOUER sur le mutant ($DEB)
  local nom="$1" d="$2" attendu="$3" motif="$4" S c
  S="$(env ${ENVX:-A=1} python3 "$DEB" --racine "$ATELIER/$d" 2>&1)"; c=$?
  if [ "$c" -eq "$attendu" ] && { [ -z "$motif" ] || printf '%s' "$S" | grep -q -- "$motif"; }; then
    echo "✗ $nom — le mutant satisfait encore le cas attendu (mutation non vue)"; ECHECS=$((ECHECS + 1))
  else echo "✓ $nom"; fi
}
muter() { # <dossier> <fichier> <expression sed> — refuse une mutation qui ne change rien
  cp "$ATELIER/$1/$2" "$ATELIER/avant.html"; sed -i "$3" "$ATELIER/$1/$2"
  cmp -s "$ATELIER/avant.html" "$ATELIER/$1/$2" && { echo "✗ la mutation $1/$2 n'a rien changé (motif périmé)"; exit 1; }
}

copie propre
cas "témoin : les pages propres → verdit" propre 0 "aucune ne défile"

copie sans-code; muter sans-code divulgation/index.html "s/main{overflow-wrap:break-word}//; s/code{overflow-wrap:anywhere}//"
cas "mutation : la somme ou le chemin trop long n'est plus coupé → rougit, la page est nommée" sans-code 1 "divulgation/index.html déborde"

copie sans-code-en; muter sans-code-en en/divulgation/index.html "s/main{overflow-wrap:break-word}//; s/code{overflow-wrap:anywhere}//"
cas "mutation : idem sur la page anglaise → rougit, nommée" sans-code-en 1 "en/divulgation/index.html déborde"

# une copie GÉNÉRÉE de la galaxie (déclarée par PROVENANCE) n'est pas mesurée ici ; la même page non déclarée l'est
copie genere; printf '<!doctype html><title>x</title><main><code>%s</code></main>' "$(printf 'x%.0s' $(seq 1 700))" > "$ATELIER/genere/index.html"
mkdir -p "$ATELIER/genere/galaxie"; printf '{"copies": ["index.html", "galaxie/index.html"]}' > "$ATELIER/genere/galaxie/PROVENANCE.json"
cas "une copie de la galaxie déclarée par PROVENANCE n'est pas mesurée → verdit" genere 0 "aucune ne défile"
rm "$ATELIER/genere/galaxie/PROVENANCE.json"
cas "la même page SANS déclaration est mesurée → rougit, nommée" genere 1 "index.html déborde"

# un plantage du NAVIGATEUR (deux observés le 2026-10-08 sous charge) : isolé → réessayé ; répété → la page n'est pas mesurée,
# le garde échoue — jamais un vert par défaut
copie panne
ENVX="DEBORDEMENT_TEST_PANNES=1" cas "un plantage isolé du navigateur est réessayé → verdit" panne 0 "aucune ne défile"
ENVX="DEBORDEMENT_TEST_PANNES=1000" cas "des plantages répétés → la page n'est PAS mesurée, le garde échoue" panne 1 "NON MESURÉE"
cp "$RACINE/scripts/debordement.py" "$ATELIER/deb_sans_retry.py"; sed -i 's/for _essai in (1, 2):/for _essai in (1,):/' "$ATELIER/deb_sans_retry.py"
cmp -s "$RACINE/scripts/debordement.py" "$ATELIER/deb_sans_retry.py" && { echo "✗ la mutation du second essai n'a rien changé (motif périmé)"; exit 1; }
DEB="$ATELIER/deb_sans_retry.py" ENVX="DEBORDEMENT_TEST_PANNES=1" rouge "mutation vue rouge : plus de second essai → le cas « plantage isolé réessayé » échoue" panne 0 "aucune ne défile"
cp "$RACINE/scripts/debordement.py" "$ATELIER/deb_panne_verte.py"; sed -i 's/fautes.append(f"{w}px NON MESURÉE/(lambda *_: None)(f"{w}px NON MESURÉE/' "$ATELIER/deb_panne_verte.py"
cmp -s "$RACINE/scripts/debordement.py" "$ATELIER/deb_panne_verte.py" && { echo "✗ la mutation « panne = vert » n'a rien changé (motif périmé)"; exit 1; }
DEB="$ATELIER/deb_panne_verte.py" ENVX="DEBORDEMENT_TEST_PANNES=1000" rouge "mutation vue rouge : une page non mesurée comptée verte → le cas « plantages répétés = échec » échoue" panne 1 "NON MESURÉE"

rm -rf "$ATELIER/vide"; mkdir -p "$ATELIER/vide"
cas "un dossier sans page n'est PAS un vert" vide 1 "aucune page"

if [ "$ECHECS" -ne 0 ]; then echo "✗ $ECHECS cas trahis"; exit 1; fi
echo "✅ debordement.py verdit sur les pages propres, et rougit sans texte long coupé (FR, EN), et sur un dossier vide"
