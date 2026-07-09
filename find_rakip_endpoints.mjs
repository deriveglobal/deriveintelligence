import { readFileSync } from 'fs';

const srv = readFileSync('/app/server.mjs', 'utf8');
const bi  = readFileSync('/app/shells/bi.js', 'utf8');

// Find all /api/rakip routes in server
console.log('=== server.mjs — /api/rakip routes ===');
srv.split('\n').forEach((line, i) => {
  if (line.includes('/api/rakip')) console.log(`L${i+1}: ${line.trim()}`);
});

// Find rfPiyasaAra in bi.js + show 100 lines
console.log('\n=== bi.js — rfPiyasaAra function ===');
const biLines = bi.split('\n');
let start = 0;
for (let i = 0; i < biLines.length; i++) {
  if (biLines[i].includes('rfPiyasaAra') && (biLines[i].includes('window.') || biLines[i].includes('async'))) {
    start = i; break;
  }
}
console.log(biLines.slice(start, start + 110).join('\n'));
