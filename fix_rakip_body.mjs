#!/usr/bin/env node
/**
 * fix_rakip_body.mjs
 *
 * Problem: POST /api/rakip/izle, PUT /api/rakip/izle/:id and PUT /api/rakip/ayar
 *          all reference `body` which is NOT in scope at their position in handleApi.
 *          Each handler must read its own body from the request stream.
 *          Additionally, no try/catch → any DB error crashes the Node.js process.
 *
 * Fix:
 *   1. Prepend inline body-reading to the 3 handlers that use `body`
 *   2. Wrap each handler's DB work in try/catch → sendJson 500 instead of crash
 *
 * Idempotency: RAKIP_BODY_FIX_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const TARGET = '/opt/krb-assessment/server.mjs';
let src = readFileSync(TARGET, 'utf8');

if (src.includes('// RAKIP_BODY_FIX_V1')) {
  console.log('Zaten uygulandı'); process.exit(0);
}

let changed = 0;

// ── 1. POST /api/rakip/izle ──────────────────────────────────────────────────
// Add body reading + try/catch wrapper
const POST_OLD = `  if (request.method === 'POST' && url.pathname === '/api/rakip/izle') {
    const { marka, ebat, model_pattern, gunluk_cekim = 3, alarm_esigi, aciklama } = body || {};
    if (!marka || !ebat) { sendJson(response, 400, { error: 'marka ve ebat zorunlu' }); return; }
    const _rSess = await requireModuleAccess(request, 'intelligence').catch(()=>null) || await requireModuleAccess(request, 'saha').catch(()=>null); const tid = _rSess?.tenantId || null; if (!tid) { sendJson(response, 401, { error: 'Unauthorized' }); return; }`;

const POST_NEW = `  if (request.method === 'POST' && url.pathname === '/api/rakip/izle') {
    // RAKIP_BODY_FIX_V1
    let body = {}; try { let _r=''; for await (const c of request) _r+=c; body=JSON.parse(_r||'{}'); } catch {}
    const { marka, ebat, model_pattern, gunluk_cekim = 3, alarm_esigi, aciklama } = body || {};
    if (!marka || !ebat) { sendJson(response, 400, { error: 'marka ve ebat zorunlu' }); return; }
    const _rSess = await requireModuleAccess(request, 'intelligence').catch(()=>null) || await requireModuleAccess(request, 'saha').catch(()=>null); const tid = _rSess?.tenantId || null; if (!tid) { sendJson(response, 401, { error: 'Unauthorized' }); return; }`;

if (!src.includes(POST_OLD)) {
  console.error('✗ POST /api/rakip/izle anchor bulunamadı'); process.exit(1);
}
src = src.replace(POST_OLD, POST_NEW);
changed++;
console.log('✓ POST /api/rakip/izle — body okuma eklendi');

// ── 2. PUT /api/rakip/izle/:id ───────────────────────────────────────────────
const PUT_IZLE_OLD = `  if (request.method === 'PUT' && /^\\/api\\/rakip\\/izle\\/\\d+$/.test(url.pathname)) {
    const izleId = parseInt(url.pathname.split('/').pop(), 10);
    const { aktif, gunluk_cekim, alarm_esigi, aciklama, model_pattern } = body || {};`;

const PUT_IZLE_NEW = `  if (request.method === 'PUT' && /^\\/api\\/rakip\\/izle\\/\\d+$/.test(url.pathname)) {
    let body = {}; try { let _r=''; for await (const c of request) _r+=c; body=JSON.parse(_r||'{}'); } catch {}
    const izleId = parseInt(url.pathname.split('/').pop(), 10);
    const { aktif, gunluk_cekim, alarm_esigi, aciklama, model_pattern } = body || {};`;

if (!src.includes(PUT_IZLE_OLD)) {
  console.error('✗ PUT /api/rakip/izle/:id anchor bulunamadı'); process.exit(1);
}
src = src.replace(PUT_IZLE_OLD, PUT_IZLE_NEW);
changed++;
console.log('✓ PUT /api/rakip/izle/:id — body okuma eklendi');

// ── 3. PUT /api/rakip/ayar ───────────────────────────────────────────────────
// Find the ayar PUT handler - search for its signature
const AYAR_ANCHOR = `url.pathname === '/api/rakip/ayar'`;
const ayarPutIdx = src.indexOf(`request.method === 'PUT' && url.pathname === '/api/rakip/ayar'`);
if (ayarPutIdx === -1) {
  console.log('— PUT /api/rakip/ayar bulunamadı, atlanıyor');
} else {
  // Find the first `body` usage in this block and prepend reading
  const blockStart = src.lastIndexOf('\n  if (', ayarPutIdx) + 1;
  const ifLine = src.slice(blockStart, src.indexOf('\n', blockStart + 1));
  // Insert body reading right after the opening `{`
  const openBrace = src.indexOf('{', ayarPutIdx);
  const afterBrace = src.indexOf('\n', openBrace) + 1;
  const bodyReadLine = `    let body = {}; try { let _r=''; for await (const c of request) _r+=c; body=JSON.parse(_r||'{}'); } catch {}\n`;
  // Only add if `body` is used in this handler but not yet declared
  const handlerChunk = src.slice(openBrace, src.indexOf('\n  }', openBrace) + 5);
  if (handlerChunk.includes('body') && !handlerChunk.includes("let body")) {
    src = src.slice(0, afterBrace) + bodyReadLine + src.slice(afterBrace);
    changed++;
    console.log('✓ PUT /api/rakip/ayar — body okuma eklendi');
  } else {
    console.log('— PUT /api/rakip/ayar — body zaten mevcut veya kullanılmıyor');
  }
}

// ── 4. Wrap POST INSERT in try/catch to prevent process crash ────────────────
// Find the INSERT into bi_rakip_izle and wrap it
const INSERT_OLD = `    const { rows } = await pool.query(
      'INSERT INTO bi_rakip_izle' +
      ' (marka,ebat,model_pattern,gunluk_cekim,alarm_esigi,aciklama,tenant_id)' +
      ' VALUES ($1,$2,$3,$4,$5,$6,$7)' +
      ' RETURNING id,marka,ebat,gunluk_cekim,alarm_esigi,aktif',
      [marka, ebat, model_pattern || null, gunluk_cekim, esik, aciklama || null, tid]
    );
    sendJson(response, 200, { row: rows[0] }); return;
  }`;

const INSERT_NEW = `    try {
      const { rows } = await pool.query(
        'INSERT INTO bi_rakip_izle' +
        ' (marka,ebat,model_pattern,gunluk_cekim,alarm_esigi,aciklama,tenant_id)' +
        ' VALUES ($1,$2,$3,$4,$5,$6,$7)' +
        ' RETURNING id,marka,ebat,gunluk_cekim,alarm_esigi,aktif',
        [marka, ebat, model_pattern || null, gunluk_cekim, esik, aciklama || null, tid]
      );
      sendJson(response, 200, { row: rows[0] });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
    return;
  }`;

if (src.includes(INSERT_OLD)) {
  src = src.replace(INSERT_OLD, INSERT_NEW);
  changed++;
  console.log('✓ POST INSERT — try/catch eklendi');
} else {
  console.log('— POST INSERT anchor bulunamadı, try/catch atlandı');
}

writeFileSync(TARGET, src, 'utf8');
console.log(`\n✓ fix_rakip_body.mjs tamamlandı — ${changed} değişiklik, ${src.split('\n').length} satır`);
