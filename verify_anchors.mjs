#!/usr/bin/env node
import { readFileSync } from 'fs';

const srv = readFileSync('/app/server.mjs', 'utf8');
const bi  = readFileSync('/app/shells/bi.js', 'utf8');

const checks = [
  ['server.mjs', srv, `'SELECT kaynak, marka, model, ebat, fiyat, stok, url,' +\n      ' satici_sayisi, yorum_sayisi, puan, scraped_at'`],
  ['bi.js GRP_OLD', bi, `        const groups = {}, kaynakSet = new Set();\n        for (const r of data.rows) {\n          const key = r.marka + ' | ' + r.ebat;`],
  ['bi.js CELL_OLD', bi, `                const f = g.fiyatlar[k];\n                return \`<td style="padding:9px 12px;text-align:right;\${f&&f===min?'color:#38a169;font-weight:700':'color:#94a3b8'}">\${f?f.toLocaleString('tr-TR')+' ₺':'<span style="color:#445">—</span>'}</td>\`;`],
  ['bi.js DEM_OLD',  bi, `          if (g.demand.satici_sayisi) demand.push('🏪' + g.demand.satici_sayisi);\n          if (g.demand.yorum_sayisi)  demand.push('🛒' + g.demand.yorum_sayisi);\n          if (g.demand.puan)          demand.push('⭐' + g.demand.puan);`],
  ['already patched?', srv, '// RAKIP_GROUPING_V1'],
];

for (const [label, src, needle] of checks) {
  console.log(`${src.includes(needle) ? '✓' : '✗'} ${label}`);
}
