import { readFileSync } from 'fs';

const src = readFileSync('/app/server.mjs', 'utf8');

// Find the rakip fiyatlar API endpoint
const idx = src.indexOf('/api/rakip/fiyatlar');
if (idx === -1) { console.log('NOT FOUND: /api/rakip/fiyatlar'); process.exit(1); }

// Print 80 lines around it
const lines = src.split('\n');
let foundLine = 0;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('/api/rakip/fiyatlar')) { foundLine = i; break; }
}
console.log(`=== /api/rakip/fiyatlar found at line ${foundLine+1} ===`);
console.log(lines.slice(Math.max(0, foundLine-2), foundLine+80).join('\n'));
