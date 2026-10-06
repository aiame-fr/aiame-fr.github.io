#!/usr/bin/env bash
# Harnais de mutation pour verifier_vitrine.sh — prouve que chaque contrôle SAIT échouer.
#
# verifier_vitrine.sh n'affirme que des absences ; une absence passe au vert pour deux raisons indiscernables : la
# propriété tient, ou le contrôle est inopérant. Ce harnais fabrique chaque violation sur une copie jetable et exige que
# le garde la voie. Chaque cas est doublé : un arbre PROPRE qui doit passer, des arbres FAUTIFS qui doivent échouer.
#
#   bash scripts/test_verifier_vitrine.sh
#
# Sortie 0 = le garde est prouvé. Sortie 1 = au moins un contrôle ne sait pas faire son travail.
set -uo pipefail

# Lavage GIT_* : un hook pre-push exporte GIT_DIR ; hérité, il gagnerait contre tout `cd` (voir test_garde_fous.sh).
for _var in $(env | grep -oE '^GIT_[A-Z_]+' || true); do unset "$_var"; done

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GARDE="$RACINE/scripts/verifier_vitrine.sh"
ATELIER="$(mktemp -d)"
trap 'rm -rf "$ATELIER"' EXIT
ECHECS=0

arbre() { # copie jetable des seuls fichiers que le garde lit
  local d="$1"; rm -rf "$d"; mkdir -p "$d/vitrine" "$d/en/vitrine"
  cp "$RACINE/vitrine/index.html" "$d/vitrine/"; cp "$RACINE/en/vitrine/index.html" "$d/en/vitrine/"
  cp "$RACINE/index.html" "$d/"; cp "$RACINE/en/index.html" "$d/en/"
}

doit_passer() {
  local nom="$1" d="$ATELIER/propre"; arbre "$d"
  if bash "$GARDE" "$d" >/dev/null 2>&1; then echo "  ✓ $nom"; else echo "  ✗ $nom — le garde refuse un arbre PROPRE"; ECHECS=$((ECHECS+1)); fi
}

# doit_echouer NOM FICHIER-RELATIF PROGRAMME-PYTHON-DE-MUTATION(t -> t) FRAGMENT-ATTENDU-DANS-LA-SORTIE
doit_echouer() {
  local nom="$1" fichier="$2" mut="$3" attendu="$4" d="$ATELIER/fautif" sortie rc
  arbre "$d"
  MUT="$mut" python3 - "$d/$fichier" <<'PY' || { echo "  ✗ $nom — mutation inapplicable (motif introuvable : le test serait faux)"; ECHECS=$((ECHECS+1)); return; }
import os, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
ns = {"t": t}
exec(os.environ["MUT"], ns)
n = ns["t"]
if n == t:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(n)
PY
  sortie="$(bash "$GARDE" "$d" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$sortie" | grep -q -F "$attendu"; then echo "  ✓ $nom"
  else echo "  ✗ $nom — le garde n'a PAS vu la violation (rc=$rc, attendu « $attendu »)"; ECHECS=$((ECHECS+1)); fi
}

# Injecte du texte juste avant la fermeture de <body> du fichier.
inj() { printf 't = t.replace("</body>", %s + "</body>", 1)' "$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1")"; }

echo "== arbre propre =="
doit_passer "la page telle que livrée est conforme"

echo "== V1 parcours d'achat =="
doit_echouer "FR : formulaire de commande"            vitrine/index.html    "$(inj '<form method="post" action="/api/v1/checkout/form"></form>')" "parcours d'achat"
doit_echouer "EN : formulaire de commande"            en/vitrine/index.html "$(inj '<form method="post" action="/api/v1/checkout/form"></form>')" "parcours d'achat"
doit_echouer "FR : case « agir à titre professionnel »" vitrine/index.html  "$(inj '<input type="checkbox" name="pro_declaration" value="true">')" "parcours d'achat"
doit_echouer "EN : carte de prix"                     en/vitrine/index.html "$(inj '<div class="price">x</div>')" "parcours d'achat"

echo "== V2 promesse de délai =="
doit_echouer "FR : « rendu sous 24 h »"               vitrine/index.html    "$(inj '<p>rendu sous 24 h</p>')" "promesse de délai"
doit_echouer "EN : « within 24 h »"                   en/vitrine/index.html "$(inj '<p>delivered within 24 h</p>')" "promesse de délai"

echo "== V3 vocabulaire d'offre =="
doit_echouer "FR : « Offre réservée aux professionnels »" vitrine/index.html "$(inj '<p>Offre réservée aux professionnels</p>')" "vocabulaire d'offre"
doit_echouer "EN : « reserved for professionals »"    en/vitrine/index.html "$(inj '<p>Offer reserved for professionals</p>')" "vocabulaire d'offre"
doit_echouer "FR : « Sur demande » (prix)"            vitrine/index.html    "$(inj '<p>Sur demande</p>')" "vocabulaire d'offre"
doit_echouer "EN : « On request » (prix)"             en/vitrine/index.html "$(inj '<p>On request</p>')" "vocabulaire d'offre"
doit_echouer "FR : « Demander un scan »"              vitrine/index.html    "$(inj '<a>Demander un scan</a>')" "vocabulaire d'offre"
doit_echouer "EN : « Request a scan »"                en/vitrine/index.html "$(inj '<a>Request a scan</a>')" "vocabulaire d'offre"
doit_echouer "FR : « Ce que vous achetez »"           vitrine/index.html    "$(inj '<p>Ce que vous achetez</p>')" "vocabulaire d'offre"
doit_echouer "EN : « What we deliver »"               en/vitrine/index.html "$(inj '<h2>What we deliver</h2>')" "vocabulaire d'offre"

echo "== V4 la page dit son statut =="
doit_echouer "FR : marqueur data-statut retiré"       vitrine/index.html    't = t.replace(" data-statut=\"instrument-pas-une-offre\"", "")' "section « statut » absente"
doit_echouer "EN : marqueur data-statut retiré"       en/vitrine/index.html 't = t.replace(" data-statut=\"instrument-pas-une-offre\"", "")' "section « statut » absente"
doit_echouer "FR : le mot « tiers » disparaît du statut" vitrine/index.html 'a = t.index("<section id=\"statut\""); b = t.index("</section>", a); t = t[:a] + t[a:b].replace("tiers", "autres").replace("Tiers", "Autres") + t[b:]' "n'a jamais tourné chez un tiers"
doit_echouer "EN : « third party » disparaît du statut" en/vitrine/index.html 'a = t.index("<section id=\"statut\""); b = t.index("</section>", a); t = t[:a] + t[a:b].replace("third part", "other part") + t[b:]' "never ran on a third party"

echo "== V5 meta description =="
doit_echouer "FR : « sans traqueur » retiré de la meta" vitrine/index.html  'import re; t = re.sub(r"(<meta name=\"description\"[^>]*?), sans traqueur", r"\1", t, count=1)' "sans traqueur"
doit_echouer "EN : « no tracker » retiré de la meta"    en/vitrine/index.html 'import re; t = re.sub(r"(<meta name=\"description\"[^>]*?), no tracker", r"\1", t, count=1)' "no tracker"
doit_echouer "FR : l'hébergement retiré de la meta"    vitrine/index.html    'import re; t = re.sub(r"(<meta name=\"description\"[^>]*?)Hetzner", r"\1Autre", t, count=1)' "ne cite plus l'hébergement"
doit_echouer "FR : « pas une offre » retiré de la meta" vitrine/index.html   'import re; t = re.sub(r"(<meta name=\"description\"[^>]*?)pas une offre", r"\1une offre", t, count=1)' "pas une offre"

echo "== V6 contact =="
doit_echouer "FR : plus de lien de contact"           vitrine/index.html    't = t.replace("mailto:tech@aiame.fr", "#")' "contact"
doit_echouer "EN : plus de lien de contact"           en/vitrine/index.html 't = t.replace("mailto:tech@aiame.fr", "#")' "contact"

echo "== V7 parité FR/EN =="
doit_echouer "EN : une section manque"                en/vitrine/index.html 'import re; t = re.sub(r"<section id=\"engagements\">.*?</section>", "", t, count=1, flags=re.S)' "sections différentes"
doit_echouer "FR : un lien en plus"                   vitrine/index.html    "$(inj '<a href="https://example.org/x">x</a>')" "liens différents"

echo "== V8 portfolio =="
doit_echouer "FR accueil : « vendu comme offre »"     index.html            "$(inj '<p>vendu comme offre</p>')" "présenté comme offre"
doit_echouer "FR accueil : « vitrine commerciale »"   index.html            "$(inj '<p>vitrine commerciale</p>')" "présenté comme offre"
doit_echouer "EN accueil : « sold as an offer »"      en/index.html         "$(inj '<p>sold as an offer</p>')" "présenté comme offre"
doit_echouer "EN accueil : « commercial showcase »"   en/index.html         "$(inj '<p>commercial showcase</p>')" "présenté comme offre"

echo
if [ "$ECHECS" -eq 0 ]; then echo "✅ verifier_vitrine.sh est prouvé : chaque contrôle voit sa violation."; exit 0; fi
echo "✗ $ECHECS contrôle(s) du garde ne savent pas faire leur travail."; exit 1
