# KRB Assessment — Ops Log (append-only)

Every production change is bracketed by a git commit and, when verified healthy, a `healthy-*` tag.
Rollback = `git reset --hard <tag>` (+ redeploy) or `git apply -R patches/<file>.patch`.
Deploy note: `shells/bi.js` is a static no-cache asset → `docker cp` into container, **no restart**.
`server.mjs` → `docker cp` + `docker restart krb-assessment`. Always `node --check` first; keep host `server_container.mjs`/`server.mjs` in sync.

---

## 2026-07-08 — Traceability baseline
- `git init` on /opt/krb-assessment. Discovered host `shells/bi.js` had **drifted** from the running container copy (container was ahead: RAKIP_GROUPING_V1 + an unfinished/broken model column). Captured the LIVE container file as the true baseline.
- Tags: `live-20260708-broken-modelcol` (running state before fixes), `pre-reconcile-hostold-20260708` (old host code).
- Rule: git must always reflect what is actually running.

## 2026-07-08 — RAKIP_MODEL_COL_V1  (patch: patches/rakip_model_col_v1.patch)
- Bug: piyasa pivot table rendered an extra model `<td>` with no `<th>` and `g.modeller` never populated → every price column shifted one to the right; "AKAKÇE" column showed `--`.
- Fix (shells/bi.js, rfPiyasaAra): add `modeller:[]` to group, populate from `r.model`, add the missing `Model` header. Realigns columns.
- Commit 6e06788. (Superseded by RAKIP_RAWDATA_V1.)

## 2026-07-08 — RAKIP_RAWDATA_V1  (patches: rakip_rawdata_p1_scaffold.patch, rakip_rawdata_p2_render.patch)
- Decision: the pivot compared non-equivalent products (different models/seasons/4-packs) as one row. Replaced it with an honest **Raw Data** view + a **Smart Matched** placeholder tab.
- shells/bi.js:
  - Renamed "Piyasa" tab → "Ham Veri"; added "🎯 Smart Matched" tab (`akilli`) + placeholder pane; registered `akilli` in rfTab.
  - Rewrote `rfPiyasaAra` → flat one-row-per-listing table (Kaynak/Marka/Ebat/Model/Fiyat/Birim/Satıcı/Puan/link), sorted by size→brand→price. Detects 4-packs (`4'lü/4 adet/set/takım`), badges them, shows per-unit price (fiyat/4). **HTML-escapes all scraped strings** (closed an XSS hole in the old render).
- Commit ba80256. Tag: healthy-20260708-rawdata.

## Pending
- Smart Matched normalization engine (canonical SKU across marketplaces) — task in progress.
- Scraper (`price_monitor.py`) truncates `ebat` to 30 chars in base table `bi_rakip_fiyat` → view `bi_rakip_fiyat_son` DISTINCT ON (kaynak,marka,ebat) can collapse distinct listings. Fix at source.
- TÜFE-LIVE scraper selector stale (logs "table row not found").
