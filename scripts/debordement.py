#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""debordement.py — aucune page du site ne défile à l'horizontale sur un téléphone, mesuré dans un vrai Chromium.

    python3 scripts/debordement.py [--racine DOSSIER]

Une ligne de commande, un chemin ou un tableau trop larges élargissent la page entière : sur un téléphone le lecteur doit
faire défiler de côté pour lire. Constaté le 2026-10-08 sur index.html et en/index.html (des `<code>` de 631 px de large
dans une fenêtre de 390). On mesure donc
`scrollWidth > innerWidth` à 360, 390 et 768 px, et — à toutes les largeurs, 1280 compris — qu'aucun mot ne sort du cadre de son
bloc, pour chaque page ; on NOMME les éléments qui dépassent.

Sont exclues : les archives figées (docs/artefacts/ : on ne retouche pas une capture datée) et les copies de la galaxie que
galaxie/PROVENANCE.json déclare (galaxie/index.html, et index.html quand la galaxie est l'accueil : générées dans
aiame-workspace, jamais retouchées ici — leur somme l'interdit ; elles sont mesurées, et corrigées s'il le faut, par l'e2e de
la galaxie, là-bas).

Sortie : 0 vert · 1 une page déborde (chaque dépassement nommé) · 2 ABSTENTION (Playwright ou Chromium absent — jamais un vert).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

LARGEURS = (360, 390, 768, 1280)
EXCLUES = ("docs/artefacts/", "galaxie/")


def panne_simulee() -> None:
    """Couture de test (test_debordement.sh) : DEBORDEMENT_TEST_PANNES=N fait planter les N premières mesures, pour prouver
    qu'un plantage isolé est réessayé et qu'un plantage répété échoue (jamais un vert). Inerte hors test (variable absente)."""
    n = int(os.environ.get("DEBORDEMENT_TEST_PANNES", "0") or 0)
    if n > 0:
        os.environ["DEBORDEMENT_TEST_PANNES"] = str(n - 1)
        raise RuntimeError("plantage simulé du navigateur")


def copies_galaxie(racine: Path) -> set[str]:
    """Les copies de la galaxie que galaxie/PROVENANCE.json déclare (galaxie/index.html, et index.html quand elle est la
    page d'accueil) sont GÉNÉRÉES dans aiame-workspace : leur somme interdit de les retoucher ici, elles sont mesurées là-bas
    (e2e de la galaxie). Une PROVENANCE illisible ne dispense de rien : on mesure alors toutes les pages."""
    prov = racine / "galaxie" / "PROVENANCE.json"
    try:
        return set(json.loads(prov.read_text(encoding="utf-8")).get("copies", []))
    except (OSError, ValueError):
        return set()


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
    generees = copies_galaxie(racine)
    pages = sorted(p for p in racine.rglob("*.html")
                   if not any(x in p.relative_to(racine).as_posix() for x in EXCLUES)
                   and p.relative_to(racine).as_posix() not in generees
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
                r, derniere = None, None
                for _essai in (1, 2):   # un plantage du NAVIGATEUR n'est pas un constat sur la page : un second essai, page neuve
                    pg = nav.new_page(viewport={"width": w, "height": 800})
                    try:
                        pg.goto(p.as_uri())
                        pg.wait_for_timeout(150)
                        panne_simulee()
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
                        break
                    except Exception as exc:   # noqa: BLE001 — Playwright lève des erreurs de plusieurs types
                        derniere = exc
                    finally:
                        try:
                            pg.close()
                        except Exception:   # noqa: BLE001 — page déjà morte
                            pass
                if r is None:
                    # deux plantages : la page n'est PAS mesurée. Un garde qui ne mesure pas n'est jamais un vert.
                    fautes.append(f"{w}px NON MESURÉE — le navigateur a planté deux fois ({str(derniere).splitlines()[0][:120]})")
                    continue
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
