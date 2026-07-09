import { readFileSync, writeFileSync } from 'fs';
const SRV = '/app/server.mjs';
let srv = readFileSync(SRV, 'utf8');

if (srv.includes('// EBAT_SEARCH_V1')) { console.log('-- zaten guncel'); process.exit(0); }

const OLD = `    if (ebat)  { vals.push('%' + ebat  + '%'); where.push('ebat  ILIKE $' + vals.length); }`;
const NEW = `    if (ebat) { // EBAT_SEARCH_V1 — tire size pattern → genislik/profil/cap, otherwise ILIKE
      const sm = ebat.replace(/\\s/g,'').match(/^(\\d{3})\\/(\\d{2})[Rr](\\d{2})/);
      if (sm) {
        vals.push(parseInt(sm[1])); where.push('genislik = $' + vals.length);
        vals.push(parseInt(sm[2])); where.push('profil = $'   + vals.length);
        vals.push(parseInt(sm[3])); where.push('cap = $'      + vals.length);
      } else {
        vals.push('%' + ebat + '%'); where.push('ebat ILIKE $' + vals.length);
      }
    }`;

if (!srv.includes(OLD)) { console.error('x anchor bulunamadi'); console.log('Beklenen:\n', OLD); process.exit(1); }
srv = srv.replace(OLD, NEW);
writeFileSync(SRV, srv, 'utf8');
console.log('OK ebat arama: tire size → genislik/profil/cap, diger → ILIKE');
