#!/usr/bin/env node
/**
 * fix_rakip_delete_stats.mjs
 * 1. Fixes DELETE /api/rakip/izle/:id — adds auth + uses tid
 * 2. Adds /api/rakip/stats endpoint before the DELETE block
 * 3. Fixes GET /api/rakip/ayar — inserts after existing orphan GET/PUT ayar handlers
 *    (which may have been partially inserted by add_rakip_settings.mjs)
 * Idempotency: RAKIP_DELETE_FIX_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/server.mjs';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// RAKIP_DELETE_FIX_V1')) {
  console.log('Zaten uygulandı — atlanıyor'); process.exit(0);
}

// ── 1. Fix DELETE block + prepend stats endpoint ──────────────────────────────
const OLD_DELETE = `  // DELETE /api/rakip/izle/:id
  if (request.method === 'DELETE' && /^\\/api\\/rakip\\/izle\\/\\d+$/.test(url.pathname)) {
    const izleId = parseInt(url.pathname.split('/').pop(), 10);
    await pool.query('DELETE FROM bi_rakip_izle WHERE id=$1 AND tenant_id=$2',
      [izleId, user?.tenant_id || 1]);
    sendJson(response, 200, { ok: true }); return;
  }`;

const NEW_DELETE = `  // RAKIP_DELETE_FIX_V1

  // GET /api/rakip/stats — veritabanı istatistikleri
  if (request.method === 'GET' && url.pathname === '/api/rakip/stats') {
    const _stSess = await requireModuleAccess(request, 'intelligence').catch(()=>null)
                 || await requireModuleAccess(request, 'saha').catch(()=>null);
    if (!_stSess?.tenantId) { sendJson(response, 401, { error: 'Unauthorized' }); return; }
    const stTid = _stSess.tenantId;
    const [totals, brands, sizes, lastScrape, watched, alarmCount] = await Promise.all([
      pool.query('SELECT COUNT(*) AS toplam FROM bi_rakip_fiyat WHERE tenant_id=$1', [stTid]),
      pool.query('SELECT COUNT(DISTINCT marka) AS sayi FROM bi_rakip_fiyat WHERE tenant_id=$1', [stTid]),
      pool.query('SELECT COUNT(DISTINCT ebat) AS sayi FROM bi_rakip_fiyat WHERE tenant_id=$1', [stTid]),
      pool.query('SELECT MAX(scraped_at) AS son_tarama FROM bi_rakip_fiyat WHERE tenant_id=$1', [stTid]),
      pool.query('SELECT COUNT(*) AS sayi FROM bi_rakip_izle WHERE tenant_id=$1 AND aktif=true', [stTid]),
      pool.query('SELECT COUNT(*) AS sayi FROM bi_rakip_fiyat_alarm WHERE tenant_id=$1 AND NOT goruldu', [stTid]),
    ]);
    sendJson(response, 200, {
      toplam_kayit:    parseInt(totals.rows[0].toplam),
      marka_sayisi:    parseInt(brands.rows[0].sayi),
      ebat_sayisi:     parseInt(sizes.rows[0].sayi),
      son_tarama:      lastScrape.rows[0].son_tarama,
      aktif_izleme:    parseInt(watched.rows[0].sayi),
      okunmamis_alarm: parseInt(alarmCount.rows[0].sayi),
    });
    return;
  }

  // GET /api/rakip/ayar — per-tenant settings
  if (request.method === 'GET' && url.pathname === '/api/rakip/ayar') {
    const _aySess = await requireModuleAccess(request, 'intelligence').catch(()=>null)
                 || await requireModuleAccess(request, 'saha').catch(()=>null);
    const ayTid = _aySess?.tenantId || null;
    let rows = [];
    try {
      if (ayTid) {
        const r = await pool.query(
          'SELECT key, value FROM bi_rakip_izle_ayar WHERE tenant_id=$1', [ayTid]);
        rows = r.rows;
      }
      if (!rows.length) {
        const r = await pool.query('SELECT key, value FROM bi_rakip_izle_ayar');
        rows = r.rows;
      }
    } catch (_) {}
    const ayar = {};
    for (const r of rows) ayar[r.key] = r.value;
    sendJson(response, 200, { ayar });
    return;
  }

  // PUT /api/rakip/ayar — save per-tenant settings
  if (request.method === 'PUT' && url.pathname === '/api/rakip/ayar') {
    const _aySess2 = await requireModuleAccess(request, 'intelligence').catch(()=>null)
                  || await requireModuleAccess(request, 'saha').catch(()=>null);
    if (!_aySess2?.tenantId) { sendJson(response, 401, { error: 'Unauthorized' }); return; }
    const ayTid2 = _aySess2.tenantId;
    const updates = body || {};
    for (const [key, value] of Object.entries(updates)) {
      if (typeof key !== 'string' || key.length > 100) continue;
      const val = String(value ?? '');
      try {
        await pool.query(
          \`INSERT INTO bi_rakip_izle_ayar (key, value, tenant_id)
             VALUES ($1, $2, $3)
             ON CONFLICT (key, tenant_id) DO UPDATE SET value=$2, guncellendi_at=NOW()\`,
          [key, val, ayTid2]
        );
      } catch (_) {
        await pool.query(
          \`INSERT INTO bi_rakip_izle_ayar (key, value)
             VALUES ($1, $2)
             ON CONFLICT (key) DO UPDATE SET value=$2, guncellendi_at=NOW()\`,
          [key, val]
        );
      }
    }
    sendJson(response, 200, { ok: true });
    return;
  }

  // DELETE /api/rakip/izle/:id
  if (request.method === 'DELETE' && /^\\/api\\/rakip\\/izle\\/\\d+$/.test(url.pathname)) {
    const _delSess = await requireModuleAccess(request, 'intelligence').catch(()=>null)
                  || await requireModuleAccess(request, 'saha').catch(()=>null);
    if (!_delSess?.tenantId) { sendJson(response, 401, { error: 'Unauthorized' }); return; }
    const delTid = _delSess.tenantId;
    const izleId = parseInt(url.pathname.split('/').pop(), 10);
    await pool.query('DELETE FROM bi_rakip_izle WHERE id=$1 AND tenant_id=$2', [izleId, delTid]);
    sendJson(response, 200, { ok: true }); return;
  }`;

if (!src.includes(OLD_DELETE)) {
  console.error('✗ DELETE block bulunamadı — server.mjs yapısı değişmiş');
  process.exit(1);
}

src = src.replace(OLD_DELETE, NEW_DELETE);
writeFileSync(TARGET, src, 'utf8');
console.log('✓ DELETE block: auth eklendi + stats/ayar endpoints eklendi');
console.log(`  Toplam satır: ${src.split('\n').length}`);
