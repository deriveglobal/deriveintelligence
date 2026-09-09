#!/usr/bin/env python3
# HAFIZA_V1 — CEO Assistant (ana beyin) icin "1. gunden unutmayan" kalici hafiza + kisi profili.
#   Yeni tablo bi_tenant_hafiza (tenant-scoped): sirket gercegi (musteri/karar/oruntu) + kisi profili
#   (oncelik/uslup/beklenti). Her turdan sonra OTOMATIK damitma (sonnet, KATI: sadece kalici gercek,
#   OYNAK SAYI YOK). Sistem promptuna ALAKA bazli hatirlama enjekte (recency-30 sinirini asar).
#   GUARDRAIL (GECMIS_ZEHRI dersi): hafiza IPUCU; canli veriyi EZMEZ, oynak durum/sayi tutmaz.
#   Multi-tenant: bi_tenant_hafiza tenant-scoped (KRB gercekleri per-tenant); global defter degil.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "HAFIZA_V1" in s:
    print("[skip] HAFIZA_V1 zaten var"); sys.exit(0)

# ── 1) TABLO: _ensureBrainDb icinde brain_notes CREATE'inden sonra ──
A1 = "await query('CREATE TABLE IF NOT EXISTS brain_notes (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, content TEXT NOT NULL, tags TEXT[] DEFAULT \\'{}\\' , created_at TIMESTAMPTZ DEFAULT NOW())', []);"
# gercek dosyadaki tam string (bosluksuz {}):
A1 = "await query('CREATE TABLE IF NOT EXISTS brain_notes (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, content TEXT NOT NULL, tags TEXT[] DEFAULT \\'{}\\', created_at TIMESTAMPTZ DEFAULT NOW())', []);"
T1 = A1 + "\n" + "\n".join([
  "        await query(\"CREATE TABLE IF NOT EXISTS bi_tenant_hafiza (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, user_id UUID, kategori TEXT NOT NULL DEFAULT 'genel', konu TEXT, icerik TEXT NOT NULL, kisi BOOLEAN DEFAULT false, guven REAL DEFAULT 0.7, kaynak TEXT DEFAULT 'damitma', ilk_gorulme TIMESTAMPTZ DEFAULT now(), son_gorulme TIMESTAMPTZ DEFAULT now(), gecerli BOOLEAN DEFAULT true)\", []); /* HAFIZA_V1 */",
  "        await query(\"CREATE INDEX IF NOT EXISTS idx_bth_tk ON bi_tenant_hafiza(tenant_id, kategori, son_gorulme DESC)\", []);",
  "        await query(\"CREATE INDEX IF NOT EXISTS idx_bth_konu ON bi_tenant_hafiza(tenant_id, konu)\", []);",
  "        await query(\"CREATE INDEX IF NOT EXISTS idx_bth_kisi ON bi_tenant_hafiza(tenant_id, kisi, user_id)\", []);",
])
assert A1 in s, "HATA: brain_notes CREATE anchor bulunamadi"
assert s.count(A1) == 1, "HATA: brain_notes anchor tek degil (%d)" % s.count(A1)
s = s.replace(A1, T1, 1)

# ── 2) DAMITICI fonksiyon: _getBrainWeather'dan once ekle (ayni closure) ──
A2 = "      async function _getBrainWeather(lat, lon) {"
DIST = r'''      async function _distillHafiza(tenantId, userId, uMsg, aMsg) { /* HAFIZA_V1 */
        try {
          if (!uMsg || uMsg.length < 15) return;
          if (typeof anthropic === "undefined" || !anthropic) return;
          const SYS = "Sen bir hafiza damiticisisin. Asagidaki TEK konusma turundan (kullanici + asistan) uzun vadeli hatirlanmaya deger KALICI gercekleri cikar.\n" +
            "IKI tur: (A) SIRKET/MUSTERI/KARAR/ORUNTU — is hakkinda kalici gercek (or: 'X musterisi kronik gec oder', 'sahip Y markasindan cikmaya karar verdi'). (B) KISI PROFILI — konusanin oncelikleri, iletisim tarzi, beklentileri, tekrarlayan endiseleri (or: 'sabah once nakit/tahsilat sorar', 'kisa ve rakam-onceli cevap sever', 'tahsilat konusunda gergin').\n" +
            "KATI KURAL: SADECE KALICI olani al. OYNAK sayi/bakiye/oran/tarih/anlik durum ALMA — bunlar canli veriden gelir, hafizaya yazilirsa sonra YALAN olur. Emin degilsen ALMA, bos don.\n" +
            "Cikti: SADECE JSON dizi (max 3 oge): [{\"kategori\":\"musteri|karar|oruntu|tercih|kisi_profili|oncelik|uslup\",\"konu\":\"kisa ozne anahtari\",\"icerik\":\"tek cumle kalici gercek\",\"kisi\":true veya false}]. Kalici hicbir sey yoksa []. Baska hicbir metin yazma.";
          const msg = await anthropic.messages.create({ model: "claude-sonnet-4-6", max_tokens: 400, messages: [{ role: "user", content: SYS + "\n\nKULLANICI: " + uMsg + "\n\nASISTAN: " + aMsg + "\n\nJSON:" }] });
          let txt = ((msg.content && msg.content[0] && msg.content[0].text) || "").trim();
          const a = txt.indexOf("["), b = txt.lastIndexOf("]");
          if (a < 0 || b < a) return;
          let arr; try { arr = JSON.parse(txt.slice(a, b + 1)); } catch (e) { return; }
          if (!Array.isArray(arr)) return;
          for (const it of arr.slice(0, 3)) {
            const kat = String(it.kategori || "genel").slice(0, 32);
            const konu = it.konu ? String(it.konu).slice(0, 120) : null;
            const ic = String(it.icerik || "").trim().slice(0, 400);
            const kisi = !!it.kisi;
            if (ic.length < 6) continue;
            const ex = await query("SELECT id FROM bi_tenant_hafiza WHERE tenant_id=$1 AND icerik=$2 LIMIT 1", [tenantId, ic]);
            if (ex.rows.length) { await query("UPDATE bi_tenant_hafiza SET son_gorulme=now(), gecerli=true WHERE id=$1", [ex.rows[0].id]); }
            else { await query("INSERT INTO bi_tenant_hafiza (tenant_id, user_id, kategori, konu, icerik, kisi, kaynak) VALUES ($1,$2,$3,$4,$5,$6,'damitma')", [tenantId, kisi ? (userId || null) : null, kat, konu, ic, kisi]); }
          }
        } catch (e) { console.error("[hafiza-distill]", e && e.message); }
      }

'''
assert A2 in s, "HATA: _getBrainWeather anchor bulunamadi"
assert s.count(A2) == 1, "HATA: _getBrainWeather anchor tek degil (%d)" % s.count(A2)
s = s.replace(A2, DIST + A2, 1)

# ── 3) _buildBrainPrompt imzasi: userId + userMsg parametreleri ──
A3 = "async function _buildBrainPrompt(tenantId) {"
assert A3 in s and s.count(A3) == 1, "HATA: _buildBrainPrompt imza anchor sorunu"
s = s.replace(A3, "async function _buildBrainPrompt(tenantId, _hUser, _hMsg) { /* HAFIZA_V1 */", 1)

# ── 4) HATIRLAMA blogu: notesCtx try/catch'inden sonra ──
A4 = "          if (r.rows.length) notesCtx = '\\n\\nHatırlat: ' + r.rows.map(n => n.content).join(' | ');\n        } catch {}"
HAF = A4 + r'''
        let hafizaCtx = '';
        try {
          const _hp = await query("SELECT icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND kisi=true AND (user_id=$2 OR user_id IS NULL) AND gecerli ORDER BY son_gorulme DESC LIMIT 8", [tenantId, _hUser || null]);
          const _hc = await query("SELECT konu, icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND (kisi IS NOT TRUE) AND gecerli ORDER BY son_gorulme DESC LIMIT 200", [tenantId]);
          const _q = String(_hMsg || '').toLocaleLowerCase('tr');
          const _toks = _q.split(/[^a-zçğıöşü0-9]+/i).filter(w => w.length > 3);
          const _scored = _hc.rows.map(r => { const hay = ((r.konu || '') + ' ' + r.icerik).toLocaleLowerCase('tr'); let sc = 0; for (const t of _toks) if (hay.indexOf(t) >= 0) sc++; return { r, sc }; });
          const _rel = _scored.filter(x => x.sc > 0).sort((a, b) => b.sc - a.sc).slice(0, 10).map(x => x.r);
          const _recent = _hc.rows.slice(0, 5);
          const _seen = new Set(); const _facts = [];
          for (const r of [..._rel, ..._recent]) { if (!_seen.has(r.icerik)) { _seen.add(r.icerik); _facts.push(r); } }
          let _blk = '';
          if (_hp.rows.length) _blk += '\n\nKIM KONUSUYOR (kalici profil — konusanin oncelik/tarz/beklentileri; tonunu ve proaktifligini buna gore ayarla ama profili YUZE VURMA, dogal davran): ' + _hp.rows.map(r => r.icerik).join(' | ');
          if (_facts.length) _blk += '\n\nTENANT HAFIZASI (1. gunden damitilmis KALICI gercekler — ipucu, SAYI/ANLIK DURUM DEGIL; guncel rakam/durum icin MUTLAKA canli araci cagir, hafizayi canli verinin YERINE koyma): ' + _facts.slice(0, 12).map(r => '\n- ' + r.icerik).join('');
          hafizaCtx = _blk;
        } catch {}'''
assert A4 in s and s.count(A4) == 1, "HATA: notesCtx anchor sorunu (%d)" % s.count(A4)
s = s.replace(A4, HAF, 1)

# ── 5) return string'e + hafizaCtx enjekte (notesCtx + selfCtx arasi) ──
A5 = "+ notesCtx + selfCtx +"
assert A5 in s and s.count(A5) == 1, "HATA: return notesCtx+selfCtx anchor sorunu (%d)" % s.count(A5)
s = s.replace(A5, "+ notesCtx + hafizaCtx + selfCtx +", 1)

# ── 6) _buildBrainPrompt cagrisi: userId + userMsg gecir ──
A6 = "let systemPrompt = await _buildBrainPrompt(tenantId);"
assert A6 in s and s.count(A6) == 1, "HATA: _buildBrainPrompt cagri anchor sorunu"
s = s.replace(A6, "let systemPrompt = await _buildBrainPrompt(tenantId, session.userId, userMsg);", 1)

# ── 7) DAMITICI cagrisi: asistan cevabi kaydedildikten sonra (fire-and-forget) ──
A7 = "await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'assistant', fullResp.trim()]);"
assert A7 in s and s.count(A7) == 1, "HATA: assistant INSERT anchor sorunu"
s = s.replace(A7, A7 + "\n            _distillHafiza(tenantId, session.userId, userMsg, fullResp.trim()).catch(function(){}); /* HAFIZA_V1 */", 1)

s = s + "\n/* HAFIZA_V1 */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] HAFIZA_V1 — bi_tenant_hafiza + otomatik damitma + alaka bazli hatirlama + kisi profili (ana beyin)")
