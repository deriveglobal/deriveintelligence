#!/usr/bin/env node
/**
 * fix_model_col.mjs — RAKIP_MODEL_COL_V1
 * 1. Model listesi toplama → gruplama döngüsüne
 * 2. "Başlık" header kolonu
 * 3. Başlık hücresi (truncate + tooltip)
 */
import { readFileSync, writeFileSync } from 'fs';

const BI = '/app/shells/bi.js';
let bi = readFileSync(BI, 'utf8');

if (bi.includes('// RAKIP_MODEL_COL_V1')) { console.log('-- Zaten guncel'); process.exit(0); }

// 1. Model listesi
const A1 = `          if (r.satici_sayisi) groups[key].saticiPerKaynak[r.kaynak] = parseInt(r.satici_sayisi);`;
const B1 = `          if (r.satici_sayisi) groups[key].saticiPerKaynak[r.kaynak] = parseInt(r.satici_sayisi); // RAKIP_MODEL_COL_V1
          if (r.model) { if (!groups[key].modeller) groups[key].modeller = []; if (!groups[key].modeller.includes(r.model)) groups[key].modeller.push(r.model); }`;
if (!bi.includes(A1)) { console.error('x Anchor 1 bulunamadi'); process.exit(1); }
bi = bi.replace(A1, B1);
console.log('+ Model listesi gruplama dongusu');

// 2. Header
const A2 = `+ '<th style="padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.15)">Ebat</th>'`;
const B2 = `+ '<th style="padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.15)">Ebat</th>'
          + '<th style="padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.15)">Baslik</th>'`;
if (!bi.includes(A2)) { console.error('x Anchor 2 bulunamadi: Ebat header'); process.exit(1); }
bi = bi.replace(A2, B2);
console.log('+ Baslik header kolonu');

// 3. Hucre
const A3 = '`<td style="max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${g.ebat}">${g.ebat}</td>`';
const B3 = '`<td style="max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${g.ebat}">${g.ebat}</td>` +\n              `<td style="padding:9px 12px;max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#94a3b8;font-size:11px" title="${(g.modeller||[]).join(\'\\n\')}">${(g.modeller||[])[0]||\'--\'}</td>`';
if (!bi.includes(A3)) { console.error('x Anchor 3 bulunamadi: ebat cell'); process.exit(1); }
bi = bi.replace(A3, B3);
console.log('+ Baslik hucresi (truncate+tooltip)');

writeFileSync(BI, bi, 'utf8');
console.log('\nOK fix_model_col.mjs tamamlandi');
