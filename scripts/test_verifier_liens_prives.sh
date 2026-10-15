#!/usr/bin/env bash
# Preuve par mutation de verifier_liens_prives.sh (règle 5). Sur des copies : lien privé en FR, en EN, avec www/http,
# dans un .json, vers un dépôt privé au nom voisin d'un public ; témoins : lien public, profil de l'organisation.
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ECHECS=0; CAS=0
base() { rm -rf "$T/$1"; mkdir -p "$T/$1/en"; printf '<p>ok <a href="https://github.com/aiame-fr/aiame-fr.github.io">site</a> <a href="https://github.com/aiame-fr">org</a></p>' > "$T/$1/index.html"; cp "$T/$1/index.html" "$T/$1/en/index.html"; }
cas() { # <nom> <dossier> <code attendu> <motif>
  CAS=$((CAS+1)); local S c; S="$(bash "$ICI/verifier_liens_prives.sh" "$T/$2" 2>&1)"; c=$?
  if [ "$c" -eq "$3" ] && [[ "$S" == *"$4"* ]]; then echo "  ✓ $1"; else ECHECS=$((ECHECS+1)); echo "  ✗ $1 — code $c (attendu $3), motif « $4 »"; printf '%s\n' "$S" | sed 's/^/      | /'; fi
}
base ok;   cas "témoin : lien public + profil de l'organisation" ok 0 "aucun lien"
base fr;   printf '<a href="https://github.com/aiame-fr/aiame-ledger">x</a>' >> "$T/fr/index.html"
           cas "mutation : lien privé en français" fr 1 "index.html : lien vers un dépôt non public"
base en;   printf '<a href="https://github.com/aiame-fr/aiame-doctrine/blob/main/X.md">x</a>' >> "$T/en/en/index.html"
           cas "mutation : lien privé dans la page anglaise (nomme le fichier)" en 1 "en/index.html"
base www;  printf '<a href="http://www.github.com/aiame-fr/aiame-miroir">x</a>' >> "$T/www/index.html"
           cas "mutation : forme http://www." www 1 "aiame-miroir"
base js;   printf '{"source":"https://github.com/aiame-fr/aiame-sov/blob/main/a.py"}' > "$T/js/data.json"
           cas "mutation : lien privé dans un .json publié" js 1 "data.json"
base voisin; printf '<a href="https://github.com/aiame-fr/aiame-fr.github.io-prive">x</a>' >> "$T/voisin/index.html"
           cas "mutation : dépôt privé au nom qui COMMENCE comme le public" voisin 1 "aiame-fr.github.io-prive"
base ok2;  printf '<a href="https://github.com/aiame-fr/aiame-fr.github.io/blob/main/scripts/x.sh">x</a>' >> "$T/ok2/index.html"
           cas "témoin : chemin dans le dépôt public" ok2 0 "aucun lien"
if [ "$ECHECS" -eq 0 ]; then echo "ok test_verifier_liens_prives : $CAS cas"; else echo "ECHEC test_verifier_liens_prives : $ECHECS sur $CAS"; exit 1; fi
