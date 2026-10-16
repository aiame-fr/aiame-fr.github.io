#!/usr/bin/env bash
# verifier_galaxie_ia.sh [RACINE] — la galaxie IA publiée (galaxie-ia/index.html) est EXTRAITE d'aiame-workspace, jamais retouchée ici.
#
# Pourquoi : la page vient de `galaxie_ia.py --publier` (aiame-workspace) ; sa somme vit dans galaxie-ia/PROVENANCE.json. Le garde de
# la galaxie (galaxie/) ne regarde que galaxie/ : sans celui-ci, une retouche à la main de galaxie-ia/index.html, ou une PROVENANCE qui
# ment sur sa somme, passerait au pre-push. Péremption (la copie diffère de la page régénérée) : `galaxie_ia.py --verifier-publie`
# côté workspace — pas d'ici, qui n'a pas les sources.
#
# Rien n'est publié tant que ni galaxie-ia/index.html ni galaxie-ia/PROVENANCE.json n'existent (ok, rien à vérifier). Dès que l'un des
# deux existe, les deux doivent exister et s'accorder. Sortie 0 = conforme · 1 = violation.
set -uo pipefail
R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
D="$R/galaxie-ia"
P="$D/PROVENANCE.json"; H="$D/index.html"
if [ ! -e "$H" ] && [ ! -e "$P" ]; then echo "ok : la galaxie IA n'est pas publiée sur ce site (rien à vérifier)"; exit 0; fi
[ -f "$H" ] || { echo "VIOLATION: $P existe mais $H est absent"; exit 1; }
[ -f "$P" ] || { echo "VIOLATION: $H existe mais $P est absent — une copie sans provenance ne prouve rien"; exit 1; }
python3 - "$P" "$H" <<'PY'
import hashlib, json, sys
try:
    prov = json.load(open(sys.argv[1], encoding="utf-8"))
except ValueError:
    print("VIOLATION: PROVENANCE.json illisible — on ne devine pas la somme déclarée"); sys.exit(1)
raw = open(sys.argv[2], "rb").read()
somme = hashlib.sha256(raw).hexdigest()
err = []
if somme != prov.get("sha256_index_html"):
    err.append(f"galaxie-ia/index.html ({somme[:12]}…) n'a pas la somme de PROVENANCE ({str(prov.get('sha256_index_html'))[:12]}…) : copie retouchée après publication")
if prov.get("copies") != ["galaxie-ia/index.html"]:
    err.append(f"PROVENANCE.copies vaut {prov.get('copies')!r}, attendu ['galaxie-ia/index.html']")
for champ in ("commit_source", "releve"):
    if not prov.get(champ):
        err.append(f"PROVENANCE.{champ} absent : on ne sait pas d'où vient la page ni quand elle a été relevée")
if b"<title>Galaxie IA AIAME</title>" not in raw:
    err.append("galaxie-ia/index.html n'est pas la page « Galaxie IA AIAME »")
print("\n".join("VIOLATION: " + e for e in err))
sys.exit(1 if err else 0)
PY
rc=$?; [ $rc -eq 0 ] && echo "ok : galaxie-ia/index.html est la copie déclarée par PROVENANCE (somme, copie, source, relevé)"; exit $rc
