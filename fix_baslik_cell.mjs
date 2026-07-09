import { readFileSync, writeFileSync } from 'fs';
const BI = '/app/shells/bi.js';
let bi = readFileSync(BI, 'utf8');
const OLD = `<td style="padding:9px 12px;color:#9ab;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${g.ebat}">${g.ebat}</td>`;
const NEW = OLD + `<td style="padding:9px 12px;max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#667;font-size:11px" title="${(g.modeller||[]).join('|')}">${(g.modeller||[])[0]||'—'}</td>`;
if (!bi.includes(OLD)) { console.error('x anchor bulunamadi'); process.exit(1); }
bi = bi.replace(OLD, NEW);
writeFileSync(BI, bi, 'utf8');
console.log('OK Baslik hucresi eklendi');
