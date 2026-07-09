import { readFileSync } from 'fs';
const src = readFileSync('/app/server.mjs', 'utf8');
const lines = src.split('\n');
// L20188 is the piyasa endpoint — print 50 lines from there
console.log(lines.slice(20187, 20240).join('\n'));
