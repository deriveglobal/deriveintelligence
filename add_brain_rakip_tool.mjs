#!/usr/bin/env node
/**
 * add_brain_rakip_tool.mjs
 * 1. Adds `query_rakip_fiyat` tool to _BRAIN_TOOLS array
 * 2. Adds handler in _runBrainTool
 * 3. Updates CEO system prompt to mention competitor price awareness
 * 4. Adds /api/rakip/piyasa-ozet endpoint (for Piyasa tab visual)
 * Idempotency: BRAIN_RAKIP_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/server.mjs';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// BRAIN_RAKIP_V1')) {
  console.log('Zaten uygulandı'); process.exit(0);
}

// ── 1. Add query_rakip_fiyat to _BRAIN_TOOLS ─────────────────────────────────
const TOOLS_ANCHOR = `        {
          name: 'generate_report',`;

const RAKIP_TOOL = `        // BRAIN_RAKIP_V1
        {
          name: 'query_rakip_fiyat',
          description: 'Rakip Fiyatlar veritabanını sorgula. Rakip markaların fiyatları, piyasa durumu, okunmamış fiyat alarmları ve izleme listesi. Sahip rakip fiyat, piyasa, fiyat izleme veya marka rekabeti sorduğunda kullan.',
          input_schema: {
            type: 'object',
            properties: {
              query_type: {
                type: 'string',
                enum: ['ozet', 'piyasa', 'marka', 'alarm'],
                description: 'ozet=genel istatistik, piyasa=marka bazlı fiyat özeti, marka=belirli marka/ebat fiyatları, alarm=okunmamış fiyat alarmları'
              },
              marka: { type: 'string', description: 'Marka adı filtresi (opsiyonel, marka sorgusu için)' },
              ebat:  { type: 'string', description: 'Lastik ebatı filtresi (opsiyonel)' }
            },
            required: ['query_type']
          }
        },
        `;

if (!src.includes(TOOLS_ANCHOR)) {
  console.error('✗ generate_report tool anchor bulunamadı'); process.exit(1);
}
src = src.replace(TOOLS_ANCHOR, RAKIP_TOOL + TOOLS_ANCHOR);
console.log('✓ query_rakip_fiyat tool _BRAIN_TOOLS\'a eklendi');

// ── 2. Add handler in _runBrainTool (before query_database handler) ───────────
const QUERY_DB_ANCHOR = `        if (toolName === 'query_database') {`;

const RAKIP_HANDLER = `        if (toolName === 'query_rakip_fiyat') {
          const { query_type, marka, ebat } = input;
          const rtid = tenantId;
          try {
            if (query_type === 'ozet') {
              const [tot, izle, alarm] = await Promise.all([
                query('SELECT COUNT(*) AS toplam, COUNT(DISTINCT marka) AS markalar, COUNT(DISTINCT ebat) AS ebatlar, MAX(scraped_at) AS son_tarama FROM bi_rakip_fiyat WHERE tenant_id=$1', [rtid]),
                query('SELECT COUNT(*) AS aktif FROM bi_rakip_izle WHERE tenant_id=$1 AND aktif=true', [rtid]),
                query('SELECT COUNT(*) AS okunmamis FROM bi_rakip_fiyat_alarm WHERE tenant_id=$1 AND NOT goruldu', [rtid]),
              ]);
              return {
                toplam_fiyat_kaydi: parseInt(tot.rows[0].toplam),
                marka_sayisi:       parseInt(tot.rows[0].markalar),
                ebat_sayisi:        parseInt(tot.rows[0].ebatlar),
                son_tarama:         tot.rows[0].son_tarama,
                aktif_izleme_sku:   parseInt(izle.rows[0].aktif),
                okunmamis_alarm:    parseInt(alarm.rows[0].okunmamis),
              };
            }
            if (query_type === 'piyasa') {
              const r = await query(\`
                SELECT marka,
                       ROUND(MIN(fiyat)::numeric,0) AS min_fiyat,
                       ROUND(MAX(fiyat)::numeric,0) AS max_fiyat,
                       ROUND(AVG(fiyat)::numeric,0) AS ort_fiyat,
                       COUNT(DISTINCT ebat)         AS sku_sayisi,
                       COUNT(DISTINCT kaynak)       AS kaynak_sayisi
                FROM bi_rakip_fiyat_son WHERE tenant_id=$1
                GROUP BY marka ORDER BY sku_sayisi DESC LIMIT 15
              \`, [rtid]);
              return { markalar: r.rows };
            }
            if (query_type === 'marka') {
              let sql = 'SELECT marka, ebat, kaynak, fiyat, scraped_at FROM bi_rakip_fiyat_son WHERE tenant_id=$1';
              const params = [rtid];
              if (marka) { params.push('%'+marka+'%'); sql += \` AND LOWER(marka) LIKE LOWER($\${params.length})\`; }
              if (ebat)  { params.push(ebat); sql += \` AND ebat=$\${params.length}\`; }
              sql += ' ORDER BY marka, ebat, fiyat ASC LIMIT 50';
              const r = await query(sql, params);
              return { satirlar: r.rows, toplam: r.rows.length };
            }
            if (query_type === 'alarm') {
              const r = await query(\`
                SELECT marka, ebat, kaynak, eski_fiyat, yeni_fiyat, degisim_pct, yon, alarm_at
                FROM bi_rakip_fiyat_alarm WHERE tenant_id=$1 AND NOT goruldu
                ORDER BY alarm_at DESC LIMIT 20
              \`, [rtid]);
              return { alarmlar: r.rows, toplam: r.rows.length };
            }
            return { hata: 'Bilinmeyen query_type' };
          } catch(e) { return { hata: e.message }; }
        }
        `;

if (!src.includes(QUERY_DB_ANCHOR)) {
  console.error('✗ query_database handler anchor bulunamadı'); process.exit(1);
}
src = src.replace(QUERY_DB_ANCHOR, RAKIP_HANDLER + QUERY_DB_ANCHOR);
console.log('✓ query_rakip_fiyat handler _runBrainTool\'a eklendi');

// ── 3. Update CEO system prompt to mention rakip tool ────────────────────────
const OLD_PROMPT_END = `8. Net, kısa ve doğrudan cevap ver.'`;
const NEW_PROMPT_END = `8. Net, kısa ve doğrudan cevap ver.\\n9. Rakip fiyat / piyasa / fiyat alarmı sorularında query_rakip_fiyat kullan — piyasa durumu, okunmamış alarmlar, marka fiyat karşılaştırması.'`;

if (!src.includes(OLD_PROMPT_END)) {
  console.error('✗ CEO system prompt sonu bulunamadı'); process.exit(1);
}
src = src.replace(OLD_PROMPT_END, NEW_PROMPT_END);
console.log('✓ CEO system prompt: rakip fiyat tool talimatı eklendi');

// ── 4. Add /api/rakip/piyasa-ozet endpoint ───────────────────────────────────
const PIYASA_ANCHOR = '  // RAKIP_DELETE_FIX_V1';

if (src.includes('// PIYASA_OZET_V1')) {
  console.log('— piyasa-ozet endpoint zaten mevcut');
} else if (src.includes(PIYASA_ANCHOR)) {
  const PIYASA_EP = `  // GET /api/rakip/piyasa-ozet — brand+season+source summary for visual overview
  // PIYASA_OZET_V1
  if (request.method === 'GET' && url.pathname === '/api/rakip/piyasa-ozet') {
    const _pS = await requireModuleAccess(request,'intelligence').catch(()=>null)
             || await requireModuleAccess(request,'saha').catch(()=>null);
    const pTid = _pS?.tenantId || null;
    const tWhere = pTid ? \` WHERE tenant_id='\${pTid}'\` : '';
    try {
      const [markaRes, mevsimRes, kaynakRes, totRes] = await Promise.all([
        pool.query(\`SELECT marka,
             ROUND(MIN(fiyat)::numeric,0) AS min_fiyat, ROUND(MAX(fiyat)::numeric,0) AS max_fiyat,
             ROUND(AVG(fiyat)::numeric,0) AS ort_fiyat, COUNT(DISTINCT ebat) AS sku_sayisi,
             COUNT(DISTINCT kaynak) AS kaynak_sayisi
           FROM bi_rakip_fiyat_son\${tWhere} GROUP BY marka ORDER BY sku_sayisi DESC LIMIT 20\`),
        pool.query(\`SELECT COALESCE(mevsim,'BELİRSİZ') AS mevsim, COUNT(DISTINCT (marka||'|'||ebat)) AS sayi
           FROM bi_rakip_fiyat_son\${tWhere} GROUP BY mevsim ORDER BY sayi DESC\`),
        pool.query(\`SELECT kaynak, COUNT(*) AS kazanc FROM (
             SELECT DISTINCT ON (marka,ebat) marka, ebat, kaynak
               FROM bi_rakip_fiyat_son\${tWhere} ORDER BY marka, ebat, fiyat ASC
           ) t GROUP BY kaynak ORDER BY kazanc DESC\`),
        pool.query(\`SELECT COUNT(DISTINCT (marka||'|'||ebat)) AS toplam_sku,
             COUNT(DISTINCT kaynak) AS kaynak_sayisi, MAX(scraped_at) AS son_tarama
           FROM bi_rakip_fiyat_son\${tWhere}\`),
      ]);
      sendJson(response, 200, {
        markalar:      markaRes.rows,
        mevsimler:     mevsimRes.rows,
        kaynak_kazanc: kaynakRes.rows,
        toplam_sku:    parseInt(totRes.rows[0]?.toplam_sku||0),
        kaynak_sayisi: parseInt(totRes.rows[0]?.kaynak_sayisi||0),
        son_tarama:    totRes.rows[0]?.son_tarama,
      });
    } catch(e) { sendJson(response,500,{error:e.message}); }
    return;
  }

`;
  src = src.replace(PIYASA_ANCHOR, PIYASA_EP + PIYASA_ANCHOR);
  console.log('✓ /api/rakip/piyasa-ozet endpoint eklendi');
}

writeFileSync(TARGET, src, 'utf8');
console.log(`\n✓ add_brain_rakip_tool.mjs tamamlandı — ${src.split('\n').length} satır`);
