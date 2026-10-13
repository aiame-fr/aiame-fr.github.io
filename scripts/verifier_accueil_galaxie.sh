#!/usr/bin/env bash
# verifier_accueil_galaxie.sh [RACINE] — quand index.html (l'accueil) est une copie de la galaxie, galaxie/PROVENANCE.json doit
# la DÉCLARER (copies) et sa somme doit être celle de PROVENANCE.
#
# Pourquoi : le 2026-10-10, #64 a republié /galaxie/ sans --accueil. PROVENANCE.copies est retombé à ['galaxie/index.html'],
# l'accueil réellement servi est resté une version en arrière, et le garde « somme de galaxie/index.html » ne voyait rien : il ne
# contrôle que la copie qu'on lui montre. Ce script contrôle l'accueil lui-même, indépendamment de l'outil qui a publié.
#
# Sortie 0 = conforme (ou accueil qui n'est pas une copie de la galaxie : rien à vérifier) · 1 = violation.
set -uo pipefail
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
P="$R/galaxie/PROVENANCE.json"
[ -f "$R/index.html" ] || { echo "VIOLATION: $R/index.html absent"; exit 1; }
grep -q '<title>Galaxie AIAME</title>' "$R/index.html" || { echo "ok : index.html n'est pas une copie de la galaxie (rien à vérifier)"; exit 0; }
[ -f "$P" ] || { echo "VIOLATION: index.html est une copie de la galaxie mais $P est absent"; exit 1; }
python3 - "$P" "$R/index.html" <<'PY'
import hashlib, json, sys
prov = json.load(open(sys.argv[1], encoding="utf-8"))
somme = hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest()
err = []
if "index.html" not in prov.get("copies", []):
    err.append("index.html est une copie de la galaxie que PROVENANCE.copies ne déclare pas (republiée sans --accueil ?) : l'accueil servi n'est plus vérifié")
if somme != prov.get("sha256_index_html"):
    err.append(f"index.html ({somme[:12]}…) n'a pas la somme de PROVENANCE ({str(prov.get('sha256_index_html'))[:12]}…) : accueil périmé ou retouché")
print("\n".join("VIOLATION: " + e for e in err))
sys.exit(1 if err else 0)
PY
rc=$?; [ $rc -eq 0 ] && echo "ok : l'accueil est la galaxie, déclarée et à la somme de PROVENANCE"; exit $rc
