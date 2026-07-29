#!/usr/bin/env python3
"""Génère mentions-legales.html, cgv.html et confidentialite.html depuis legal.json.

Garde-fou : tant qu'un champ vaut TODO, les pages sont écrites en **BROUILLON**
avec un bandeau visible et le déploiement les refuse (voir --check). Publier des
mentions légales incomplètes ou inexactes est un manquement en soi (LCEN art. 6-III).

    python3 build_legal.py           # génère (brouillon si TODO)
    python3 build_legal.py --check   # sortie 1 si des TODO subsistent
"""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent
L = json.loads((ROOT / "legal.json").read_text(encoding="utf-8"))
TODOS = sorted(k for k, v in L.items() if isinstance(v, str) and v.startswith("TODO"))

CSS = """
:root{--coton:#F7F4EE;--carbone:#26241F;--argile:#8D877C;--line:#E5E0D6;--capucine:#D14E0F;--card:#fff}
@media (prefers-color-scheme:dark){:root{--coton:#1D1B18;--carbone:#F0EDE6;--argile:#9C968A;--line:#35322C;--capucine:#F0703A;--card:#26241F}}
*{box-sizing:border-box;margin:0}
body{background:var(--coton);color:var(--carbone);font:16px/1.7 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;padding:0 1.25rem}
main{max-width:46rem;margin:0 auto;padding:3.5rem 0 5rem}
.brand{display:flex;align-items:center;gap:.6rem;font-weight:800;font-size:.8rem;letter-spacing:.32em;color:var(--argile)}
.dot{width:.65rem;height:.65rem;border-radius:50%;background:var(--capucine)}
h1{font-size:1.9rem;font-weight:800;letter-spacing:-.02em;margin:1.2rem 0 .5rem}
h2{font-size:1.15rem;font-weight:800;margin:2.2rem 0 .6rem}
h3{font-size:1rem;font-weight:700;margin:1.4rem 0 .4rem}
p,li{margin:0 0 .8rem}ul{padding-left:1.2rem}
a{color:var(--capucine)}
.meta{color:var(--argile);font-size:.9rem;margin-bottom:2rem}
.box{background:var(--card);border:1px solid var(--line);border-left:.45rem solid var(--capucine);border-radius:14px;padding:1.2rem;margin:1.4rem 0}
.draft{background:#B3261E;color:#fff;border-radius:12px;padding:1rem 1.2rem;margin:0 0 2rem;font-weight:700}
table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.94rem}
th,td{border:1px solid var(--line);padding:.5rem .6rem;text-align:left;vertical-align:top}
footer{margin-top:3rem;padding-top:1.5rem;border-top:1px solid var(--line);color:var(--argile);font-size:.9rem}
"""

BANNER = ('<div class="draft">⚠️ BROUILLON — NE PAS PUBLIER. Champs manquants dans '
          'legal.json&nbsp;: {missing}. Des mentions légales incomplètes constituent '
          'elles-mêmes un manquement.</div>')


def page(title: str, body: str) -> str:
    banner = BANNER.format(missing=", ".join(TODOS)) if TODOS else ""
    return f"""<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="{'noindex' if TODOS else 'index'}">
<title>{title} — AIAME</title><style>{CSS}</style></head><body><main>
<div class="brand"><span class="dot"></span>AIAME</div>
{banner}
<h1>{title}</h1>
<p class="meta">Version du {L['cgv_version']} · <a href="/">aiame.fr</a></p>
{body}
<footer><p><a href="/mentions-legales.html">Mentions légales</a> ·
<a href="/cgv.html">CGV</a> · <a href="/confidentialite.html">Confidentialité</a> ·
<a href="/">Accueil</a></p></footer>
</main></body></html>
"""


MENTIONS = f"""
<h2>1. Éditeur du site</h2>
<p><strong>{L['editeur_nom']}</strong> — {L['editeur_statut']}<br>
{L['editeur_adresse']}<br>
SIREN/SIRET : {L['editeur_siren']}<br>
Courriel : <a href="mailto:{L['editeur_email']}">{L['editeur_email']}</a> · Téléphone : {L['editeur_telephone']}<br>
{L['tva']}</p>
<p>Directeur de la publication : {L['directeur_publication']}</p>

<h2>2. Hébergement</h2>
<p>{L['hebergeur_nom']}<br>{L['hebergeur_adresse']}<br>Téléphone : {L['hebergeur_tel']}</p>
<p>Le site est hébergé sur une infrastructure située dans l'Union européenne et administrée
directement par l'éditeur.</p>

<h2>3. Activité</h2>
<p>Le site présente et commercialise <strong>Aiame Red</strong>, prestation d'audit technique
de dérive et de red teaming appliquée aux systèmes d'intelligence artificielle.</p>
<div class="box"><p><strong>L'audit est une prestation technique et ne constitue pas un conseil
juridique.</strong> Les éléments produits (cartographie AI Act / RGPD, fiches de dérive) sont
destinés à alimenter le travail de votre conseil, de votre DPO ou de votre auditeur. Ils ne
constituent ni un avis juridique, ni une certification de conformité.</p></div>

<h2>4. Propriété intellectuelle</h2>
<p>Les contenus de ce site (textes, méthode, gabarits d'audit) sont protégés. Toute reproduction
sans autorisation est interdite. Les rapports remis aux clients leur appartiennent ; la méthode
et les outils restent la propriété de l'éditeur.</p>

<h2>5. Données personnelles et cookies</h2>
<p>Ce site <strong>n'utilise aucun cookie, aucun traqueur et aucun script tiers</strong>, et ne
journalise pas les accès. Voir la <a href="/confidentialite.html">politique de confidentialité</a>.</p>

<h2>6. Médiation de la consommation</h2>
<p>Conformément à l'article L616-1 du code de la consommation :
{L['mediateur_nom']} — {L['mediateur_url']}</p>

<h2>7. Signalement</h2>
<p>Tout contenu manifestement illicite peut être signalé à
<a href="mailto:{L['editeur_email']}">{L['editeur_email']}</a>.</p>
"""

CGV = f"""
<h2>Article 1 — Objet et champ d'application</h2>
<p>Les présentes conditions générales de vente (CGV) régissent la vente des prestations
<strong>Aiame Red</strong> par {L['editeur_nom']} ({L['editeur_statut']}, SIREN {L['editeur_siren']}),
ci-après « le Prestataire », à tout client professionnel ou consommateur, ci-après « le Client ».</p>
<p>Toute commande implique l'acceptation sans réserve des présentes CGV, portées à la connaissance
du Client avant la validation de la commande.</p>

<h2>Article 2 — Prestations</h2>
<table>
<tr><th>Formule</th><th>Périmètre</th><th>Délai</th></tr>
<tr><td>Scan</td><td>Audit automatisé d'une capacité ; fiche de dérive</td><td>&lt; 24 h</td></tr>
<tr><td>Produit</td><td>Toutes les capacités ; pack de preuves AI Act / RGPD</td><td>&lt; 24 h</td></tr>
<tr><td>Veille continue</td><td>Re-scan à chaque version, alerte de dérive, historique</td><td>continu</td></tr>
</table>
<p>Une revue humaine complémentaire peut être proposée sur devis. Le contenu exact de chaque
prestation est décrit sur <a href="/">aiame.fr</a> au jour de la commande.</p>

<h2>Article 3 — Prix et taxes</h2>
<p>Les tarifs en vigueur sont <strong>communiqués au Client lors du cadrage, avant toute
commande et sans engagement</strong>. Ils sont exprimés en euros et <strong>nets de taxes</strong> :
{L['tva']}. Aucune TVA n'est due ni facturée. Le tarif applicable est celui communiqué et accepté
au moment de la commande ; un changement ultérieur est sans effet rétroactif.</p>

<h2>Article 4 — Commande et paiement</h2>
<p>La commande est ferme à sa validation par le Client. Le paiement s'effectue par carte bancaire
via un prestataire de paiement agréé, ou par virement SEPA. Le Prestataire <strong>ne conserve
aucune donnée bancaire</strong>.</p>
<p>Pour les professionnels, en cas de retard de paiement : pénalités au taux d'intérêt légal
majoré, et indemnité forfaitaire de recouvrement de 40 € (art. L441-10 et D441-5 du code de commerce).</p>

<h2>Article 5 — Exécution</h2>
<p>La prestation démarre à réception du paiement et de la description du produit à auditer, que le
Client s'engage à fournir de manière exacte et complète. Les livrables sont transmis par voie
électronique dans le délai annoncé.</p>

<h2>Article 6 — Droit de rétractation (consommateurs)</h2>
<p>Le Client consommateur dispose d'un délai de <strong>quatorze (14) jours</strong> à compter de
la conclusion du contrat pour exercer son droit de rétractation, sans motif ni pénalité
(art. L221-18 du code de la consommation).</p>
<div class="box">
<p><strong>Exécution immédiate et renonciation.</strong> La prestation étant exécutée sous 24 heures,
le Client qui souhaite ce délai doit, lors de la commande&nbsp;:</p>
<ul>
<li>demander <strong>expressément</strong> que l'exécution commence avant la fin du délai de rétractation ;</li>
<li>reconnaître <strong>expressément</strong> qu'il perd son droit de rétractation une fois la
prestation pleinement exécutée (art. L221-25 du code de la consommation).</li>
</ul>
<p>Ces deux consentements sont recueillis séparément, ne sont jamais pré-cochés, et sont conservés
horodatés. À défaut, le droit de rétractation s'applique pleinement.</p>
</div>
<h3>Formulaire type de rétractation</h3>
<p>À l'attention de {L['editeur_nom']}, {L['editeur_adresse']}, {L['editeur_email']} :<br>
« Je vous notifie par la présente ma rétractation du contrat portant sur la prestation ci-dessous :
commande n° ……… du ……… . Nom du consommateur : ……… . Adresse : ……… . Date : ……… . »</p>
<p>Conformément à l'article L121-21-8 du code de la consommation, le droit de rétractation ne
s'applique pas entre professionnels.</p>

<h2>Article 7 — Abonnement Veille continue</h2>
<p>L'abonnement est mensuel, sans durée d'engagement. Il est <strong>résiliable à tout moment en
une seule action</strong> depuis l'espace client, sans justification, sans frais et sans démarche
auprès du Prestataire. La résiliation prend effet à la fin de la période en cours ; l'accès aux
historiques déjà produits reste garanti et exportable.</p>

<h2>Article 8 — Obligations et limites</h2>
<p>Le Prestataire est tenu d'une <strong>obligation de moyens</strong>. L'audit identifie des
risques de dérive à partir des éléments décrits par le Client ; il ne garantit ni l'exhaustivité
des risques d'un système, ni la conformité réglementaire de celui-ci.</p>
<div class="box"><p><strong>Les livrables ne constituent ni un avis juridique, ni une
certification.</strong> Ils documentent des éléments de preuve techniques destinés au conseil, au
DPO ou à l'auditeur du Client.</p></div>
<p>La responsabilité du Prestataire est limitée au montant de la prestation concernée, sauf faute
lourde ou dolosive. Sont exclus les dommages indirects.</p>

<h2>Article 9 — Garantie légale de conformité</h2>
<p>Le Client consommateur bénéficie de la garantie légale de conformité des contenus et services
numériques (art. L224-25-12 et suivants du code de la consommation), indépendamment de toute
garantie commerciale.</p>

<h2>Article 10 — Confidentialité et propriété</h2>
<p>Les informations transmises par le Client sont traitées de manière confidentielle et ne sont ni
revendues, ni réutilisées à d'autres fins. Le rapport remis appartient au Client. La méthode, les
gabarits et le moteur d'audit restent la propriété du Prestataire.</p>

<h2>Article 11 — Données personnelles</h2>
<p>Voir la <a href="/confidentialite.html">politique de confidentialité</a>.</p>

<h2>Article 12 — Force majeure</h2>
<p>Aucune partie n'est responsable d'un manquement dû à un cas de force majeure au sens de
l'article 1218 du code civil.</p>

<h2>Article 13 — Réclamation et médiation</h2>
<p>Toute réclamation peut être adressée à <a href="mailto:{L['editeur_email']}">{L['editeur_email']}</a>.
À défaut de résolution, le Client consommateur peut saisir gratuitement le médiateur de la
consommation : {L['mediateur_nom']} — {L['mediateur_url']}. Il peut également recourir à la
plateforme européenne de règlement en ligne des litiges.</p>

<h2>Article 14 — Droit applicable</h2>
<p>Les présentes CGV sont soumises au droit français. À défaut de résolution amiable, compétence
est attribuée aux tribunaux français compétents, sous réserve des règles protectrices applicables
au consommateur.</p>
"""

CONF = f"""
<h2>1. Responsable de traitement</h2>
<p>{L['editeur_nom']}, {L['editeur_adresse']} — <a href="mailto:{L['editeur_email']}">{L['editeur_email']}</a>.</p>

<h2>2. Principe</h2>
<div class="box"><p>Ce site <strong>n'utilise aucun cookie, aucun traqueur, aucun script tiers, et
ne journalise pas les accès</strong>. Aucun profilage n'est réalisé. Aucune donnée n'est vendue,
louée ou cédée — en aucune circonstance.</p></div>

<h2>3. Données traitées</h2>
<table>
<tr><th>Donnée</th><th>Finalité</th><th>Base légale</th><th>Conservation</th></tr>
<tr><td>Adresse e-mail</td><td>Livraison des livrables, suivi de commande</td><td>Exécution du contrat</td><td>3 ans après la dernière commande</td></tr>
<tr><td>Pays, n° de TVA</td><td>Détermination du régime fiscal applicable</td><td>Obligation légale</td><td>10 ans (obligation comptable)</td></tr>
<tr><td>Données de commande et consentements horodatés</td><td>Preuve de la vente et du respect du droit de rétractation</td><td>Obligation légale</td><td>10 ans</td></tr>
<tr><td>Description technique du produit à auditer</td><td>Réalisation de l'audit</td><td>Exécution du contrat</td><td>Supprimée sur demande, 12 mois par défaut</td></tr>
</table>
<p>Aucune donnée bancaire n'est collectée ni conservée : le paiement est traité par un prestataire
agréé qui procède à la tokenisation.</p>

<h2>4. Destinataires</h2>
<ul>
<li>Le prestataire de paiement choisi, pour la seule transaction ;</li>
<li>l'hébergeur ({L['hebergeur_nom']}, Union européenne) ;</li>
<li>le service de facturation conforme, pour l'émission des factures.</li>
</ul>
<p>Aucun transfert hors Union européenne n'est réalisé pour l'hébergement. Si un prestataire de
paiement établi hors UE est utilisé, le transfert est encadré par les clauses contractuelles types
de la Commission européenne, et cette page sera mise à jour en conséquence.</p>

<h2>5. Vos droits</h2>
<p>Vous disposez des droits d'accès, de rectification, d'effacement, de limitation, d'opposition et
de portabilité (art. 15 à 22 du RGPD). Exercice à
<a href="mailto:{L['editeur_email']}">{L['editeur_email']}</a> ; réponse sous un mois.</p>
<p>Certaines données ne peuvent être effacées avant leur échéance légale lorsqu'une obligation
comptable ou probatoire l'impose : nous vous l'indiquerons explicitement plutôt que de refuser
sans motif.</p>
<p>Vous pouvez introduire une réclamation auprès de la CNIL — <a href="https://www.cnil.fr">cnil.fr</a>.</p>

<h2>6. Sécurité</h2>
<p>Chiffrement TLS avec certificat maîtrisé par l'éditeur, hébergement souverain administré
directement, accès restreint, aucune donnée bancaire stockée, journalisation d'accès désactivée
par principe.</p>
"""

if __name__ == "__main__":
    if "--check" in sys.argv:
        if TODOS:
            print(f"INCOMPLET — champs à renseigner dans legal.json : {', '.join(TODOS)}")
            sys.exit(1)
        print("legal.json complet — pages publiables")
        sys.exit(0)

    for filename, title, body in [
        ("mentions-legales.html", "Mentions légales", MENTIONS),
        ("cgv.html", "Conditions générales de vente", CGV),
        ("confidentialite.html", "Politique de confidentialité", CONF),
    ]:
        (ROOT / filename).write_text(page(title, body), encoding="utf-8")
        print(f"écrit : {filename}")
    print("\n⚠️  BROUILLON" if TODOS else "\n✅ publiable")
    if TODOS:
        print("champs manquants :", ", ".join(TODOS))
