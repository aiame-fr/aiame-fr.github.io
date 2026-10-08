#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""debordement.py — aucune page du site ne défile à l'horizontale sur un téléphone, mesuré dans un vrai Chromium.

    python3 scripts/debordement.py [--racine DOSSIER]

Une ligne de commande, un chemin ou un tableau trop larges élargissent la page entière : sur un téléphone le lecteur doit
faire défiler de côté pour lire. Constaté le 2026-10-08 sur index.html et en/index.html (des `<code>` de 631 px de large
dans une fenêtre de 390). On mesure donc
`scrollWidth > innerWidth` à 360, 390 et 768 px, et — à toutes les largeurs, 1280 compris — qu'aucun mot ne sort du cadre de son
bloc, pour chaque page ; on NOMME les éléments qui dépassent.

Sont exclues : les archives figées (docs/artefacts/ : on ne retouche pas une capture datée) et la galaxie publiée
(galaxie/index.html : générée dans aiame-workspace, jamais retouchée ici — sa somme l'interdit ; elle est mesurée, et corrigée
s'il le faut, par l'e2e de la galaxie, là-bas).

Sortie : 0 vert · 1 une page déborde (chaque dépassement nommé) · 2 ABSTENTION (Playwright ou Chromium absent — jamais un vert).
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import tempfile
from pathlib import Path

LARGEURS = (360, 390, 768, 1280)
EXCLUES = ("docs/artefacts/", "galaxie/")


def navigateur() -> str | None:
    for c in (os.environ.get("DEBORDEMENT_CHROMIUM"), "/usr/bin/chromium", shutil.which("chromium"), shutil.which("chromium-browser")):
        if c and Path(c).exists():
            return c
    return None


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--racine", default=str(Path(__file__).resolve().parent.parent))
    a = ap.parse_args(argv)
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("⚠ ABSTENTION — Playwright (Python) absent sur cette machine", file=sys.stderr)
        return 2
    chrome = navigateur()
    if not chrome:
        print("⚠ ABSTENTION — Chromium absent sur cette machine", file=sys.stderr)
        return 2
    racine = Path(a.racine).resolve()
    pages = sorted(p for p in racine.rglob("*.html")
                   if not any(x in p.relative_to(racine).as_posix() for x in EXCLUES)
                   and not {".claude", ".git"} & set(p.relative_to(racine).parts))   # relatif : ce dossier peut LUI-MÊME vivre sous .claude/worktrees/
    if not pages:
        print("✗ aucune page .html trouvée — un garde qui ne mesure rien ne prouve rien", file=sys.stderr)
        return 1
    echecs: list[str] = []
    with tempfile.TemporaryDirectory() as td, sync_playwright() as pw:
        nav = pw.chromium.launch(executable_path=chrome, args=["--no-sandbox"],
                                 env={**os.environ, "WAYLAND_DISPLAY": "", "DISPLAY": "", "XDG_RUNTIME_DIR": td})
        for p in pages:
            nom = p.relative_to(racine).as_posix()
            fautes = []
            for w in LARGEURS:
                pg = nav.new_page(viewport={"width": w, "height": 800})
                pg.goto(p.as_uri())
                pg.wait_for_timeout(150)
                r = pg.evaluate("""() => { const vw = innerWidth;
                    const bad = [...document.querySelectorAll('body *')].filter(e => { const b = e.getBoundingClientRect(); return b.width > 0 && b.right > vw + 1; })
                      .filter((e, i, tous) => !tous.some(o => o !== e && e.contains(o)))   // le plus profond seulement : la cause, pas ses parents
                      .slice(0, 3).map(e => e.tagName.toLowerCase() + (e.className ? '.' + String(e.className).split(' ')[0] : '') + '@' + Math.round(e.getBoundingClientRect().right));
                    // un mot qui sort du cadre de son bloc (carte, item, cellule) sans élargir la page : invisible au défilement sur un grand
                    // écran, mais le texte déborde de sa carte (constaté sur www.aiame.fr à 1280 px : jusqu'à 313 px)
                    const sort = []; const w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT); let n;
                    while ((n = w.nextNode())) { const bloc = n.parentElement.closest('li, td, th, p, dd, .repo, main'); if (!bloc) continue;
                      const cr = bloc.getBoundingClientRect(), re = /\\S+/g; let m;
                      while ((m = re.exec(n.textContent))) { const r = document.createRange(); r.setStart(n, m.index); r.setEnd(n, m.index + m[0].length);
                        const b = r.getBoundingClientRect(); if (b.width > 0 && b.right > cr.right + 1) sort.push(m[0].slice(0, 40) + ' +' + Math.round(b.right - cr.right)); } }
                    return { deborde: document.documentElement.scrollWidth > vw, bad, sort: sort.slice(0, 3) }; }""")
                pg.close()
                if r["deborde"]:
                    fautes.append(f"{w}px la page défile {r['bad']}")
                if r["sort"]:
                    fautes.append(f"{w}px du texte sort de son cadre {r['sort']}")
            if fautes:
                echecs.append(nom)
                print(f"✗ {nom} déborde : {' ; '.join(fautes)}", file=sys.stderr)
            else:
                print(f"✓ {nom}")
        nav.close()
    if echecs:
        print(f"✗ {len(echecs)} page(s) défilent à l'horizontale sur téléphone", file=sys.stderr)
        return 1
    print(f"✅ {len(pages)} pages : aucune ne défile à l'horizontale à {', '.join(map(str, LARGEURS))} px")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
