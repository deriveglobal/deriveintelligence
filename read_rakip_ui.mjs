import { readFileSync } from 'fs';

const src = readFileSync('/app/shells/bi.js', 'utf8');
const lines = src.split('\n');

// Find rfPiyasaAra and the table rendering section
let foundLine = 0;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].includes('rfPiyasaAra') && lines[i].includes('async function')) { foundLine = i; break; }
  if (lines[i].includes('window.rfPiyasaAra')) { foundLine = i; break; }
}
console.log(`=== rfPiyasaAra found at line ${foundLine+1} ===`);
console.log(lines.slice(foundLine, foundLine+120).join('\n'));
