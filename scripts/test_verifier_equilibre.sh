#!/usr/bin/env bash
# Preuve que verifier_equilibre.sh sait échouer (règle 5) : chaque violation est fabriquée sur une copie, le garde doit la voir.
set -u
ICI="$(cd "$(dirname "$0")" && pwd)"; V="$ICI/verifier_equilibre.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; echec=0
neuf() { rm -rf "$T/r"; mkdir -p "$T/r"; [ -d "$ICI/../equilibre" ] && cp -r "$ICI/../equilibre" "$T/r/equilibre"; }
rouge() { if bash "$V" "$T/r" >/dev/null 2>&1; then echo "✗ NON vu : $1"; echec=1; else echo "✓ vu rouge : $1"; fi; }
neuf; if [ -d "$T/r/equilibre" ]; then bash "$V" "$T/r" >/dev/null 2>&1 && echo "✓ la copie intacte passe" || { echo "✗ la copie intacte échoue"; echec=1; }
  echo "<!-- retouche -->" >> "$T/r/equilibre/index.html"; rouge "page retouchée"
  neuf; rm "$T/r/equilibre/PROVENANCE.json"; rouge "PROVENANCE absente"
  neuf; rm "$T/r/equilibre/index.html"; rouge "page absente"
  neuf; echo "pas du json" > "$T/r/equilibre/PROVENANCE.json"; rouge "PROVENANCE illisible"
else echo "(equilibre/ absent : on fabrique une copie minimale)"; mkdir -p "$T/r/equilibre"; echo "<p>x</p>" > "$T/r/equilibre/index.html"
  python3 -c 'import hashlib,json;json.dump({"sha256_index_html":hashlib.sha256(b"<p>x</p>\n").hexdigest()},open("'"$T"'/r/equilibre/PROVENANCE.json","w"))'
  bash "$V" "$T/r" >/dev/null 2>&1 && echo "✓ la copie intacte passe" || { echo "✗ la copie intacte échoue"; echec=1; }
  echo "x" >> "$T/r/equilibre/index.html"; rouge "page retouchée"; fi
[ "$echec" -eq 0 ] && echo "✓ test verifier_equilibre vert" || echo "✗ test verifier_equilibre ROUGE"; exit "$echec"
