#!/usr/bin/env node
/**
 * fix_rakip_dark_theme.mjs
 * Replaces hardcoded light-theme colors inside loadRakipRoom() in bi.js
 * with dark-theme equivalents. Scoped only to the loadRakipRoom block.
 * Idempotency: DARK_THEME_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/shells/bi.js';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// DARK_THEME_V1')) {
  console.log('Zaten uygulandı — atlanıyor'); process.exit(0);
}

// Find the loadRakipRoom function boundaries
const START = 'function loadRakipRoom(cont, _apiFetch) {';
const startIdx = src.indexOf(START);
if (startIdx === -1) { console.error('loadRakipRoom bulunamadı'); process.exit(1); }

// Find the matching closing brace of loadRakipRoom
// It ends at the next top-level `  }` after the function start
// We'll find it by looking for `\n  }\n` after a reasonable point
// Safer: find the next `async function loadDeptData` which comes after
const END_MARKER = 'async function loadDeptData(';
const endIdx = src.indexOf(END_MARKER, startIdx);
if (endIdx === -1) { console.error('loadDeptData bulunamadı'); process.exit(1); }

let before = src.slice(0, startIdx);
let fn     = src.slice(startIdx, endIdx);
let after  = src.slice(endIdx);

// ── Color replacements (light → dark) ────────────────────────────────────────
const replacements = [
  // Panel backgrounds
  [/background:#f7fafc/g,                    'background:rgba(255,255,255,0.06)'],
  [/background:#fff5f5/g,                    'background:rgba(229,62,62,0.12)'],
  [/background:#ebf8ff/g,                    'background:rgba(49,130,206,0.18)'],
  [/background:#f0fff4/g,                    'background:rgba(56,161,105,0.18)'],
  [/background:#fffbeb/g,                    'background:rgba(237,137,54,0.12)'],
  [/background:#edf2f7/g,                    'background:rgba(255,255,255,0.08)'],

  // White inputs/selects
  [/background:#fff(?=[;'"])/g,              'background:rgba(255,255,255,0.08)'],
  [/background:white/g,                      'background:rgba(255,255,255,0.08)'],

  // Borders
  [/border:1px solid #e2e8f0/g,              'border:1px solid rgba(255,255,255,0.12)'],
  [/border:1px solid #cbd5e0/g,              'border:1px solid rgba(255,255,255,0.18)'],
  [/border:1px dashed #cbd5e0/g,             'border:1px dashed rgba(255,255,255,0.15)'],
  [/border:2px solid #e2e8f0/g,             'border-bottom:2px solid rgba(255,255,255,0.15)'],
  [/border-bottom:2px solid #e2e8f0/g,       'border-bottom:2px solid rgba(255,255,255,0.15)'],
  [/border-bottom:1px solid #e2e8f0/g,       'border-bottom:1px solid rgba(255,255,255,0.08)'],
  [/border-bottom:1px solid #f0f4f8/g,       'border-bottom:1px solid rgba(255,255,255,0.06)'],
  [/border:1px solid #bee3f8/g,              'border:1px solid rgba(49,130,206,0.4)'],
  [/border:1px solid #fed7d7/g,              'border:1px solid rgba(229,62,62,0.4)'],
  [/border:1px solid #c6f6d5/g,              'border:1px solid rgba(56,161,105,0.4)'],
  [/border-top:1px solid #e2e8f0/g,          'border-top:1px solid rgba(255,255,255,0.12)'],

  // Text colors (dark → light)
  [/color:#1a1a2e/g,                         'color:#e2e8f0'],
  [/color:#2d3748/g,                         'color:#e2e8f0'],
  [/color:#4a5568/g,                         'color:#94a3b8'],
  [/color:#555(?=[;'"])/g,                   'color:#9ab'],
  [/color:#718096/g,                         'color:#8899aa'],
  [/color:#888(?=[;'"])/g,                   'color:#778'],
  [/color:#999(?=[;'"])/g,                   'color:#667'],
  [/color:#ccc(?=[;'"])/g,                   'color:#445'],
  [/color:#2b6cb0/g,                         'color:#63b3ed'],
  [/color:#276749/g,                         'color:#68d391'],
  [/color:#c53030/g,                         'color:#fc8181'],

  // Input text colors (need to be light on dark bg)
  [/font-size:13px;box-sizing:border-box">/g,
   'font-size:13px;box-sizing:border-box;color:#e2e8f0">'],
  [/font-size:13px;text-align:center">/g,
   'font-size:13px;text-align:center;color:#e2e8f0">'],
  [/font-size:14px;width:200px">/g,
   'font-size:14px;width:200px;color:#e2e8f0">'],
  [/font-size:14px;width:200px\\">/g,
   'font-size:14px;width:200px;color:#e2e8f0\\">'],
];

for (const [pattern, replacement] of replacements) {
  fn = fn.replace(pattern, replacement);
}

// Add marker comment
fn = fn.replace(START, START + '\n    // DARK_THEME_V1');

src = before + fn + after;
writeFileSync(TARGET, src, 'utf8');
console.log('✓ Dark theme uygulandı — loadRakipRoom renkleri güncellendi');
console.log(`  Toplam satır: ${src.split('\n').length}`);
