#!/usr/bin/env bash
# verifier_vitrine.sh [RACINE] — la page Aiame Red (/vitrine/ et /en/vitrine/) n'est PAS une offre.
#
# Pourquoi ce garde existe : le 2026-10-05 le propriétaire a corrigé le fait que la page présentait Aiame Red comme une
# offre (formulaire d'achat, « rendu sous 24 h », cartes de prix) alors que le moteur n'a jamais tourné que sur nos
# propres produits et que rien n'a été vendu (LEDGER-STATUS.json : `offered_sandbox_only`). Ce garde empêche le retour
# silencieux de cette présentation, en FR comme en EN, et exige que la page DISE son statut.
#
# Chaque contrôle affirme une ABSENCE (ou une présence exigée) : il est prouvé par test_verifier_vitrine.sh, qui fabrique
# la violation et exige que ce script la voie.
#
# Sortie 0 = conforme. Sortie 1 = au moins une violation.
set -uo pipefail

R="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FAIL=0
bad() { echo "VIOLATION: $*"; FAIL=1; }

for langue in fr en; do
  if [ "$langue" = fr ]; then f="$R/vitrine/index.html"; else f="$R/en/vitrine/index.html"; fi
  if [ ! -f "$f" ]; then bad "$langue : $f absent"; continue; fi

  # V1 — aucun parcours d'achat : formulaire, case « déclare agir à titre professionnel », carte de prix.
  if grep -n -i -E '<form|/api/v1/checkout|pro_declaration|type="checkbox"|class="price"|class="card"|class="buy"' "$f"; then
    bad "$langue : parcours d'achat présent (formulaire, case professionnelle ou carte de prix)"
  fi

  # V2 — aucune promesse de délai : rien n'a jamais été livré à un tiers.
  if grep -n -i -E '24 ?h|&lt; ?24|sous 24|within 24' "$f"; then
    bad "$langue : promesse de délai de livraison"
  fi

  # V3 — aucun vocabulaire d'offre ou de commande. (« sur demande » n'est interdit que comme étiquette de prix,
  # seule dans son élément : le pilier B2H « ne parle que sur demande » est légitime.)
  if grep -n -i -E "offre réservée|offer reserved|reserved for professionals|aux professionnels|>sur demande<|>on request<|tarifs? communiqués?|pricing communicated|ce que vous achetez|what you buy|ce que nous livrons|what we deliver|demander un (scan|audit)|request a (scan|product audit)|pas encore vendable|not sellable yet" "$f"; then
    bad "$langue : vocabulaire d'offre ou de commande"
  fi

  # V4 — la page DIT son statut : une section marquée, qui nomme les tiers (aucun passage chez un tiers).
  statut="$(awk '/<section id="statut"/{p=1} p{print} /<\/section>/{if(p) exit}' "$f")"
  if ! printf '%s' "$statut" | grep -q 'data-statut="instrument-pas-une-offre"'; then
    bad "$langue : section « statut » absente ou non marquée data-statut=\"instrument-pas-une-offre\""
  elif [ "$langue" = fr ] && ! printf '%s' "$statut" | grep -q -i 'tiers'; then
    bad "fr : la section statut ne dit pas que le moteur n'a jamais tourné chez un tiers"
  elif [ "$langue" = en ] && ! printf '%s' "$statut" | grep -q -i 'third part'; then
    bad "en : the status section does not say the engine never ran on a third party"
  fi

  # V5 — la description (meta) reste celle que SOURCES.md invoque : hébergement UE et « sans traqueur ».
  meta="$(grep -m1 -i '<meta name="description"' "$f")"
  if ! printf '%s' "$meta" | grep -q 'Hetzner'; then bad "$langue : la meta description ne cite plus l'hébergement (SOURCES.md s'y appuie)"; fi
  if [ "$langue" = fr ] && ! printf '%s' "$meta" | grep -q -i 'sans traqueur'; then bad "fr : la meta description ne dit plus « sans traqueur » (SOURCES.md s'y appuie)"; fi
  if [ "$langue" = en ] && ! printf '%s' "$meta" | grep -q -i 'no tracker'; then bad "en : the meta description no longer says « no tracker » (SOURCES.md relies on it)"; fi
  if ! printf '%s' "$meta" | grep -q -i -E 'pas une offre|not an offer'; then bad "$langue : la meta description ne dit pas « pas une offre » / « not an offer »"; fi

  # V6 — le contact subsiste (la page invite à écrire, elle ne ferme pas la porte).
  if ! grep -q 'mailto:tech@aiame.fr' "$f"; then bad "$langue : plus aucun lien de contact tech@aiame.fr"; fi
done

# V7 — parité FR/EN : mêmes sections, dans le même ordre, mêmes liens (hors interrupteur de langue et objet du mail).
if [ -f "$R/vitrine/index.html" ] && [ -f "$R/en/vitrine/index.html" ]; then
  python3 - "$R/vitrine/index.html" "$R/en/vitrine/index.html" <<'PY' || FAIL=1
import re, sys
def lire(p):
    t = open(p, encoding="utf-8").read()
    sections = re.findall(r'<section id="([^"]+)"', t)
    hrefs = []
    for m in re.finditer(r'<a ([^>]*)href="([^"]+)"([^>]*)>', t):
        if 'class="lang"' in m.group(0):
            continue
        h = m.group(2)
        h = re.sub(r'^/en(?=/)', '', h)              # /en/transparence.html ≡ /transparence.html
        h = re.sub(r'^mailto:([^?]+)\?.*$', r'mailto:\1', h)  # l'objet du mail est traduit
        hrefs.append(h)
    return sections, sorted(set(hrefs))
sf, hf = lire(sys.argv[1]); se, he = lire(sys.argv[2])
ok = True
if sf != se:
    print(f"VIOLATION: parité FR/EN — sections différentes : fr={sf} en={se}"); ok = False
if hf != he:
    print(f"VIOLATION: parité FR/EN — liens différents : {sorted(set(hf) ^ set(he))}"); ok = False
sys.exit(0 if ok else 1)
PY
fi

# V8 — le portfolio (accueil) ne présente plus Aiame Red comme une offre vendue ni la page comme « vitrine commerciale ».
for f in "$R/index.html" "$R/en/index.html"; do
  [ -f "$f" ] || { bad "$f absent"; continue; }
  if grep -n -i -E 'vendu comme offre|sold as an offer|vitrine commerciale|commercial showcase' "$f"; then
    bad "$(basename "$(dirname "$f")")/$(basename "$f") : Aiame Red présenté comme offre ou vitrine commerciale"
  fi
done

if [ "$FAIL" -eq 0 ]; then echo "OK : la page Aiame Red n'est pas présentée comme une offre (FR, EN, portfolio)"; fi
exit "$FAIL"
