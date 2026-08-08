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

echo "== GF-1 frontier-in-execution (blocking) =="
if grep -rn -iE 'from openai|import openai|import anthropic|from anthropic|api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis' \
    "$SRC" --include='*.py' --include='*.ts' --include='*.tsx' --include='*.rs'; then
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
  --include='*.ts' --include='*.tsx' | head -5 \
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
    "$SRC" --include='*.py' --include='*.ts' --include='*.tsx' --include='*.rs' --include='*.json' --include='*.yml' --include='*.yaml'; then
  echo "VIOLATION: Elzeard tenant credential or MCP client registration found (ADR-PC-023)"; FAIL=1
elif find "$SRC" -type f -iname '.mcp.json' 2>/dev/null | grep -q .; then
  echo "VIOLATION: .mcp.json tracked in runtime tree (ADR-PC-023)"; FAIL=1
else
  echo "OK: no Elzeard tenant credential or MCP client registration"
fi

exit $FAIL
