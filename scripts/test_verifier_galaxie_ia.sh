#!/usr/bin/env bash
# Preuve par mutation de verifier_galaxie_ia.sh (règle 5 : un garde jamais vu échouer ne prouve rien). Mutations sur des COPIES :
# page retouchée, PROVENANCE qui ment, PROVENANCE absente, page absente, mauvaise liste de copies, source ou relevé absents, page
# d'un autre titre, PROVENANCE illisible ; témoins : copie conforme, galaxie IA non publiée.
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"; RACINE="$(cd "$ICI/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ECHECS=0; CAS=0
frais() { rm -rf "$T/$1"; mkdir -p "$T/$1/galaxie-ia"; printf '<!doctype html><title>Galaxie IA AIAME</title><p>page</p>' > "$T/$1/galaxie-ia/index.html"
  python3 - "$T/$1" <<'PY'
import hashlib, json, sys
r = sys.argv[1]; s = hashlib.sha256(open(r + "/galaxie-ia/index.html", "rb").read()).hexdigest()
json.dump({"copies": ["galaxie-ia/index.html"], "sha256_index_html": s, "commit_source": "0" * 40, "releve": "2026-10-16"}, open(r + "/galaxie-ia/PROVENANCE.json", "w"))
PY
}
modifier() { python3 - "$1" "$2" "$3" <<'PY'
import json, sys
p, cle, val = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(p))
if val == "__SUPPRIMER__": d.pop(cle, None)
else: d[cle] = json.loads(val)
json.dump(d, open(p, "w"))
PY
}
cas() { # <nom> <dossier> <code attendu> <motif>
  CAS=$((CAS+1)); local S c; S="$(bash "$RACINE/scripts/verifier_galaxie_ia.sh" "$T/$2" 2>&1)"; c=$?
  if [ "$c" -eq "$3" ] && [[ "$S" == *"$4"* ]]; then echo "  ✓ $1"; else ECHECS=$((ECHECS+1)); echo "  ✗ $1 — code $c (attendu $3), motif « $4 »"; printf '%s\n' "$S" | sed 's/^/      | /' | head -6; fi
}
frais ok;      cas "témoin : copie conforme (somme, copie, source, relevé)" ok 0 "est la copie déclarée"
frais retouche; printf '<!-- retouche -->' >> "$T/retouche/galaxie-ia/index.html"
               cas "mutation : page retouchée à la main après publication" retouche 1 "copie retouchée après publication"
frais ment;    modifier "$T/ment/galaxie-ia/PROVENANCE.json" sha256_index_html '"0000000000000000000000000000000000000000000000000000000000000000"'
               cas "mutation : PROVENANCE qui ment sur la somme" ment 1 "n'a pas la somme"
frais sansprov; rm "$T/sansprov/galaxie-ia/PROVENANCE.json"
               cas "mutation : page sans PROVENANCE" sansprov 1 "une copie sans provenance ne prouve rien"
frais sanspage; rm "$T/sanspage/galaxie-ia/index.html"
               cas "mutation : PROVENANCE sans page" sanspage 1 "est absent"
frais copies;  modifier "$T/copies/galaxie-ia/PROVENANCE.json" copies '["galaxie-ia/index.html","index.html"]'
               cas "mutation : liste de copies qui n'est pas exactement la page IA" copies 1 "PROVENANCE.copies vaut"
frais source;  modifier "$T/source/galaxie-ia/PROVENANCE.json" commit_source __SUPPRIMER__
               cas "mutation : commit source absent" source 1 "PROVENANCE.commit_source absent"
frais releve;  modifier "$T/releve/galaxie-ia/PROVENANCE.json" releve __SUPPRIMER__
               cas "mutation : date du relevé absente" releve 1 "PROVENANCE.releve absent"
frais autre;   printf '<!doctype html><title>Autre page</title>' > "$T/autre/galaxie-ia/index.html"
               python3 - "$T/autre" <<'PY'
import hashlib, json, sys
r = sys.argv[1]; p = r + "/galaxie-ia/PROVENANCE.json"; d = json.load(open(p))
d["sha256_index_html"] = hashlib.sha256(open(r + "/galaxie-ia/index.html", "rb").read()).hexdigest(); json.dump(d, open(p, "w"))
PY
               cas "mutation : une autre page, même avec la bonne somme" autre 1 "n'est pas la page « Galaxie IA AIAME »"
frais illisible; printf '{pas du json' > "$T/illisible/galaxie-ia/PROVENANCE.json"
               cas "mutation : PROVENANCE illisible" illisible 1 "illisible"
mkdir -p "$T/vide"; cas "témoin : galaxie IA non publiée → rien à vérifier (pas un faux rouge)" vide 0 "n'est pas publiée"
if [ "$ECHECS" -eq 0 ]; then echo "ok test_verifier_galaxie_ia : $CAS cas"; else echo "ECHEC test_verifier_galaxie_ia : $ECHECS sur $CAS"; exit 1; fi
