#!/usr/bin/env bash
# Harnais de mutation pour garde_fous.sh — applique PRATIQUE-PROUVER-LE-GARDE-FOU.md
# à garde_fous.sh lui-même.
#
# Chaque contrôle du script (GF-1, GF-2, GF-3) affirme une ABSENCE. Une telle
# affirmation passe au vert pour deux raisons indiscernables : la propriété
# tient, ou le contrôle est inopérant. Ce harnais lève l'ambiguïté — il
# fabrique la violation et exige que le script la voie.
#
# Chaque cas est donc doublé : un arbre FAUTIF qui doit échouer, et un arbre
# PROPRE qui doit passer. Un garde-fou qui hurle toujours ne vaut pas mieux
# qu'un garde-fou muet : les deux sont ignorés au bout d'une semaine.
#
#   ./garde-fous/test_garde_fous.sh
#
# Sortie 0 = les garde-fous sont prouvés. Sortie 1 = au moins un ne sait pas
# faire son travail.

set -uo pipefail  # PAS -e : on lance délibérément des commandes qui échouent

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GF="$RACINE/garde_fous.sh"
ATELIER="$(mktemp -d)"
trap 'rm -rf "$ATELIER"' EXIT

ECHECS=0
CAS=0

# --- utilitaires -------------------------------------------------------------

# arbre <nom> : crée un dépôt git jetable (GF-2 lit `git ls-files` dans le CWD,
# pas dans SRC — le harnais doit donc s'exécuter DANS l'arbre testé).
arbre() {
  local chemin="$ATELIER/$1"
  mkdir -p "$chemin/src"
  git -C "$chemin" init -q
  printf 'print("hello")\n' > "$chemin/src/app.py"
  printf 'export const x = "sobre";\n' > "$chemin/src/ui.ts"
  echo "$chemin"
}

# lancer <arbre> [deps...] -> imprime la sortie, retourne le code du script
lancer() {
  local chemin="$1"; shift
  ( cd "$chemin" && git add -A >/dev/null 2>&1; bash "$GF" "$chemin/src" "$@" 2>&1 )
}

# verifier <intitulé> <code attendu> <motif attendu> <arbre> [deps...]
verifier() {
  local intitule="$1" code_attendu="$2" motif="$3" chemin="$4"; shift 4
  CAS=$((CAS + 1))
  local sortie code
  sortie="$(lancer "$chemin" "$@")"; code=$?

  local souci=""
  [ "$code" = "$code_attendu" ] || souci="code $code (attendu $code_attendu)"
  grep -qE "$motif" <<< "$sortie" || souci="$souci ; motif « $motif » absent"

  if [ -n "$souci" ]; then
    ECHECS=$((ECHECS + 1))
    printf '  ÉCHEC  %s\n         %s\n' "$intitule" "$souci"
    sed 's/^/         | /' <<< "$sortie"
  else
    printf '  ok     %s\n' "$intitule"
  fi
}

echo "== Harnais de mutation — garde_fous.sh =="

# --- témoin : sans mutation, tout doit passer --------------------------------
# Sans ce cas, un script qui échoue toujours passerait tous les tests suivants.
PROPRE="$(arbre propre)"
verifier "témoin : arbre propre → succès" 0 "OK: no frontier provider" "$PROPRE"

# --- GF-1 frontier en exécution (bloquant) -----------------------------------
FRONTIER_PY="$(arbre gf1_py)"
printf 'from openai import OpenAI\n' >> "$FRONTIER_PY/src/app.py"
verifier "GF-1 : import openai dans le runtime → échec" \
  1 "VIOLATION: frontier provider referenced" "$FRONTIER_PY"

FRONTIER_TS="$(arbre gf1_ts)"
printf 'import Anthropic from "anthropic";\n' >> "$FRONTIER_TS/src/ui.ts"
verifier "GF-1 : import anthropic en TypeScript → échec" \
  1 "VIOLATION: frontier provider referenced" "$FRONTIER_TS"

FRONTIER_URL="$(arbre gf1_url)"
printf 'const u = "https://api.openai.com/v1";\n' >> "$FRONTIER_URL/src/ui.ts"
verifier "GF-1 : URL api.openai.com en dur → échec" \
  1 "VIOLATION: frontier provider referenced" "$FRONTIER_URL"

FRONTIER_DEP="$(arbre gf1_dep)"
printf 'openai==1.2.0\n' > "$FRONTIER_DEP/requirements.txt"
verifier "GF-1 : dépendance openai déclarée → échec" \
  1 "VIOLATION: frontier dependency declared" "$FRONTIER_DEP" \
  "$FRONTIER_DEP/requirements.txt"

# Contre-épreuve : le mot « openai » hors runtime et hors deps ne doit PAS
# déclencher. Un garde-fou qui prend la doc pour du code est inutilisable.
FRONTIER_DOC="$(arbre gf1_doc)"
printf 'Nous refusons openai et anthropic en exécution.\n' > "$FRONTIER_DOC/DOCTRINE.md"
verifier "GF-1 : « openai » dans un .md → pas de violation" \
  0 "OK: no frontier provider" "$FRONTIER_DOC"

# --- GF-2 secrets dans l'arbre (bloquant) ------------------------------------
SECRET="$(arbre gf2)"
printf 'TOKEN=abc\n' > "$SECRET/.env"
verifier "GF-2 : .env suivi par git → échec" \
  1 "VIOLATION: .env file tracked" "$SECRET"

SECRET_SUFFIXE="$(arbre gf2_suffixe)"
printf 'TOKEN=abc\n' > "$SECRET_SUFFIXE/.env.production"
verifier "GF-2 : .env.production suivi → échec" \
  1 "VIOLATION: .env file tracked" "$SECRET_SUFFIXE"

# Contre-épreuve : l'exemption `.example` doit exempter, et rien de plus.
EXEMPLE="$(arbre gf2_exemple)"
printf 'TOKEN=\n' > "$EXEMPLE/.env.example"
verifier "GF-2 : .env.example suivi → pas de violation" \
  0 "OK: no tracked .env" "$EXEMPLE"

# --- GF-3 discours non mesuré (avertissement seulement) ----------------------
# Le contrat de GF-3 est d'AVERTIR sans bloquer. Les deux moitiés comptent :
# qu'il voie la formulation, et qu'il ne fasse pas échouer la sortie.
DISCOURS="$(arbre gf3)"
printf 'const t = "analyse en temps réel";\n' >> "$DISCOURS/src/ui.ts"
verifier "GF-3 : « temps réel » non mesuré → avertit" \
  0 "WARN: unmeasured-claim wording" "$DISCOURS"
verifier "GF-3 : ... et n'échoue pas (avertissement seul)" \
  0 "OK: no tracked .env" "$DISCOURS"

verifier "GF-3 : arbre sobre → pas d'avertissement" \
  0 "OK: no banned wording" "$PROPRE"

# --- GF-4 frontière MCP Elzéard (bloquant, ADR-PC-023) -----------------------
verifier "témoin : arbre propre → GF-4 ok aussi" \
  0 "OK: no Elzeard tenant credential" "$PROPRE"

MCP_CRED="$(arbre gf4_cred)"
printf 'const key = "pck_a1b2c3d4_9f8e7d6c5b4a39281706f5e4d3c2b1a";\n' >> "$MCP_CRED/src/ui.ts"
verifier "GF-4 : clé pck_<réelle>_<réelle> → échec" \
  1 "VIOLATION: Elzeard tenant credential" "$MCP_CRED"

MCP_REG="$(arbre gf4_reg)"
printf '{"mcpServers": {"elz-core": {"command": "x"}}}\n' > "$MCP_REG/src/config.json"
verifier "GF-4 : clé mcpServers dans un .json → échec" \
  1 "VIOLATION: Elzeard tenant credential" "$MCP_REG"

MCP_FILE="$(arbre gf4_file)"
printf '{}\n' > "$MCP_FILE/src/.mcp.json"
verifier "GF-4 : .mcp.json suivi → échec" \
  1 "VIOLATION: .mcp.json tracked" "$MCP_FILE"

# Contre-épreuve 1 : le placeholder de doctrine, tel qu'écrit en prose, ne doit
# PAS déclencher — sinon le garde-fou hurle sur sa propre documentation (la
# leçon « vérifier la structure, pas la sous-chaîne »).
MCP_PLACEHOLDER="$(arbre gf4_placeholder)"
printf '// voir pck_<lookup_id>_<secret> dans l ADR-PC-023\n' >> "$MCP_PLACEHOLDER/src/ui.ts"
verifier "GF-4 : placeholder pck_<lookup_id>_<secret> → pas de violation" \
  0 "OK: no Elzeard tenant credential" "$MCP_PLACEHOLDER"

# Contre-épreuve 2 : mention en doc (.md, hors extensions scannées) ne doit
# pas déclencher non plus — même logique que la contre-épreuve GF-1.
MCP_DOC="$(arbre gf4_doc)"
printf 'La clé pck_a1b2c3d4_9f8e7d6c5b4a39281706f5e4d3c2b1a ne doit jamais sortir de product-core.\n' \
  > "$MCP_DOC/DOCTRINE.md"
verifier "GF-4 : clé réaliste dans un .md → pas de violation" \
  0 "OK: no Elzeard tenant credential" "$MCP_DOC"

# --- exclusion des répertoires de dépendances (18/08) ------------------------
# Régression réelle, mordue deux fois le 18/08 dans deux dépôts différents :
# l'intégration OpenAI/Anthropic de sentry_sdk (dépendance TRANSITIVE, jamais
# écrite par nous) vivant sous .venv/ faisait échouer GF-1 sur un arbre par
# ailleurs propre. Le cas ci-dessous reproduit l'incident à l'identique plutôt
# que d'inventer un exemple plus simple — c'est la panne vécue, pas une panne
# plausible.
DEP_PY="$(arbre dep_python)"
mkdir -p "$DEP_PY/src/.venv/lib/python3.12/site-packages/sentry_sdk/integrations"
printf 'from openai.resources.responses import AsyncResponses, Responses\n' \
  > "$DEP_PY/src/.venv/lib/python3.12/site-packages/sentry_sdk/integrations/openai.py"
verifier "GF-1 : import openai réel sous .venv/ (sentry_sdk) → pas de violation" \
  0 "OK: no frontier provider" "$DEP_PY"

DEP_JS="$(arbre dep_js)"
mkdir -p "$DEP_JS/src/node_modules/@anthropic-ai/sdk/dist"
printf 'import Anthropic from "anthropic";\nmodule.exports = Anthropic;\n' \
  > "$DEP_JS/src/node_modules/@anthropic-ai/sdk/dist/index.ts"
verifier "GF-1 : import anthropic sous node_modules/ → pas de violation" \
  0 "OK: no frontier provider" "$DEP_JS"

DEP_RUST="$(arbre dep_rust)"
mkdir -p "$DEP_RUST/src/target/debug/build"
printf '// import openai — genere par cargo, jamais ecrit ici\n' \
  > "$DEP_RUST/src/target/debug/build/openai_stub.rs"
verifier "GF-1 : mention openai sous target/ (build Rust) → pas de violation" \
  0 "OK: no frontier provider" "$DEP_RUST"

# Le cas qui compte vraiment : l'exclusion ne doit PAS avaler une vraie
# violation qui vit à côté d'un répertoire de dépendances exclu. Sans ce test,
# un --exclude-dir trop large (ou mal placé) passerait les mêmes cas ci-dessus
# en rendant GF-1 aveugle partout, pas seulement dans .venv/.
DEP_ET_VRAI="$(arbre dep_et_vrai_violation)"
mkdir -p "$DEP_ET_VRAI/src/.venv/lib/site-packages/sentry_sdk"
printf 'from openai import OpenAI\n' \
  > "$DEP_ET_VRAI/src/.venv/lib/site-packages/sentry_sdk/openai.py"
printf 'from openai import OpenAI  # celui-la est du VRAI code\n' \
  >> "$DEP_ET_VRAI/src/app.py"
verifier "GF-1 : violation réelle toujours détectée à côté d'un .venv/ exclu" \
  1 "VIOLATION: frontier provider referenced" "$DEP_ET_VRAI"

DEP_GF3="$(arbre dep_gf3)"
mkdir -p "$DEP_GF3/src/node_modules/some-lib"
printf 'export const t = "analyse en temps réel";\n' \
  > "$DEP_GF3/src/node_modules/some-lib/index.ts"
verifier "GF-3 : formulation non mesurée sous node_modules/ → pas d'avertissement" \
  0 "OK: no banned wording" "$DEP_GF3"

DEP_GF4="$(arbre dep_gf4)"
mkdir -p "$DEP_GF4/src/.venv/lib/site-packages/some_mcp_client"
printf '{"mcpServers": {"whatever": {}}}\n' \
  > "$DEP_GF4/src/.venv/lib/site-packages/some_mcp_client/config.json"
mkdir -p "$DEP_GF4/src/node_modules"
printf '{}\n' > "$DEP_GF4/src/node_modules/.mcp.json"
verifier "GF-4 : mcpServers + .mcp.json sous des dépendances → pas de violation" \
  0 "OK: no Elzeard tenant credential" "$DEP_GF4"

# --- verdict -----------------------------------------------------------------
echo
if [ "$ECHECS" -eq 0 ]; then
  echo "== $CAS cas, 0 échec — les garde-fous savent voir ce qu'ils prétendent voir =="
  exit 0
fi
echo "== $CAS cas, $ECHECS échec(s) — un garde-fou ne fait pas son travail =="
exit 1
