# KRB Assessment — Code Map

Navigate by this map + `// MARKER` anchors. Do NOT grep the 1.3MB files blindly.

## Files (host: /opt/krb-assessment)
- `server_container.mjs` (EDIT THIS) ≈28.5k lines — all HTTP routing/API, raw Node http, no framework.
  Mirror to `server.mjs`; deploy = docker cp + `docker restart krb-assessment`.
- `shells/bi.js` ≈ client UI bundle for BI + **Rakip** modules (served static at `/shells/bi.js`, loaded by app.js). Deploy = docker cp, **no restart**.
- `price_monitor.py` — competitor scraper (writes `bi_rakip_fiyat`).
- `index.html` loads `/app.js` (versioned) which fetches the shells.

## Rakip module UI — shells/bi.js
- Tab bar ~L4444: buttons `rf-tab-{piyasa|akilli|izleme|alarmlar|ayarlar}`; labels: Ham Veri / 🎯 Smart Matched / İzleme / Alarmlar / Ayarlar.
- Panes: `rf-pane-piyasa` (Raw Data, ~L4460), `rf-pane-akilli` (Smart Matched placeholder), `rf-pane-izleme`, ...
- `window.rfTab(tab)` ~L4613 — tabs array `['piyasa','akilli','izleme','alarmlar','ayarlar']`.
- `window.rfPiyasaAra()` ~L4622 — `// RAKIP_RAWDATA_V1` flat Raw Data render (reads rf-marka/rf-ebat, GET /api/rakip/piyasa, one row per listing).
- `window.rfHizliIzleEkle`, `rfPiyasaIzleEkle`, `rfYuklePiyasaOzet` — watchlist/ozet helpers.

## Rakip API — server_container.mjs
- `GET /api/rakip/piyasa` ~L20189 — returns `{rows}` from view `bi_rakip_fiyat_son`; `// EBAT_CONCAT_V1` size match at ~L20195.
- `GET /api/rakip/ozet` ~L20219, `/api/rakip/izle`, `/api/rakip/piyasa-ozet` ~L20295. Auth: `requireModuleAccess(request,'intelligence'|'saha')`.

## DB (PostgreSQL, container krb-assessment-postgres, db assessment_platform, user assessment_app)
- `bi_rakip_fiyat` — base table (scraper writes here; `ebat` currently truncated to 30 chars).
- `bi_rakip_fiyat_son` — VIEW: `DISTINCT ON (kaynak,marka,ebat) ... ORDER BY ..., scraped_at DESC` (latest per listing).
  Columns: kaynak, marka, ebat(full title, truncated), model(full, untruncated), genislik/profil/cap(clean size ints), fiyat, stok, url, satici_sayisi, yorum_sayisi, puan, scraped_at, tenant_id.

## Deploy checklist
1. Edit host file. 2. `node --check`. 3. `git apply --check` (patches). 4. commit "before" exists.
5. `docker cp` (+ restart if server.mjs). 6. verify md5 host==container + marker. 7. tag healthy. 8. append OPS_LOG.md.
