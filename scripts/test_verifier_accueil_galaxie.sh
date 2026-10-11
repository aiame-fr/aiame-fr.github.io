#!/usr/bin/env bash
# Preuve par mutation de verifier_accueil_galaxie.sh (règle 5 : un garde jamais vu échouer ne prouve rien). Mutations sur des
# COPIES : accueil périmé, accueil non déclaré, PROVENANCE absente ; témoins : accueil conforme, accueil qui n'est pas la galaxie.
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"; RACINE="$(cd "$ICI/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ECHECS=0; CAS=0
frais() { rm -rf "$T/$1"; mkdir -p "$T/$1/galaxie"; printf '<!doctype html><title>Galaxie AIAME</title><p>page</p>' > "$T/$1/index.html"
  python3 - "$T/$1" <<'PY'
import hashlib, json, sys
r = sys.argv[1]; s = hashlib.sha256(open(r + "/index.html", "rb").read()).hexdigest()
json.dump({"copies": ["index.html", "galaxie/index.html"], "sha256_index_html": s}, open(r + "/galaxie/PROVENANCE.json", "w"))
PY
}
cas() { # <nom> <dossier> <code attendu> <motif>
  CAS=$((CAS+1)); local S c; S="$(bash "$RACINE/scripts/verifier_accueil_galaxie.sh" "$T/$2" 2>&1)"; c=$?
  if [ "$c" -eq "$3" ] && [[ "$S" == *"$4"* ]]; then echo "  ✓ $1"; else ECHECS=$((ECHECS+1)); echo "  ✗ $1 — code $c (attendu $3), motif « $4 »"; printf '%s\n' "$S" | sed 's/^/      | /'; fi
}
frais ok;       cas "témoin : accueil = galaxie, déclarée, à la bonne somme" ok 0 "l'accueil est la galaxie"
frais perime;   printf '<!-- retouche -->' >> "$T/perime/index.html"
                cas "mutation : accueil retouché / périmé (somme différente)" perime 1 "n'a pas la somme"
frais nondecl;  python3 -c "import json,sys; p=sys.argv[1]; d=json.load(open(p)); d['copies']=['galaxie/index.html']; json.dump(d,open(p,'w'))" "$T/nondecl/galaxie/PROVENANCE.json"
                cas "mutation : accueil non déclaré dans copies (le cas #64)" nondecl 1 "ne déclare pas"
frais sansprov; rm "$T/sansprov/galaxie/PROVENANCE.json"
                cas "mutation : PROVENANCE absente alors que l'accueil est la galaxie" sansprov 1 "est absent"
frais autre;    printf '<!doctype html><title>Autre page</title>' > "$T/autre/index.html"; rm "$T/autre/galaxie/PROVENANCE.json"
                cas "témoin : un accueil qui n'est pas la galaxie n'est pas jugé" autre 0 "rien à vérifier"
mkdir -p "$T/vide"; cas "un dossier sans index.html échoue (ce n'est pas un vert)" vide 1 "absent"
if [ "$ECHECS" -eq 0 ]; then echo "ok test_verifier_accueil_galaxie : $CAS cas"; else echo "ECHEC test_verifier_accueil_galaxie : $ECHECS sur $CAS"; exit 1; fi
