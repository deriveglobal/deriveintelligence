#!/usr/bin/env node
/**
 * fix_rakip_grouping.mjs
 * 1. server.mjs: /api/rakip/piyasa SQL'e genislik/profil/cap ekle
 * 2. bi.js: gruplama key'ini marka+parsed_size'a çek (cross-platform birleşme)
 * 3. bi.js: satici_sayisi'ni per-kaynak sakla + her source cell'inde göster
 * Idempotency: RAKIP_GROUPING_V1
 */
import { readFileSync, writeFileSync } from 'fs';

// ── server.mjs ────────────────────────────────────────────────────────────────
const SRV = '/app/server.mjs';
let srv = readFileSync(SRV, 'utf8');

if (!srv.includes('// RAKIP_GROUPING_V1')) {
  const SRV_OLD = `'SELECT kaynak, marka, model, ebat, fiyat, stok, url,' +\n      ' satici_sayisi, yorum_sayisi, puan, scraped_at'`;
  const SRV_NEW = `'SELECT kaynak, marka, model, ebat, genislik, profil, cap, fiyat, stok, url,' +\n      ' satici_sayisi, yorum_sayisi, puan, scraped_at // RAKIP_GROUPING_V1'`;
  if (!srv.includes(SRV_OLD)) { console.error('✗ server.mjs SELECT anchor bulunamadı'); process.exit(1); }
  srv = srv.replace(SRV_OLD, SRV_NEW);
  writeFileSync(SRV, srv, 'utf8');
  console.log('✓ server.mjs: genislik/profil/cap SELECT\'e eklendi');
} else {
  console.log('— server.mjs zaten güncel');
}

// ── bi.js ─────────────────────────────────────────────────────────────────────
const BI = '/app/shells/bi.js';
let bi = readFileSync(BI, 'utf8');

if (bi.includes('// RAKIP_GROUPING_V1')) { console.log('— bi.js zaten güncel'); process.exit(0); }

// 1. Gruplama döngüsü — key + saticiPerKaynak
const GRP_OLD = `        const groups = {}, kaynakSet = new Set();
        for (const r of data.rows) {
          const key = r.marka + ' | ' + r.ebat;
          if (!groups[key]) groups[key] = { marka: r.marka, ebat: r.ebat, fiyatlar: {}, demand: {} };
          groups[key].fiyatlar[r.kaynak] = parseFloat(r.fiyat);
          kaynakSet.add(r.kaynak);
          if (r.satici_sayisi) groups[key].demand.satici_sayisi = r.satici_sayisi;
          if (r.yorum_sayisi)  groups[key].demand.yorum_sayisi  = r.yorum_sayisi;
          if (r.puan)          groups[key].demand.puan          = r.puan;
        }`;

const GRP_NEW = `        const groups = {}, kaynakSet = new Set(); // RAKIP_GROUPING_V1
        for (const r of data.rows) {
          // Parsed boyut varsa marka+ebat yerine marka+205/55R16 kullan → cross-platform birleşme
          const sz = (r.genislik && r.profil && r.cap) ? \`\${r.genislik}/\${r.profil}R\${r.cap}\` : r.ebat;
          const key = r.marka.toLowerCase() + '|' + sz;
          if (!groups[key]) groups[key] = { marka: r.marka, ebat: sz, fiyatlar: {}, saticiPerKaynak: {}, demand: {} };
          const pf = parseFloat(r.fiyat);
          // Per kaynak en düşük fiyatı tut (aynı kaynaktan iki farklı model varsa ucuzunu göster)
          if (!groups[key].fiyatlar[r.kaynak] || pf < groups[key].fiyatlar[r.kaynak]) groups[key].fiyatlar[r.kaynak] = pf;
          kaynakSet.add(r.kaynak);
          if (r.satici_sayisi) groups[key].saticiPerKaynak[r.kaynak] = parseInt(r.satici_sayisi);
          if (r.yorum_sayisi)  groups[key].demand.yorum_sayisi  = r.yorum_sayisi;
          if (r.puan)          groups[key].demand.puan          = r.puan;
        }`;

if (!bi.includes(GRP_OLD)) { console.error('✗ bi.js gruplama döngüsü anchor bulunamadı'); process.exit(1); }
bi = bi.replace(GRP_OLD, GRP_NEW);
console.log('✓ bi.js: gruplama key → marka+ebat_parsed, saticiPerKaynak eklendi');

// 2. Source cell rendering — satici_sayisi inline göster
const CELL_OLD = `                const f = g.fiyatlar[k];
                return \`<td style="padding:9px 12px;text-align:right;\${f&&f===min?'color:#38a169;font-weight:700':'color:#94a3b8'}">\${f?f.toLocaleString('tr-TR')+' ₺':'<span style="color:#445">—</span>'}</td>\`;`;

const CELL_NEW = `                const f = g.fiyatlar[k];
                const sat = g.saticiPerKaynak?.[k];
                const satStr = sat ? \`<br><span style="font-size:10px;color:#7a8a9a">\${sat} satıcı</span>\` : '';
                return \`<td style="padding:9px 12px;text-align:right;\${f&&f===min?'color:#38a169;font-weight:700':'color:#94a3b8'}">\${f?f.toLocaleString('tr-TR')+' ₺'+satStr:'<span style="color:#445">—</span>'}</td>\`;`;

if (!bi.includes(CELL_OLD)) { console.error('✗ bi.js cell render anchor bulunamadı'); process.exit(1); }
bi = bi.replace(CELL_OLD, CELL_NEW);
console.log('✓ bi.js: kaynak cell\'e satıcı sayısı eklendi');

// 3. Talep kolonundan satici_sayisi kaldır (artık inline gösteriliyor)
const DEM_OLD = `          if (g.demand.satici_sayisi) demand.push('🏪' + g.demand.satici_sayisi);
          if (g.demand.yorum_sayisi)  demand.push('🛒' + g.demand.yorum_sayisi);
          if (g.demand.puan)          demand.push('⭐' + g.demand.puan);`;

const DEM_NEW = `          if (g.demand.yorum_sayisi)  demand.push('🛒' + g.demand.yorum_sayisi);
          if (g.demand.puan)          demand.push('⭐' + g.demand.puan);`;

if (!bi.includes(DEM_OLD)) { console.error('✗ bi.js demand display anchor bulunamadı'); process.exit(1); }
bi = bi.replace(DEM_OLD, DEM_NEW);
console.log('✓ bi.js: Talep kolonundan satici_sayisi kaldırıldı (inline gösteriliyor)');

writeFileSync(BI, bi, 'utf8');
console.log('\n✓ fix_rakip_grouping.mjs tamamlandı');
