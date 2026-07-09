#!/usr/bin/env node
/**
 * add_rakip_settings.mjs
 *
 * 1. server.mjs: adds /api/rakip/stats endpoint + extends /api/rakip/ayar to be
 *    per-tenant aware (after migrate_rakip_tenant_uuid.sql was run)
 * 2. bi.js (container): adds "Ayarlar" 4th tab to loadRakipRoom() with:
 *    - DB stats (total records, brand count, size count, last scrape, watch count)
 *    - Scraping settings (aktif, sıklık, saatler, markalar, kaynaklar, alarm eşiği)
 *
 * Idempotency: checks for RAKIP_SETTINGS_V1 marker before patching.
 */

import { readFileSync, writeFileSync } from 'fs';

// ─── 1. server.mjs patch ──────────────────────────────────────────────────────
const SERVER = '/opt/krb-assessment/server.mjs';
let srv = readFileSync(SERVER, 'utf8');

if (!srv.includes('// RAKIP_STATS_V1')) {
  // Insert before the rakip 404 fallthrough (end of rakip section)
  const ANCHOR = "  // ── End of rakip handlers ──";
  const STATS_ENDPOINT = `
  // ── GET /api/rakip/stats — veritabanı istatistikleri ─────────────────────
  // RAKIP_STATS_V1
  if (request.method === 'GET' && url.pathname === '/api/rakip/stats') {
    const _s = await requireModuleAccess(request, 'intelligence').catch(()=>null)
             || await requireModuleAccess(request, 'saha').catch(()=>null);
    if (!_s?.tenantId) { sendJson(response, 401, { error: 'Unauthorized' }); return; }
    const tid = _s.tenantId;
    const [totals, brands, sizes, lastScrape, watched, alarmCount] = await Promise.all([
      pool.query('SELECT COUNT(*) AS toplam FROM bi_rakip_fiyat WHERE tenant_id=$1', [tid]),
      pool.query('SELECT COUNT(DISTINCT marka) AS sayi FROM bi_rakip_fiyat WHERE tenant_id=$1', [tid]),
      pool.query('SELECT COUNT(DISTINCT ebat) AS sayi FROM bi_rakip_fiyat WHERE tenant_id=$1', [tid]),
      pool.query('SELECT MAX(scraped_at) AS son_tarama FROM bi_rakip_fiyat WHERE tenant_id=$1', [tid]),
      pool.query('SELECT COUNT(*) AS sayi FROM bi_rakip_izle WHERE tenant_id=$1 AND aktif=true', [tid]),
      pool.query('SELECT COUNT(*) AS sayi FROM bi_rakip_fiyat_alarm WHERE tenant_id=$1 AND NOT goruldu', [tid]),
    ]);
    sendJson(response, 200, {
      toplam_kayit:  parseInt(totals.rows[0].toplam),
      marka_sayisi:  parseInt(brands.rows[0].sayi),
      ebat_sayisi:   parseInt(sizes.rows[0].sayi),
      son_tarama:    lastScrape.rows[0].son_tarama,
      aktif_izleme:  parseInt(watched.rows[0].sayi),
      okunmamis_alarm: parseInt(alarmCount.rows[0].sayi),
    });
    return;
  }

  // ── GET /api/rakip/ayar — per-tenant settings (updated for composite PK) ──
  // (replaces any old GET /api/rakip/ayar that didn't pass tenant_id)
  if (request.method === 'GET' && url.pathname === '/api/rakip/ayar') {
    const _s = await requireModuleAccess(request, 'intelligence').catch(()=>null)
             || await requireModuleAccess(request, 'saha').catch(()=>null);
    const tid = _s?.tenantId || null;
    let rows = [];
    try {
      // Try per-tenant first (after migration)
      if (tid) {
        const r = await pool.query(
          'SELECT key, value FROM bi_rakip_izle_ayar WHERE tenant_id=$1', [tid]);
        rows = r.rows;
      }
      if (!rows.length) {
        // Fallback: global (pre-migration or no rows yet)
        const r = await pool.query('SELECT key, value FROM bi_rakip_izle_ayar');
        rows = r.rows;
      }
    } catch (_) {}
    const ayar = {};
    for (const r of rows) ayar[r.key] = r.value;
    sendJson(response, 200, { ayar });
    return;
  }

  // ── PUT /api/rakip/ayar — save settings ────────────────────────────────────
  if (request.method === 'PUT' && url.pathname === '/api/rakip/ayar') {
    const _s = await requireModuleAccess(request, 'intelligence').catch(()=>null)
             || await requireModuleAccess(request, 'saha').catch(()=>null);
    if (!_s?.tenantId) { sendJson(response, 401, { error: 'Unauthorized' }); return; }
    const tid = _s.tenantId;
    const updates = body || {};
    for (const [key, value] of Object.entries(updates)) {
      if (typeof key !== 'string' || key.length > 100) continue;
      const val = String(value ?? '');
      try {
        await pool.query(
          \`INSERT INTO bi_rakip_izle_ayar (key, value, tenant_id)
             VALUES ($1, $2, $3)
             ON CONFLICT (key, tenant_id) DO UPDATE SET value=$2, guncellendi_at=NOW()\`,
          [key, val, tid]
        );
      } catch (_) {
        // Fallback for pre-migration (single PK = key)
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

`;

  if (srv.includes(ANCHOR)) {
    srv = srv.replace(ANCHOR, STATS_ENDPOINT + ANCHOR);
    console.log('✓ server.mjs: /api/rakip/stats + ayar endpoints eklendi');
  } else {
    // Fallback: insert before the saha check
    const SAHA_CHECK = "  if (url.pathname.startsWith('/api/saha/')) return handleSahaApi";
    if (srv.includes(SAHA_CHECK)) {
      srv = srv.replace(SAHA_CHECK, STATS_ENDPOINT + '  ' + SAHA_CHECK);
      console.log('✓ server.mjs: fallback anchor kullanıldı (saha check öncesi)');
    } else {
      console.error('✗ server.mjs anchor bulunamadı — manuel ekleme gerekiyor');
    }
  }
  writeFileSync(SERVER, srv, 'utf8');
} else {
  console.log('— server.mjs: RAKIP_STATS_V1 zaten mevcut, atlanıyor');
}

// ─── 2. bi.js patch — Ayarlar tab ────────────────────────────────────────────
const BIJS = '/opt/krb-assessment/shells/bi.js';
let bi = readFileSync(BIJS, 'utf8');

if (bi.includes('// RAKIP_SETTINGS_TAB_V1')) {
  console.log('— bi.js: RAKIP_SETTINGS_TAB_V1 zaten mevcut, atlanıyor');
  process.exit(0);
}

// Find the tab bar in loadRakipRoom and add Ayarlar tab
const OLD_ALARMLAR_BTN = `          <button onclick="rfTab('alarmlar')" id="rf-tab-alarmlar"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#888;margin-bottom:-2px">
            Alarmlar <span id="rf-alarm-count" style="display:none;background:#e53e3e;color:#fff;
              border-radius:10px;padding:1px 5px;font-size:11px;margin-left:4px">0</span>
          </button>`;

const NEW_ALARMLAR_BTN = `          <button onclick="rfTab('alarmlar')" id="rf-tab-alarmlar"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#888;margin-bottom:-2px">
            Alarmlar <span id="rf-alarm-count" style="display:none;background:#e53e3e;color:#fff;
              border-radius:10px;padding:1px 5px;font-size:11px;margin-left:4px">0</span>
          </button>
          <button onclick="rfTab('ayarlar')" id="rf-tab-ayarlar"
            style="padding:10px 20px;border:none;background:none;font-size:14px;font-weight:600;
                   cursor:pointer;border-bottom:3px solid transparent;color:#888;margin-bottom:-2px">⚙ Ayarlar</button>`;

if (!bi.includes(OLD_ALARMLAR_BTN)) {
  console.error('✗ bi.js: Alarmlar tab butonu bulunamadı');
  process.exit(1);
}
bi = bi.replace(OLD_ALARMLAR_BTN, NEW_ALARMLAR_BTN);
console.log('✓ bi.js: Ayarlar tab butonu eklendi');

// Add the Ayarlar pane after the alarmlar pane closing div
const OLD_ALARM_PANE_END = `        <div id="rf-pane-alarmlar" style="display:none">
          <div style="display:flex;justify-content:space-between;margin-bottom:12px">
            <div id="rf-alarm-info" style="font-size:13px;color:#555"></div>
            <button onclick="rfHepsiniOku()"
              style="padding:5px 14px;background:#718096;color:#fff;border:none;border-radius:5px;font-size:13px;cursor:pointer">Tümünü Okundu İşaretle</button>
          </div>
          <div id="rf-alarm-table"></div>
        </div>
      </div>
    \`;`;

const NEW_ALARM_PANE_END = `        <div id="rf-pane-alarmlar" style="display:none">
          <div style="display:flex;justify-content:space-between;margin-bottom:12px">
            <div id="rf-alarm-info" style="font-size:13px;color:#555"></div>
            <button onclick="rfHepsiniOku()"
              style="padding:5px 14px;background:#718096;color:#fff;border:none;border-radius:5px;font-size:13px;cursor:pointer">Tümünü Okundu İşaretle</button>
          </div>
          <div id="rf-alarm-table"></div>
        </div>
        <div id="rf-pane-ayarlar" style="display:none">
          <!-- RAKIP_SETTINGS_TAB_V1 -->
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;max-width:900px">

            <!-- Sol: Veritabanı Durumu -->
            <div style="background:#f7fafc;border-radius:10px;padding:20px;border:1px solid #e2e8f0">
              <div style="font-size:15px;font-weight:700;color:#2d3748;margin-bottom:16px">📊 Veritabanı Durumu</div>
              <div id="rf-stats-yukleniyor" style="color:#888;font-size:13px">Yükleniyor...</div>
              <div id="rf-stats-grid" style="display:none;gap:12px;display:none">
                <table style="width:100%;border-collapse:collapse;font-size:13px">
                  <tbody id="rf-stats-tbody"></tbody>
                </table>
              </div>
              <div style="margin-top:14px;padding-top:12px;border-top:1px solid #e2e8f0">
                <button onclick="rfYukleStats()"
                  style="padding:6px 14px;background:#ebf8ff;color:#2b6cb0;border:1px solid #bee3f8;border-radius:6px;font-size:12px;cursor:pointer">↻ Yenile</button>
              </div>
            </div>

            <!-- Sağ: Tarama Ayarları -->
            <div style="background:#f7fafc;border-radius:10px;padding:20px;border:1px solid #e2e8f0">
              <div style="font-size:15px;font-weight:700;color:#2d3748;margin-bottom:16px">⚙ Tarama Ayarları</div>
              <div style="display:flex;flex-direction:column;gap:12px;font-size:13px">

                <label style="display:flex;align-items:center;gap:10px;cursor:pointer">
                  <input type="checkbox" id="rf-ayar-aktif" style="width:16px;height:16px;cursor:pointer">
                  <span style="font-weight:600">Otomatik tarama aktif</span>
                </label>

                <div>
                  <div style="font-weight:600;color:#4a5568;margin-bottom:4px">Tarama sıklığı (günde kaç kez)</div>
                  <select id="rf-ayar-sikligi"
                    style="width:100%;padding:7px 10px;border:1px solid #cbd5e0;border-radius:6px;font-size:13px;background:#fff">
                    <option value="1">1 kez (günlük)</option>
                    <option value="2">2 kez (sabah + akşam)</option>
                    <option value="3">3 kez (sabah / öğle / akşam)</option>
                    <option value="6">6 kez (her 4 saatte)</option>
                    <option value="24">24 kez (saatlik)</option>
                  </select>
                </div>

                <div>
                  <div style="font-weight:600;color:#4a5568;margin-bottom:4px">Tarama saatleri (virgülle)</div>
                  <input id="rf-ayar-saatler" type="text" placeholder="08:00,13:00,18:00"
                    style="width:100%;padding:7px 10px;border:1px solid #cbd5e0;border-radius:6px;font-size:13px;box-sizing:border-box">
                </div>

                <div>
                  <div style="font-weight:600;color:#4a5568;margin-bottom:4px">İzlenecek markalar (virgülle)</div>
                  <textarea id="rf-ayar-markalar" rows="2" placeholder="Continental,Bridgestone,Michelin,Lassa,Pirelli"
                    style="width:100%;padding:7px 10px;border:1px solid #cbd5e0;border-radius:6px;font-size:13px;resize:vertical;box-sizing:border-box"></textarea>
                </div>

                <div>
                  <div style="font-weight:600;color:#4a5568;margin-bottom:4px">Kaynak siteler (virgülle)</div>
                  <input id="rf-ayar-kaynaklar" type="text" placeholder="lastikborsasi,lastiksepeti,n11"
                    style="width:100%;padding:7px 10px;border:1px solid #cbd5e0;border-radius:6px;font-size:13px;box-sizing:border-box">
                </div>

                <div>
                  <div style="font-weight:600;color:#4a5568;margin-bottom:4px">Varsayılan alarm eşiği (%)</div>
                  <input id="rf-ayar-esik2" type="number" min="1" max="50" step="0.5" value="10"
                    style="width:100%;padding:7px 10px;border:1px solid #cbd5e0;border-radius:6px;font-size:13px;box-sizing:border-box">
                </div>

                <button onclick="rfKaydetTumAyarlar()"
                  style="padding:9px;background:#3182ce;color:#fff;border:none;border-radius:6px;font-size:14px;font-weight:600;cursor:pointer;width:100%;margin-top:4px">
                  Ayarları Kaydet
                </button>
                <div id="rf-ayar-msg" style="font-size:12px;text-align:center;min-height:16px"></div>
              </div>
            </div>

          </div>
        </div>
      </div>
    \`;`;

if (!bi.includes(OLD_ALARM_PANE_END)) {
  console.error('✗ bi.js: Alarmlar pane kapanış bloğu bulunamadı');
  process.exit(1);
}
bi = bi.replace(OLD_ALARM_PANE_END, NEW_ALARM_PANE_END);
console.log('✓ bi.js: Ayarlar pane HTML eklendi');

// Extend rfTab to handle 'ayarlar'
const OLD_RFTAB = `    window.rfTab = function(tab) {
      ['piyasa','izleme','alarmlar'].forEach(t => {
        const pane = document.getElementById('rf-pane-' + t);
        const btn  = document.getElementById('rf-tab-'  + t);
        if (!pane || !btn) return;
        pane.style.display = t === tab ? 'block' : 'none';
        btn.style.borderBottomColor = t === tab ? '#3182ce' : 'transparent';
        btn.style.color = t === tab ? '#3182ce' : '#888';
      });
      if (tab === 'izleme')   rfYukleIzle();
      if (tab === 'alarmlar') rfYukleAlarm();
    };`;

const NEW_RFTAB = `    window.rfTab = function(tab) {
      ['piyasa','izleme','alarmlar','ayarlar'].forEach(t => {
        const pane = document.getElementById('rf-pane-' + t);
        const btn  = document.getElementById('rf-tab-'  + t);
        if (!pane || !btn) return;
        pane.style.display = t === tab ? 'block' : 'none';
        btn.style.borderBottomColor = t === tab ? '#3182ce' : 'transparent';
        btn.style.color = t === tab ? '#3182ce' : '#888';
      });
      if (tab === 'izleme')   rfYukleIzle();
      if (tab === 'alarmlar') rfYukleAlarm();
      if (tab === 'ayarlar')  { rfYukleStats(); rfYukleAyarlar(); }
    };`;

if (!bi.includes(OLD_RFTAB)) {
  console.error('✗ bi.js: rfTab fonksiyonu bulunamadı');
  process.exit(1);
}
bi = bi.replace(OLD_RFTAB, NEW_RFTAB);
console.log('✓ bi.js: rfTab güncellendi (ayarlar desteği)');

// Add rfYukleStats + rfYukleAyarlar + rfKaydetTumAyarlar before rfYukleOzet
const BEFORE_OZET = `    async function rfYukleOzet() {`;

const SETTINGS_FNS = `    window.rfYukleStats = async function() {
      const tbody = document.getElementById('rf-stats-tbody');
      const loading = document.getElementById('rf-stats-yukleniyor');
      const grid = document.getElementById('rf-stats-grid');
      if (!tbody) return;
      if (loading) loading.style.display = 'block';
      if (grid) grid.style.display = 'none';
      try {
        const d = await rfApi('/api/rakip/stats');
        const sonTarama = d.son_tarama
          ? new Date(d.son_tarama).toLocaleString('tr-TR', {day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'})
          : '—';
        tbody.innerHTML = [
          ['Toplam fiyat kaydı', (d.toplam_kayit||0).toLocaleString('tr-TR')],
          ['Farklı marka',       d.marka_sayisi || '—'],
          ['Farklı ebat',        d.ebat_sayisi  || '—'],
          ['Aktif izleme SKU',   d.aktif_izleme || '0'],
          ['Okunmamış alarm',    d.okunmamis_alarm || '0'],
          ['Son tarama',         sonTarama],
        ].map(([k,v]) =>
          \`<tr style="border-bottom:1px solid #e2e8f0">
             <td style="padding:8px 4px;color:#718096">\${k}</td>
             <td style="padding:8px 4px;font-weight:600;text-align:right">\${v}</td>
           </tr>\`
        ).join('');
        if (loading) loading.style.display = 'none';
        if (grid) { grid.style.display = 'table'; grid.style.display = 'block'; }
        const statsDiv = document.getElementById('rf-stats-grid');
        if (statsDiv) statsDiv.style.display = 'block';
      } catch(e) {
        if (tbody) tbody.innerHTML = \`<tr><td colspan="2" style="color:#e53e3e;padding:8px">Hata: \${e.message}</td></tr>\`;
        if (loading) loading.style.display = 'none';
      }
    };

    window.rfYukleAyarlar = async function() {
      try {
        const d = await rfApi('/api/rakip/ayar');
        const a = d.ayar || {};
        const el = id => document.getElementById(id);
        if (el('rf-ayar-aktif'))   el('rf-ayar-aktif').checked = (a.scraping_aktif || 'true') === 'true';
        if (el('rf-ayar-sikligi')) el('rf-ayar-sikligi').value = a.scraping_sikligi || '3';
        if (el('rf-ayar-saatler')) el('rf-ayar-saatler').value = a.scraping_saatleri || '08:00,13:00,18:00';
        if (el('rf-ayar-markalar')) el('rf-ayar-markalar').value = a.scraping_markalar || '';
        if (el('rf-ayar-kaynaklar')) el('rf-ayar-kaynaklar').value = a.scraping_kaynaklar || '';
        if (el('rf-ayar-esik2'))   el('rf-ayar-esik2').value = a.alarm_esigi_varsayilan || '10';
      } catch(e) { console.warn('Ayarlar yüklenemedi:', e.message); }
    };

    window.rfKaydetTumAyarlar = async function() {
      const el = id => document.getElementById(id);
      const msg = el('rf-ayar-msg');
      const payload = {
        scraping_aktif:     el('rf-ayar-aktif')?.checked ? 'true' : 'false',
        scraping_sikligi:   el('rf-ayar-sikligi')?.value  || '3',
        scraping_saatleri:  el('rf-ayar-saatler')?.value  || '',
        scraping_markalar:  el('rf-ayar-markalar')?.value || '',
        scraping_kaynaklar: el('rf-ayar-kaynaklar')?.value || '',
        alarm_esigi_varsayilan: el('rf-ayar-esik2')?.value || '10',
      };
      try {
        await rfApi('/api/rakip/ayar', 'PUT', payload);
        if (msg) { msg.style.color = '#38a169'; msg.textContent = '✓ Ayarlar kaydedildi'; }
        setTimeout(() => { if (msg) msg.textContent = ''; }, 3000);
      } catch(e) {
        if (msg) { msg.style.color = '#e53e3e'; msg.textContent = 'Hata: ' + e.message; }
      }
    };

    `;

if (!bi.includes(BEFORE_OZET)) {
  console.error('✗ bi.js: rfYukleOzet fonksiyonu bulunamadı');
  process.exit(1);
}
bi = bi.replace(BEFORE_OZET, SETTINGS_FNS + BEFORE_OZET);
console.log('✓ bi.js: rfYukleStats + rfYukleAyarlar + rfKaydetTumAyarlar eklendi');

writeFileSync(BIJS, bi, 'utf8');
console.log(`\n✓ add_rakip_settings.mjs tamamlandı`);
console.log('  bi.js: Ayarlar tab (DB istatistikleri + tarama ayarları)');
console.log('  server.mjs: /api/rakip/stats + /api/rakip/ayar (PUT) endpoints');
