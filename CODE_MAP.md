# KRB Assessment — Code Map

Navigate by this map + `// MARKER` anchors. Do NOT grep the 1.3MB files blindly.

## Files (host: /opt/krb-assessment)
- `server_container.mjs` (EDIT THIS) ≈28.5k lines — all HTTP routing/API, raw Node http, no framework.
  Mirror to `server.mjs`; deploy = docker cp + `docker restart krb-assessment`.
- `shells/bi.js` ≈ client UI bundle for BI + **Rakip** modules (served static at `/shells/bi.js`, loaded by app.js). Deploy = docker cp, **no restart**.
- `price_monitor.py