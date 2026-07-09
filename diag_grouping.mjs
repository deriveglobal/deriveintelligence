#!/usr/bin/env node
import { readFileSync } from 'fs';
import { execSync } from 'child_process';

// 1. Syntax check
for (const f of ['/app/server.mjs', '/app/shells/bi.js']) {
  try {
    execSync(`node --check ${f}`, { stdio: 'pipe' });
    console.log(`✓ syntax OK: ${f}`);
  } catch(e) {
    console.log(`✗ SYNTAX ERROR: ${f}`);
    console.log(e.stderr?.toString() || e.message);
  }
}

// 2. Show patched region in bi.js
const bi = readFileSync('/app/shells/bi.js', 'utf8');
const lines = bi.split('\n');
const idx = lines.findIndex(l => l.includes('RAKIP_GROUPING_V1'));
if (idx >= 0) {
  console.log(`\n=== bi.js patch bölgesi (L${idx+1}-${idx+30}) ===`);
  console.log(lines.slice(idx, idx+30).join('\n'));
} else {
  console.log('\n✗ RAKIP_GROUPING_V1 bi.js\'te bulunamadı');
}

// 3. Show saticiPerKaynak cell region
const cellIdx = lines.findIndex(l => l.includes('saticiPerKaynak'));
if (cellIdx >= 0) {
  console.log(`\n=== cell render bölgesi (L${cellIdx+1}-${cellIdx+10}) ===`);
  console.log(lines.slice(cellIdx, cellIdx+10).join('\n'));
}
