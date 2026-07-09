#!/usr/bin/env node
/**
 * fix_rakip_ayarlar_layout.mjs
 * Fixes Ayarlar tab layout: 2-column cramped grid → side-by-side with proper widths
 * Uses flex with fixed right panel so Tarama Ayarları isn't squished.
 * Idempotency: AYARLAR_LAYOUT_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/shells/bi.js';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// AYARLAR_LAYOUT_V1')) {
  console.log('Zaten uygulandı — atlanıyor'); process.exit(0);
}

// Replace the cramped 2-column grid with a proper flex layout
const OLD_GRID = `          <div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;max-width:900px">

            <!-- Sol: Veritabanı Durumu -->
            <div style="background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">
              <div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:16px">📊 Veritabanı Durumu</div>`;

const NEW_GRID = `          <!-- AYARLAR_LAYOUT_V1 -->
          <div style="display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap">

            <!-- Sol: Veritabanı Durumu -->
            <div style="flex:1;min-width:320px;background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">
              <div style="font-size:15px;font-weight:700;color:#e2e8f0;margin-bottom:16px">📊 Veritabanı Durumu</div>`;

if (!src.includes(OLD_GRID)) {
  console.error('✗ Grid container bulunamadı');
  process.exit(1);
}
src = src.replace(OLD_GRID, NEW_GRID);

// Fix right panel width
const OLD_RIGHT = `            <!-- Sağ: Tarama Ayarları -->
            <div style="background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">`;

const NEW_RIGHT = `            <!-- Sağ: Tarama Ayarları -->
            <div style="width:320px;min-width:280px;background:rgba(255,255,255,0.06);border-radius:10px;padding:20px;border:1px solid rgba(255,255,255,0.12)">`;

if (!src.includes(OLD_RIGHT)) {
  console.error('✗ Sağ panel bulunamadı');
  process.exit(1);
}
src = src.replace(OLD_RIGHT, NEW_RIGHT);

// Also fix select/input widths inside the right panel to use 100% properly
// The select for sıklık currently uses full width which is fine
// Fix the textarea and inputs to have proper sizing
src = src.replace(
  `<select id="rf-ayar-sikligi"\n                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;background:rgba(255,255,255,0.08)">`,
  `<select id="rf-ayar-sikligi"\n                    style="width:100%;padding:7px 10px;border:1px solid rgba(255,255,255,0.18);border-radius:6px;font-size:13px;background:rgba(255,255,255,0.08);color:#e2e8f0">`
);

writeFileSync(TARGET, src, 'utf8');
console.log('✓ Ayarlar layout düzeltildi: flex ile geniş sağ panel');
console.log(`  Toplam satır: ${src.split('\n').length}`);
