# Sources tierces citées par aiame-fr.github.io

Manifeste exigé par **GF-5** (`garde-fous/garde_fous.sh`, canon `aiame-doctrine`) : tout
domaine externe cité littéralement dans le dépôt doit être nommé ici, **sans condition**.
Absent jusqu'ici — trou repo-wide, jamais déclenché par GF-5 avant le 2026-09-25 : ce
dépôt ne contenait aucune balise déclarative (`<link>`, `<script src>`, `@import`,
`url()`) pointant hors d'`aiame.fr`, seul déclencheur de la portion de GF-5 qui lit le
HTML/CSS. Les liens `<a href>` ci-dessous existaient déjà, sans jamais avoir été scrutés
— surfacé en ajoutant les balises `<link rel="alternate" hreflang>` de l'effort i18n
(2026-09-25), qui font désormais matcher le fichier.

## Ce que ce dépôt cite, et pourquoi

Aucune de ces adresses n'est appelée par du code : ce site est statique, sans script
côté serveur ni côté client qui contacte un tiers. Les deux domaines ci-dessous
n'apparaissent que dans des liens `<a href>` en texte de page — un humain clique, rien
n'est automatisé, il n'y a rien à collecter et personne à respecter (`robots.txt`,
limite de débit) au sens où GF-5 l'entend pour un vrai appel réseau.

| Domaine | Rôle | Où (motif) | Régime |
|---|---|---|---|
| `github.com` | Liens vers le code source des dépôts de l'organisation (« Source », décisions, ADR) | `index.html`, `vitrine/index.html`, `dev/index.html`, `dev/miroir-note.html`, `transparence.html`, leurs miroirs `en/`, et d'autres pages du dépôt | Lien de prose cliqué par un humain, jamais appelé par du code |
| `aiame-fr.github.io` | Référence à cette même URL de miroir GitHub Pages, dans `vitrine/index.html` : une exception délibérée et déjà disclosée au « zéro tiers » de la page (une copie de la vitrine y est aussi publiée, hébergée par GitHub et non notre infra) | `vitrine/index.html`, `en/vitrine/index.html` | Auto-référence disclosée en prose, jamais appelée par du code |

`aiame.fr` et ses sous-domaines (`www.aiame.fr`, `dev.aiame.fr`) apparaissent aussi dans
ces fichiers (URL absolues de la même origine, dans les balises `hreflang` notamment).
Ce sont nos propres domaines : GF-5 les exempte nativement, ils ne figurent donc pas
dans ce tableau.

## Ce qui n'est pas cité

Aucune collecte de contenu tiers, aucun tracker, aucune police/police web ni script
CDN externe — le `<meta name="description">` de `vitrine/index.html` le déclare lui-même
(« sans traqueur »). `changedetection.io` et d'autres outils cités ailleurs dans
l'organisation n'existent pas dans ce dépôt.

## Juridiction de contrainte — la troisième colonne (ajoutée le 2026-09-29)

Ce manifeste répondait à « où part la donnée ? » (GF-5). Il ne répondait pas à
« sous quelle loi tombe l'entité qui la reçoit ? ». Ce tableau est la copie
locale, par dépôt, de `aiame-doctrine/legal/REGISTRE-JURIDICTION.md`, et il
suit la même règle (« la souveraineté est bâtie, jamais vendue », 2026-08-26) :
aucun score, aucun classement, jamais repris tel quel sur une surface qu'un
client lit. Le nom du chantier côté client reste une décision propriétaire
(`AIAME-SOV-PATRIOT-ETUDE-2026.md` §7.4).

Seul `github.com` a une entité tierce réelle à nommer ici : la ligne
`aiame-fr.github.io` ci-dessus est une auto-référence (notre propre contenu),
et `aiame.fr`/`www.aiame.fr`/`dev.aiame.fr` sont nos propres domaines, tous
deux hors du champ de ce tableau. **Ce que ce tableau ne couvre volontairement
pas** : ce dépôt lui-même est hébergé par GitHub Pages — l'entité/juridiction
ci-dessous concerne les liens `<a href>` cliqués par un humain, pas
l'hébergement du dépôt qui les sert, une question distincte, non traitée ici.

| Domaine | Quand, et qui appelle | Entité contrôlante | Juridiction | Grade |
|---|---|---|---|---|
| `github.com` | Liens de prose cliqués par un humain (entrée ci-dessus) | GitHub, Inc. (Microsoft) | US | entité `déduit` |

Domaine et conclusion identiques à la ligne déjà résolue dans
`aiame-sov/SOURCES.md` — pas re-recherchés, réutilisés.
