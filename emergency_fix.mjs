#!/usr/bin/env node
// Acil fix: // yorumu + operatörünü yuttu — satırı restore et
import { readFileSync, writeFileSync } from 'fs';

const SRV = '/app/server.mjs';
let srv = readFileSync(SRV, 'utf8');

// Bozuk satır: comment + operatörü yiyor
const BAD  = `' satici_sayisi, yorum_sayisi, puan, scraped_at' // RAKIP_GROUPING_V1`;
const GOOD = `' satici_sayisi, yorum_sayisi, puan, scraped_at'`; // RAKIP_GROUPING_V1

if (!srv.includes(BAD)) {
  console.error('✗ Bozuk satır bulunamadı — manuel kontrol gerekli');
  // Mevcut durumu göster
  const idx = srv.indexOf('RAKIP_GROUPING_V1');
  if (idx >= 0) console.log('Marker konumu:\n', srv.substring(idx-80, idx+60));
  process.exit(1);
}

srv = srv.replace(BAD, GOOD);
writeFileSync(SRV, srv, 'utf8');
console.log('✓ server.mjs düzeltildi — marker JS inline comment olarak kaldı');
