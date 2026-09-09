#!/usr/bin/env python3
# OMURGA 20 (#127) — Veri Sağlık alarm UI: 2 endpoint + Veri odası panel.
# Full-text replacement + idempotent + doğrulama. docker cp YOK; build ayrı.
import sys, subprocess

SRV = '/opt/krb-assessment/server_container.mjs'
BIJS = '/opt/krb-assessment/shells/bi.js'

def rd(p):
    with open(p, encoding='utf-8') as f: return f.read()
def wr(p, s):
    with open(p, 'w', encoding='utf-8') as f: f.write(s)

# ───────────────────────── 1. SERVER: iki route ─────────────────────────
ROUTES = r'''
  // ── VERI_SAGLIK_ALARM (#127 omurga_20) — insan kararı: kabul(whitelist)/reddet ──
  if (request.method === 'GET' && url.pathname === '/api/bi/saglik-alarm') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const r = await query(`
        SELECT id, tablo, kolon, deger, adet, tip, tespit_at
          FROM bi_saglik_alarm
         WHERE tenant_id=$1::uuid AND durum='yeni'
         ORDER BY tespit_at DESC, tablo LIMIT 200`, [session.tenantId]);
      sendJson(response, 200, { alarmlar: r.rows });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }

  if (request.method === 'POST' && url.pathname === '/api/bi/saglik-alarm-karar') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const body = await readJson(request);
      if (!body.id || !['kabul','reddet'].includes(body.karar)) {
        sendJson(response, 400, { error: 'id ve karar (kabul|reddet) zorunlu' }); return;
      }
      const a = await query(`SELECT tablo, kolon, deger, tip FROM bi_saglik_alarm
                              WHERE id=$1::uuid AND tenant_id=$2::uuid`,
                            [body.id, session.tenantId]);
      if (!a.rows.length) { sendJson(response, 404, { error: 'alarm bulunamadı' }); return; }
      const row = a.rows[0];
      if (body.karar === 'kabul') {
        // sadece DEĞER-tipi alarm whitelistlenir; olay-tipi (mutabakat/mukerrer/aralik) sadece kapatılır
        if (!['mutabakat','mukerrer','aralik'].includes(row.tip) && row.kolon && row.deger != null) {
          await query(`INSERT INTO bi_bilinen_deger (tenant_id, tablo, kolon, deger)
                        VALUES ($1::uuid,$2,$3,$4) ON CONFLICT DO NOTHING`,
                      [session.tenantId, row.tablo, row.kolon, row.deger]);
        }
        await query(`UPDATE bi_saglik_alarm SET durum='kabul' WHERE id=$1::uuid AND tenant_id=$2::uuid`,
                    [body.id, session.tenantId]);
        sendJson(response, 200, { ok:true, mesaj:'Bilinen kümeye eklendi.' });
      } else {
        await query(`UPDATE bi_saglik_alarm SET durum='reddet' WHERE id=$1::uuid AND tenant_id=$2::uuid`,
                    [body.id, session.tenantId]);
        sendJson(response, 200, { ok:true, mesaj:'Gerçek bozulma olarak işaretlendi.' });
      }
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }

'''
SRV_ANCHOR = '  // ── ANA_API_V1'

s = rd(SRV)
if '/api/bi/saglik-alarm-karar' in s:
    print('  ⏭ server zaten yamalı')
else:
    n = s.count(SRV_ANCHOR)
    if n != 1:
        print(f'  ✗ SERVER anchor {n} kez bulundu (1 bekleniyor) — DURDU'); sys.exit(1)
    s = s.replace(SRV_ANCHOR, ROUTES + SRV_ANCHOR, 1)
    wr(SRV, s)
    print('  ✅ server: 2 route eklendi')

# ───────────────────────── 2. BIJS: placeholder ─────────────────────────
b = rd(BIJS)

E1_OLD = "    let h = '<div class=\"etiket\" style=\"margin-bottom:12px\">ERP DOSYALARI</div>';"
E1_NEW = ("    let h = '<div id=\"veri-alarm\"></div>';\n"
          "    h += '<div class=\"etiket\" style=\"margin-bottom:12px\">ERP DOSYALARI</div>';")

E2_OLD = ("    g.innerHTML = h;\n\n"
          "    const drop = document.getElementById('veri-drop');")
E2_NEW = ("    g.innerHTML = h;\n"
          "    _saglikAlarmCiz();\n\n"
          "    const drop = document.getElementById('veri-drop');")

FUNCS = r'''  async function _saglikAlarmCiz() {
    const box = document.getElementById('veri-alarm');
    if (!box) return;
    let d = { alarmlar: [] };
    try {
      const r = await fetch('/api/bi/saglik-alarm', { credentials:'same-origin' });
      d = await r.json();
    } catch(e) { return; }
    const a = d.alarmlar || [];
    if (!a.length) {
      box.innerHTML = '<div class="kart" style="margin-bottom:20px"><div style="display:flex;justify-content:space-between;align-items:baseline">'
        + '<span class="etiket" style="margin:0">VERİ SAĞLIK</span>'
        + '<span class="n d-yesil" style="font-size:12px">✅ açık alarm yok</span></div></div>';
      return;
    }
    let h = '<div class="kart kart-karar" style="margin-bottom:20px">';
    h += '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:10px">'
       + '<span class="etiket" style="margin:0">⚠ VERİ SAĞLIK — ' + a.length + ' açık alarm</span>'
       + '<span style="font-size:12px;color:var(--tx-2)">tanımadığını sessizce kabul etme</span></div>';
    a.forEach(function(x){
      var tipEt = x.tip==='mukerrer' ? 'mükerrer artışı'
                : x.tip==='mutabakat' ? 'ortalama sıçraması'
                : x.tip==='aralik' ? 'aralık dışı' : 'bilinmeyen değer';
      h += '<div style="padding:10px 0;border-top:0.5px solid var(--cizgi)">'
         + '<div style="display:flex;justify-content:space-between;gap:10px;align-items:baseline">'
         + '<span style="font-size:13px"><b>' + esc(x.tablo) + '</b> · ' + esc(x.kolon||'') + '</span>'
         + '<span class="n d-sari" style="font-size:11px">' + esc(tipEt) + (x.adet?(' · '+Number(x.adet).toLocaleString('tr-TR')+'×'):'') + '</span></div>'
         + '<div style="font-size:13px;color:var(--tx-1);margin:4px 0 8px">' + esc(x.deger||'') + '</div>'
         + '<div style="display:flex;gap:8px">'
         + '<button data-karar="kabul" data-id="' + x.id + '" style="font-size:12px;padding:5px 12px;border-radius:8px;border:0.5px solid var(--cizgi-g);background:var(--zemin-1);color:var(--tx-1);cursor:pointer">Bilinen kümeye ekle</button>'
         + '<button data-karar="reddet" data-id="' + x.id + '" style="font-size:12px;padding:5px 12px;border-radius:8px;border:0.5px solid var(--kirmizi);color:var(--kirmizi);background:transparent;cursor:pointer">Gerçek bozulma</button>'
         + '</div></div>';
    });
    h += '</div>';
    box.innerHTML = h;
    box.querySelectorAll('button[data-karar]').forEach(function(bt){
      bt.onclick = function(){ _saglikKarar(bt.dataset.id, bt.dataset.karar, bt); };
    });
  }

  async function _saglikKarar(id, karar, btn) {
    if (btn) { btn.disabled = true; btn.textContent = '…'; }
    try {
      await fetch('/api/bi/saglik-alarm-karar', {
        method:'POST', credentials:'same-origin',
        headers:{'Content-Type':'application/json'},
        body: JSON.stringify({ id: id, karar: karar })
      });
    } catch(e) {}
    _saglikAlarmCiz();
  }

  async function _yukle(dosya) {'''

FUNCS_ANCHOR = '  async function _yukle(dosya) {'

if 'veri-alarm' in b and '_saglikAlarmCiz' in b:
    print('  ⏭ bi.js zaten yamalı')
else:
    for name, old in [('E1', E1_OLD), ('E2', E2_OLD), ('FUNCS_ANCHOR', FUNCS_ANCHOR)]:
        c = b.count(old)
        if c != 1:
            print(f'  ✗ BIJS {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
    b = b.replace(E1_OLD, E1_NEW, 1)
    b = b.replace(E2_OLD, E2_NEW, 1)
    b = b.replace(FUNCS_ANCHOR, FUNCS, 1)
    wr(BIJS, b)
    print('  ✅ bi.js: placeholder + call + 2 fonksiyon eklendi')

# ───────────────────────── 3. node --check ─────────────────────────
for p in [SRV, BIJS]:
    r = subprocess.run(['node','--check',p], capture_output=True, text=True)
    print(('  ✅ node --check OK: ' if r.returncode==0 else '  ✗ SYNTAX HATA: ')+p)
    if r.returncode!=0:
        print(r.stderr); sys.exit(1)

# ───────────────────────── 4. varlık doğrula ─────────────────────────
s2, b2 = rd(SRV), rd(BIJS)
print('  route GET     :', "/api/bi/saglik-alarm'" in s2)
print('  route POST    :', '/api/bi/saglik-alarm-karar' in s2)
print('  bijs placeholder:', 'id="veri-alarm"' in b2)
print('  bijs call     :', '_saglikAlarmCiz();' in b2)
print('  bijs func     :', 'async function _saglikAlarmCiz' in b2)
print('\n  ✅ YAMA TAMAM — sırada: stamp + docker build + compose up --force-recreate')
