# aiame.fr — Gandi DNS records for GitHub Pages

*Prepared 2026-07-28. Apply in the Gandi dashboard: aiame.fr → DNS Records.*
*Current state to replace: apex → Gandi webredir (217.70.184.38), `www` → webredir.gandi.net.*

## 1. Delete

- All `A` records on `@` pointing to `217.70.184.*` (webredir)
- The `www` CNAME → `webredir.gandi.net.`
- Disable any Gandi "web forwarding" configured for the domain (Domain → Web Forwarding), otherwise Gandi keeps re-creating the webredir records.

## 2. Add

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `@` | `185.199.108.153` | 1800 |
| A | `@` | `185.199.109.153` | 1800 |
| A | `@` | `185.199.110.153` | 1800 |
| A | `@` | `185.199.111.153` | 1800 |
| AAAA | `@` | `2606:50c0:8000::153` | 1800 |
| AAAA | `@` | `2606:50c0:8001::153` | 1800 |
| AAAA | `@` | `2606:50c0:8002::153` | 1800 |
| AAAA | `@` | `2606:50c0:8003::153` | 1800 |
| CNAME | `www` | `aiame-fr.github.io.` | 1800 |

Leave MX/TXT records (mail for tech@aiame.fr) untouched.

## 3. Verify (after propagation, minutes → a few hours)

```bash
dig +short aiame.fr A          # expect the four 185.199.10x.153
dig +short www.aiame.fr CNAME  # expect aiame-fr.github.io.
curl -sI https://aiame.fr | head -3   # expect HTTP/2 200, server: GitHub.com
```

## 4. Then enforce HTTPS

GitHub side is already configured (custom domain `aiame.fr` set on the Pages site; `CNAME` file committed). Once DNS resolves, GitHub provisions the Let's Encrypt certificate automatically (can take up to ~1 h after propagation). Then:

```bash
gh api -X PUT repos/aiame-fr/aiame-fr.github.io/pages -F https_enforced=true
```

(or tick "Enforce HTTPS" in the repo's Pages settings.)
