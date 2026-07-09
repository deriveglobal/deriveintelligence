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

## 2026-07-08 — DB: dedup by full model (task #4)  (migration in /opt/price_monitor/migrations/)
- `bi_rakip_fiyat_son` deduped on `(kaynak,marka,ebat)` where `ebat` = 30-char TRUNCATED title fragment -> distinct listings sharing a 30-char prefix collapsed (silent loss).
- Fix: `DISTINCT ON (kaynak, tenant_id, marka, COALESCE(NULLIF(model,''), ebat))`. View rows **13,821 -> 20,911 (+51%)** recovered. Files: migration_20260708_dedup_by_model.sql + rollback_*.sql (on /opt/price_monitor, git-tracked).

## 2026-07-08 — Scraper: sizescan breadth crawl  (repo: /opt/price_monitor — SEPARATE git, runs via cron, NOT a container)
- Root cause of akakce under-coverage: flat `lastik,{page}.html` crawl trips Cloudflare at page ~15 -> only ~774 popular SKUs. Fix = breadth (crawl per-size pages), not depth.
- `sizescan` CLI mode (RAKIP_SIZESCAN_V1, ~L1660): demand-ranked (best-seller-first) per-size crawl. akakce uses slug URL `lastik/{w}-{p}-r{c}.html` (its `?q=` search bounces to homepage). n11/trendyol/pttavm use their working `?q=` search (dry-run validated).
- `_harvest_akakce_sizes` (RAKIP_SIZESCAN_HARVEST_V1, ~L1630): harvests akakce's FULL size list from its own directory (lastik.html) instead of our DB — avoids circularity, finds sizes we were missing.
- Result: **akakce 774 -> 6,876 rows (~9x)**. Commits (/opt/price_monitor): 49ffda2 baseline, cda5725 sizescan, 7d926c6 harvest. Tags: healthy-scraper-20260708-{sizescan,harvest}.
- Cron (server crontab, git-untracked — back up via `crontab -l`): akakce 04:30 `--top 500`; n11 05:15 / trendyol 06:00 / pttavm 06:45 (`--top 300`). DATABASE_URL needs `set -a && source .env && set +a` (source alone doesn't export).
- DEAD sources (0 rows, Akamai/bot-blocked): hepsiburada, cimri, lastix, lastiksiparis — need a separate "unblock" effort, NOT sizescan.
- Protocol used: every change dry-run validated (`sizescan --site X --dry-run --top N`, no DB writes) + `py_compile` gate + git-tracked patch before live.

## Pending
- **Smart Matched normalization engine** (task #7) — canonical SKU across marketplaces (pattern/size/load-speed/season/single-vs-set). Flagship, not started.
- **Revive dead sources** — hepsiburada (Akamai), cimri, lastix. Get them returning data at all.
- **Extend sizescan** — kolayoto already deep; could harvest size directories for more sources.
- **TUFE-LIVE scraper** selector stale (logs "table row not found").
- **Code cleanup** — /opt/krb-assessment littered with ~30 one-off fix_*.mjs/.py scripts + .bak files (Rule #1 debt).
