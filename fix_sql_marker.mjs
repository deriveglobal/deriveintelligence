#!/usr/bin/env node
// Marker yanlışlıkla SQL string'in içine girdi — dışarı çıkarır
import { readFileSync, writeFileSync } from 'fs';

const SRV = '/app/server.mjs';
let srv = readFileSync(SRV, 'utf8');

const BAD  = `' satici_sayisi, yorum_sayisi, puan, scraped_at // RAKIP_GROUPING_V1'`;
const GOOD = `' satici_sayisi, yorum_sayisi, puan, scraped_at' // RAKIP_GROUPING_V1`;

if (!srv.includes(BAD)) {
  console.log('— Zaten düzeltilmiş veya farklı bir durum. Kontrol et:');
  const idx = srv.indexOf('RAKIP_GROUPING_V1');
  if (idx >= 0) console.log('  Marker konumu:', srv.substring(idx-60, idx+40));
  process.exit(0);
}

srv = srv.replace(BAD, GOOD);
writeFileSync(SRV, srv, 'utf8');
console.log('✓ SQL marker düzeltildi — artık string dışında JS yorumu olarak');
