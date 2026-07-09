#!/usr/bin/env node
/**
 * fix_rakip_ui.mjs
 * 1. Title color: #e2e8f0 → #ef4444 (red/coral)
 * 2. Ebat column: max-width + title tooltip (no more truncation without hover)
 * 3. Min column: clickable sort header (asc / desc / default toggle)
 * Idempotency: RAKIP_UI_V1 marker
 */
import { readFileSync, writeFileSync } from 'fs';

const BI = '/opt/krb-assessment/shells/bi.js';
let src = readFileSync(BI, 'utf8');

if (src.includes('// RAKIP_UI_V1')) { console.log('Zaten uygulandı'); process.exit(0); }

// ── 1. Title color ────────────────────────────────────────────────────────────
const T_OLD = `<h2 style="margin:0;font-size:22px;font-weight:700;color:#e2e8f0">Rakip Fiyatlar</h2>`;
const T_NEW = `<h2 style="margin:0;font-size:22px;font-weight:700;color:#ef4444">Rakip Fiyatlar</h2>`;
if (!src.includes(T_OLD)) { console.error('✗ title anchor bulunamadı'); process.exit(1); }
src = src.replace(T_OLD, T_NEW);
console.log('✓ Başlık rengi kırmızıya değiştirildi');

// ── 2. Ebat cell — add max-width + title tooltip ──────────────────────────────
const E_OLD = '`<td style="padding:9px 12px;color:#9ab">${g.ebat}</td>`';
const E_NEW = '`<td style="padding:9px 12px;color:#9ab;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${g.ebat}">${g.ebat}</td>`';
if (!src.includes(E_OLD)) { console.error('✗ ebat cell anchor bulunamadı'); process.exit(1); }
src = src.replace(E_OLD, E_NEW);
console.log('✓ Ebat sütunu: max-width + hover tooltip eklendi');

// ── 3. Min sort — add state var before rfPiyasaAra ───────────────────────────
const SORT_STATE = `    let _rfMinSort = 0; // 0=varsayılan 1=artan -1=azalan — RAKIP_UI_V1\n    `;
const FN_ANCHOR = `    window.rfPiyasaAra = async function() {`;
if (!src.includes(FN_ANCHOR)) { console.error('✗ rfPiyasaAra anchor bulunamadı'); process.exit(1); }
src = src.replace(FN_ANCHOR, SORT_STATE + FN_ANCHOR);
console.log('✓ _rfMinSort state değişkeni eklendi');

// ── 3a. Make Min header clickable ─────────────────────────────────────────────
const MH_OLD = `+ '<th style="padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.15);text-align:right">Min</th>'`;
const MH_NEW = `+ \`<th onclick="_rfToggleMinSort()" style="padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.15);text-align:right;cursor:pointer;user-select:none">Min \${_rfMinSort===1?'▲':_rfMinSort===-1?'▼':'⇅'}</th>\``;
if (!src.includes(MH_OLD)) { console.error('✗ Min header anchor bulunamadı'); process.exit(1); }
src = src.replace(MH_OLD, MH_NEW);
console.log('✓ Min sütun başlığı tıklanabilir yapıldı');

// ── 3b. Apply sort to rows after default sort ─────────────────────────────────
const SORT_OLD = `        const rows = Object.values(groups).sort((a,b) => (a.marka+a.ebat).localeCompare(b.marka+b.ebat));`;
const SORT_NEW = `        let rows = Object.values(groups).sort((a,b) => (a.marka+a.ebat).localeCompare(b.marka+b.ebat));
        if (_rfMinSort !== 0) {
          rows.sort((a,b) => {
            const ma = Object.values(a.fiyatlar).filter(Boolean).reduce((m,v)=>v<m?v:m, Infinity);
            const mb = Object.values(b.fiyatlar).filter(Boolean).reduce((m,v)=>v<m?v:m, Infinity);
            return _rfMinSort * (ma - mb);
          });
        }`;
if (!src.includes(SORT_OLD)) { console.error('✗ rows sort anchor bulunamadı'); process.exit(1); }
src = src.replace(SORT_OLD, SORT_NEW);
console.log('✓ Min sıralama mantığı eklendi');

// ── 3c. Add toggle function after rfHizliIzleEkle ────────────────────────────
const TOGGLE_ANCHOR = `    window.rfHizliIzleEkle = async function(marka, ebat) {`;
const TOGGLE_FN = `    window._rfToggleMinSort = function() {
      _rfMinSort = _rfMinSort === 0 ? 1 : _rfMinSort === 1 ? -1 : 0;
      rfPiyasaAra();
    };

    `;
if (!src.includes(TOGGLE_ANCHOR)) { console.error('✗ rfHizliIzleEkle anchor bulunamadı'); process.exit(1); }
src = src.replace(TOGGLE_ANCHOR, TOGGLE_FN + TOGGLE_ANCHOR);
console.log('✓ _rfToggleMinSort fonksiyonu eklendi');

writeFileSync(BI, src, 'utf8');
console.log(`\n✓ fix_rakip_ui.mjs tamamlandı — ${src.split('\n').length} satır`);
