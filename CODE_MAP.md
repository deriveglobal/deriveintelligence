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

## Scraper — /opt/price_monitor  (SEPARATE repo + git; runs via CRON, not a container)
- `price_monitor.py` (~1740 lines) — Playwright + curl_cffi crawler. `SITES` config dict at L40 (per-site: list_urls, max_pages, search_url_tpl, size slug, item_sel/fields, proxy). Modes: probe / scrape / watched / sizescan. `main()` L1652.
- `run_size_scan()` ~L1660 = RAKIP_SIZESCAN_V1 (demand-ranked per-size). `_harvest_akakce_sizes()` ~L1630 = RAKIP_SIZESCAN_HARVEST_V1 (akakce full size list from lastik.html). `insert_rows()` writes bi_rakip_fiyat; `run_watched_scrape()` = VIP list.
- akakce size page = slug `akakce.com/lastik/{w}-{p}-r{c}.html` (SSR, curl-fetchable). n11/trendyol/pttavm = `?q={size}` search (works). akakce `?q=` is BROKEN (homepage).
- Live sources: kolayoto, n11, trendyol, lastikpazar, lastikborsasi, pttavm, akakce. Dead (0 rows): hepsiburada, cimri, lastix, lastiksiparis.
- Proxy: SmartProxy TR residential (akakce/n11/hepsiburada configs). CLI dry-run = no DB writes: `venv/bin/python3 price_monitor.py sizescan --site X --dry-run --top N`.
- Cron: akakce 04:30, n11 05:15, trendyol 06:00, pttavm 06:45 (sizescan); scrape 02:00; watched 08:00/13:00/20:00.
- Scraper deploy/edit protocol: git-tracked patch -> `git apply --recount --check` -> `py_compile` -> dry-run -> live. git identity: user.email dev@krb.local.
