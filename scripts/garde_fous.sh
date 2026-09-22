#!/usr/bin/env bash
# AIAME garde-fous — doctrinal blocking checks (canonical copy: aiame-doctrine).
# Doctrine: frontier models never in the execution path (three-stage rule);
# secrets never in history; measured wording over marketing wording; no
# standing AIAME-side credential to an Elzeard tenant's data (ADR-PC-023,
# elz-core — "capability shared, never the data").
# Usage: garde_fous.sh <runtime_src_dir> [deps_file...]
set -euo pipefail

SRC="${1:?usage: garde_fous.sh <runtime_src_dir> [deps_file...]}"
shift || true
FAIL=0

# Répertoires de DÉPENDANCES, jamais de code écrit ici : un venv/node_modules
# installé embarque des paquets tiers qui importent légitimement openai/
# anthropic ou déclarent une clé "mcpServers" dans leur propre config — grep
# -r sans exclusion les lit comme si c'était notre code d'exécution. Mesuré en
# direct le 18/08 : l'intégration OpenAI/Anthropic de sentry_sdk (dépendance
# transitive) sous .venv/ a fait échouer GF-1 sur un arbre par ailleurs propre,
# deux fois, dans deux dépôts différents. Motif déjà en usage ailleurs dans
# l'org (node_modules/.venv/__pycache__/.git/dist/build), plus .next (build
# Next.js) et target (build Rust/Cargo, aiame-core).
EXCLURE_DEPS=(
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.venv
  --exclude-dir=__pycache__ --exclude-dir=dist --exclude-dir=build
  --exclude-dir=.next --exclude-dir=target --exclude-dir=out
)
# `out/` ajouté le 2026-09-21 : c'est le répertoire d'export statique de Next
# (`aiame-eu/services/apod/frontend/out/`, `aiame-miroir/frontend/out/`), aussi
# généré que `dist/` ou `.next/`. Son absence ici ne se voyait pas tant que
# GF-5 ne lisait ni .css ni .html — élargir la portée l'a rendue visible.

echo "== GF-1 frontier-in-execution (blocking) =="
if grep -rn -iE 'from openai|import openai|import anthropic|from anthropic|api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis' \
    "$SRC" --include='*.py' --include='*.ts' --include='*.tsx' --include='*.rs' \
    "${EXCLURE_DEPS[@]}"; then
  echo "VIOLATION: frontier provider referenced in runtime code"; FAIL=1
else
  echo "OK: no frontier provider in runtime code"
fi
for f in "$@"; do
  if [ -f "$f" ] && grep -iE '^\s*(openai|anthropic|google-generativeai)' "$f"; then
    echo "VIOLATION: frontier dependency declared in $f"; FAIL=1
  fi
done

echo "== GF-2 secrets-in-tree (blocking) =="
if git ls-files | grep -E '(^|/)\.env(\..+)?$' | grep -v '\.example$'; then
  echo "VIOLATION: .env file tracked by git"; FAIL=1
else
  echo "OK: no tracked .env files"
fi

echo "== GF-3 discours-vs-mesure (warning only) =="
grep -rn -iE '"[^"]*(temps réel|real[- ]time|intelligent)[^"]*"' "$SRC" \
  --include='*.ts' --include='*.tsx' "${EXCLURE_DEPS[@]}" | head -5 \
  && echo "WARN: unmeasured-claim wording found (ban until measured — NN-4)" \
  || echo "OK: no banned wording"

echo "== GF-4 elzeard-mcp-boundary (blocking) =="
# ADR-PC-023 (elz-core): AIAME's own hosted stack may never hold a standing
# credential to Elzeard's tenant-scoped MCP server. Two shapes of that
# violation: a real product-core tenant key (pck_<lookup_id>_<secret>, where
# both halves are actual random-looking strings — the placeholder itself, as
# written in doctrine prose, has no matching chars after the underscores and
# is deliberately not matched here), or an MCP client registration.
if grep -rn -E 'pck_[A-Za-z0-9]{6,}_[A-Za-z0-9]{16,}|"mcpServers"' \
    "$SRC" --include='*.py' --include='*.ts' --include='*.tsx' --include='*.rs' --include='*.json' --include='*.yml' --include='*.yaml' \
    "${EXCLURE_DEPS[@]}"; then
  echo "VIOLATION: Elzeard tenant credential or MCP client registration found (ADR-PC-023)"; FAIL=1
elif find "$SRC" \( -iname .git -o -iname node_modules -o -iname .venv -o -iname __pycache__ -o -iname dist -o -iname build -o -iname .next -o -iname target \) -prune -o -type f -iname '.mcp.json' -print 2>/dev/null | grep -q .; then
  echo "VIOLATION: .mcp.json tracked in runtime tree (ADR-PC-023)"; FAIL=1
else
  echo "OK: no Elzeard tenant credential or MCP client registration"
fi

echo "== GF-5 third-party-scrape-boundary (blocking) =="
# Trou de doctrine fermé le 2026-08-24 : avant aiame-price (agent de veille
# tarifaire BTP/Würth), aiame-doctrine n'avait aucune règle sur la collecte de
# données commerciales tierces. Portée volontairement étroite : ne regarde que
# les fichiers qui appellent ET un domaine EXTERNE (ni aiame.fr, nu ou en
# sous-domaine, ni localhost) littéralement présent — un client HTTP interne
# (aiame-auth, aiame-store, etc.) n'a pas à parler de robots.txt. Deux formes
# de violation sur ces fichiers-là : (1) aucune mention de robots.txt ou de
# limite de débit dans le même fichier, SAUF marqueur api-tierce-sous-contrat
# (voir plus bas) ; (2) le domaine cité n'apparaît pas dans un manifeste
# SOURCES.md à la racine (ou un niveau sous, ex. docs/) du dépôt — pas juste
# "le fichier existe", chaque domaine doit y être nommé, TOUJOURS, y compris
# sous le marqueur.
#
# Deux trous trouvés le 2026-09-05, en resynchronisant 4 dépôts en retard :
# (a) un domaine réservé à la doc/aux tests (RFC 2606 : example.com/.net/.org,
#     TLD .test/.example/.invalid/.localhost) dans une fixture de test n'est
#     jamais un vrai appel réseau — grep sur du texte l'ignorait déjà pour les
#     dépendances (EXCLURE_DEPS) mais pas pour ces domaines-placeholder ;
# (b) la portée "scraping" ne distingue pas un site public à collecter (le
#     public visé) d'une API tierce AUTHENTIFIÉE SOUS CONTRAT (PSP Stripe/
#     SumUp, etc.) — celle-ci n'a ni robots.txt ni notion de "limite de débit
#     polie", exiger l'un ou l'autre est un non-sens qui aurait bloqué tout
#     futur intégrateur de paiement. Le marqueur `GF-5: api-tierce-sous-contrat`
#     (commentaire, n'importe où dans le fichier) lève UNIQUEMENT ces deux
#     exigences-là ; la déclaration SOURCES.md, elle, reste due dans tous les
#     cas — la transparence sur qui on appelle n'est jamais négociable, seule
#     l'étiquette "scraping" l'est.
#
# Troisième trou, trouvé le 2026-09-21 : `aiame-services` servait en PRODUCTION
# un `@import url("https://fonts.googleapis.com/...")` en première ligne de son
# bundle CSS — chaque rendu de page envoyait l'IP et le User-Agent du visiteur
# chez Google LLC. GF-5 ne pouvait pas le voir, et la cause première n'était PAS
# le motif : c'était le FILTRE DE TYPE. Seuls *.py/*.ts/*.tsx étaient ouverts,
# donc un .css n'était jamais lu, quoi qu'il contînt. Durcir le motif seul
# n'aurait rien changé. D'où deux corrections, dans cet ordre :
#   (1) *.css et *.html entrent dans la portée ;
#   (2) sur CES DEUX types uniquement, le motif couvre les formes DÉCLARATIVES,
#       celles que le navigateur exécute sans qu'aucun code ne les appelle
#       (@import, <link href>, <script src>, url()). Ces motifs exigent
#       `https?://` À L'INTÉRIEUR de la construction : un `url(/logo.svg)`
#       local ne déclenche donc rien.
#
# Les deux bornes ci-dessous ne sont pas de la prudence, elles sont MESURÉES
# sur la flotte réelle (ancien script contre nouveau, 12 dépôts) :
#   - Le motif déclaratif ne tourne PAS sur .py/.ts : un `<link href="http://
#     arxiv.org/...">` dans une fixture Atom XML d'`aiame-rag` est de la
#     DONNÉE, pas un document rendu. Le passer au même filtre produisait un
#     faux positif immédiat.
#   - `.js`/`.jsx` restent HORS portée, et c'est un choix documenté, pas un
#     oubli : la flotte n'a AUCUN .js runtime écrit à la main (vérifié sur tous
#     les `frontend/src/`) — uniquement du vendoré ou du généré
#     (`public/mediapipe/wasm/*.js` de miroir, `src/vendor/wasm_*.js` de sov,
#     colle wasm-bindgen). Les y inclure produisait 22 violations dans le seul
#     miroir, toutes sur du code tiers jamais écrit par nous — et PUNISSAIT le
#     dépôt qui a justement fait le bon geste en vendorisant au lieu d'appeler
#     un CDN. Un garde-fou qui refuse la forme légitime n'est pas plus sûr,
#     il devient impossible à garder vert. Gap assumé : un .js écrit à la main
#     n'est pas couvert ; le jour où il en existe un, ce commentaire est la
#     trace de la décision à rouvrir.
#
# Une référence déclarative n'est PAS de la collecte : exiger d'une feuille de
# style qu'elle « mentionne robots.txt » ou déclare une « limite de débit »
# serait un non-sens, exactement celui que le marqueur api-tierce-sous-contrat
# existe pour éviter. Un fichier dont le SEUL déclencheur est déclaratif est
# donc dispensé de ces deux exigences — et de celles-là uniquement. Le
# SOURCES.md reste dû : c'est la règle qui ne plie jamais.
GF5_MOTIF_APPEL='requests\.(get|post)\(|httpx\.(get|post|AsyncClient)\(|urlopen\(|fetch\('
GF5_MOTIF_DECLARATIF='@import[[:space:]]+[^;]*https?://|<link[^>]+href=[^>]*https?://|<script[^>]+src=[^>]*https?://|url\([^)]*https?://'
GF5_APPELANTS=$(grep -rlE "$GF5_MOTIF_APPEL" \
    "$SRC" --include='*.py' --include='*.ts' --include='*.tsx' \
    "${EXCLURE_DEPS[@]}" 2>/dev/null || true)
GF5_DECLARANTS=$(grep -rlE "$GF5_MOTIF_DECLARATIF" \
    "$SRC" --include='*.css' --include='*.html' \
    "${EXCLURE_DEPS[@]}" 2>/dev/null || true)
GF5_FETCH=$(printf '%s\n%s\n' "$GF5_APPELANTS" "$GF5_DECLARANTS" | grep -v '^$' | sort -u || true)
GF5_MANIFESTE=$(find . -maxdepth 2 \( -iname .git -o -iname node_modules -o -iname .venv \) -prune -o -type f -iname 'SOURCES.md' -print 2>/dev/null | head -1 || true)
GF5_OK=1
for f in $GF5_FETCH; do
  GF5_DOMAINES=$(grep -ohE 'https?://[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$f" 2>/dev/null \
    | sed -E 's#https?://##' \
    | grep -viE '(^|\.)aiame\.fr$|\.(test|example|invalid|localhost)$|^example\.(com|net|org)$' \
    | sort -u || true)
  [ -n "$GF5_DOMAINES" ] || continue
  if grep -qi 'GF-5: api-tierce-sous-contrat' "$f"; then
    : # API authentifiée sous contrat (PSP, etc.) — pas du scraping ; le
      # domaine reste dû en SOURCES.md, jamais dispensé plus bas.
  elif ! grep -qE "$GF5_MOTIF_APPEL" "$f"; then
    : # Référence déclarative d'asset uniquement (@import, <link>, <script>,
      # url()) : aucun code n'appelle, c'est le navigateur qui charge. Ni
      # robots.txt ni limite de débit n'ont de sens ici. Le domaine reste dû
      # en SOURCES.md — même règle que ci-dessus, et pour la même raison.
  else
    grep -qi 'robots' "$f" \
      || { echo "VIOLATION: $f appelle un domaine externe ($GF5_DOMAINES) sans mention de robots.txt"; GF5_OK=0; }
    grep -qE 'rate_limit|time\.sleep\(|asyncio\.sleep\(' "$f" \
      || { echo "VIOLATION: $f appelle un domaine externe ($GF5_DOMAINES) sans limite de débit déclarée"; GF5_OK=0; }
  fi
  if [ -z "$GF5_MANIFESTE" ]; then
    echo "VIOLATION: $f cite un domaine externe ($GF5_DOMAINES), aucun SOURCES.md dans le dépôt"; GF5_OK=0
  else
    for d in $GF5_DOMAINES; do
      grep -qi "$d" "$GF5_MANIFESTE" \
        || { echo "VIOLATION: domaine $d cité dans $f mais absent de $GF5_MANIFESTE"; GF5_OK=0; }
    done
  fi
done
if [ "$GF5_OK" = 1 ]; then
  echo "OK: no third-party fetch without robots/rate-limit ack and SOURCES.md entry"
else
  FAIL=1
fi

exit $FAIL
