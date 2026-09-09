#!/usr/bin/env python3
# HAFIZA — CEO Assistant kalici hafiza + kisi profili + beyan/gozlem + davranis madencisi (BIRLESIK, temiz).
#   CANLI server_container.mjs uzerine yazilir. KRITIK DUZELTME: _buildBrainPrompt(tenantId) -> (tenantId, session, _hMsg)
#   cunku govde 'session' (cok-tenant company_profile/tenantName) kullaniyordu; eski yamada session kapsam disi kalip 500 atmisti.
#   Race-safe tablo (pg_type duplicate yut). Idempotent (marker HAFIZA_FULL). node --check + runtime smoke test edildi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "HAFIZA_FULL" in s:
    print("[skip] HAFIZA_FULL zaten var"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# ── E1) TABLO (race-safe) ──
A1 = r"""        await query('CREATE TABLE IF NOT EXISTS brain_notes (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, content TEXT NOT NULL, tags TEXT[] DEFAULT \'{}\', created_at TIMESTAMPTZ DEFAULT NOW())', []);"""
T1 = A1 + r"""
        try { await query("CREATE TABLE IF NOT EXISTS bi_tenant_hafiza (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, user_id UUID, kategori TEXT NOT NULL DEFAULT 'genel', konu TEXT, icerik TEXT NOT NULL, kisi BOOLEAN DEFAULT false, guven REAL DEFAULT 0.7, kaynak TEXT DEFAULT 'damitma', ilk_gorulme TIMESTAMPTZ DEFAULT now(), son_gorulme TIMESTAMPTZ DEFAULT now(), gecerli BOOLEAN DEFAULT true)", []); } catch (e) { if (!/exist|duplicate/i.test((e && e.message) || '')) throw e; } /* HAFIZA_FULL */
        await query("CREATE INDEX IF NOT EXISTS idx_bth_tk ON bi_tenant_hafiza(tenant_id, kategori, son_gorulme DESC)", []).catch(function(){});
        await query("CREATE INDEX IF NOT EXISTS idx_bth_konu ON bi_tenant_hafiza(tenant_id, konu)", []).catch(function(){});
        await query("CREATE INDEX IF NOT EXISTS idx_bth_kisi ON bi_tenant_hafiza(tenant_id, kisi, user_id)", []).catch(function(){});"""
rep(A1, T1, "tablo")

# ── E2) DAMITICI + MADENCI fonksiyonlari (_getBrainWeather'dan once) ──
A2 = "      async function _getBrainWeather(lat, lon) {"
FUNCS = r'''      async function _distillHafiza(tenantId, userId, uMsg, aMsg) { /* HAFIZA_FULL */
        try {
          if (!uMsg || uMsg.length < 15) return;
          if (typeof anthropic === "undefined" || !anthropic) return;
          const SYS = "Sen bir hafiza damiticisisin. Asagidaki TEK konusma turundan (kullanici + asistan) uzun vadeli hatirlanmaya deger KALICI gercekleri cikar.\n" +
            "IKI tur: (A) SIRKET/MUSTERI/KARAR/ORUNTU (or: 'X musterisi kronik gec oder', 'sahip Y markasindan cikmaya karar verdi'). (B) KISI PROFILI — konusanin oncelikleri, iletisim tarzi, beklentileri, tekrarlayan endiseleri (or: 'sabah once nakit/tahsilat sorar', 'kisa ve rakam-onceli cevap sever').\n" +
            "KATI: SADECE KALICI olani al. OYNAK sayi/bakiye/oran/tarih/anlik durum ALMA — canli veriden gelir, hafizaya yazilirsa sonra YALAN olur. Emin degilsen ALMA.\n" +
            "KAYNAK: 'gozlem' = veriden/davranistan gozlenen; 'beyan' = kisinin SOYLEDIGI iddia/tercih (dusuk guven). Insan kandirir; emin degilsen 'beyan'.\n" +
            "Cikti: SADECE JSON dizi (max 3): [{\"kategori\":\"musteri|karar|oruntu|tercih|kisi_profili|oncelik|uslup\",\"konu\":\"kisa ozne\",\"icerik\":\"tek cumle kalici gercek\",\"kisi\":true/false,\"kaynak\":\"beyan|gozlem\"}]. Kalici sey yoksa []. Baska metin yazma.";
          const msg = await anthropic.messages.create({ model: "claude-sonnet-4-6", max_tokens: 760, messages: [{ role: "user", content: SYS + "\n\nKULLANICI: " + uMsg + "\n\nASISTAN: " + aMsg + "\n\nJSON:" }] });
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
            const kyn = (String(it.kaynak || 'beyan').toLowerCase().indexOf('goz') >= 0) ? 'gozlem' : 'beyan';
            const gvn = kyn === 'gozlem' ? 0.9 : 0.55;
            if (ic.length < 6) continue;
            const ex = await query("SELECT id FROM bi_tenant_hafiza WHERE tenant_id=$1 AND icerik=$2 LIMIT 1", [tenantId, ic]);
            if (ex.rows.length) { await query("UPDATE bi_tenant_hafiza SET son_gorulme=now(), gecerli=true WHERE id=$1", [ex.rows[0].id]); }
            else { await query("INSERT INTO bi_tenant_hafiza (tenant_id, user_id, kategori, konu, icerik, kisi, kaynak, guven) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)", [tenantId, kisi ? (userId || null) : null, kat, konu, ic, kisi, kyn, gvn]); }
          }
        } catch (e) { console.error("[hafiza-distill]", e && e.message); }
      }
      async function _madenciUpsert(tenantId, sig, kat, ic) { /* HAFIZA_FULL */
        try {
          const ex = await query("SELECT id, icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND konu=$2 AND kaynak='gozlem' AND gecerli=true LIMIT 1", [tenantId, sig]);
          if (ex.rows.length) {
            if (ex.rows[0].icerik === ic) { await query("UPDATE bi_tenant_hafiza SET son_gorulme=now() WHERE id=$1", [ex.rows[0].id]); return 0; }
            await query("UPDATE bi_tenant_hafiza SET gecerli=false WHERE id=$1", [ex.rows[0].id]);
          }
          await query("INSERT INTO bi_tenant_hafiza (tenant_id, user_id, kategori, konu, icerik, kisi, kaynak, guven) VALUES ($1,NULL,$2,$3,$4,false,'gozlem',0.9)", [tenantId, kat, sig, ic]);
          return 1;
        } catch (e) { return 0; }
      }
      async function _madenciCalistir(tenantId) { /* HAFIZA_FULL — deterministik davranis madencisi */
        let n = 0; const T = String(tenantId);
        try {
          const _odemeSql = "WITH nm AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), ranked AS (SELECT bt.muhatap_kodu kod, bt.son12_suresi sur, bt.son12_gec_orani gec, bt.son12_tutar tut, row_number() OVER (ORDER BY bt.son12_tutar DESC) rn FROM bi_tahsilat bt WHERE bt.tenant_id::text=$1 AND bt.musteri_mi AND bt.son12_tutar>0 AND bt.son12_suresi IS NOT NULL) SELECT r.kod, COALESCE(nm.ad, r.kod) ad, r.sur, r.gec FROM ranked r LEFT JOIN nm ON nm.kod=r.kod WHERE r.rn<=40";
          const pr = (await query(_odemeSql, [T])).rows;
          for (const r of pr) {
            const sur = r.sur == null ? null : Number(r.sur);
            const gec = r.gec == null ? null : Number(r.gec);
            if (sur == null) continue;
            let sinif = null;
            if (sur >= 55 || (gec != null && gec >= 0.45)) sinif = 'kronik yavas/gec odeyen';
            else if (sur <= 18 && (gec == null || gec <= 0.12)) sinif = 'hizli ve disiplinli odeyen';
            if (!sinif) continue;
            n += await _madenciUpsert(tenantId, r.kod + '|odeme', 'musteri', String(r.ad) + ': odeme davranisi — ' + sinif + ' (12 ay gozlem; kesin gun/oran icin canli veriye bak)');
          }
          const _trendSql = "WITH m AS (SELECT musteri_kodu kod, max(musteri_adi) ad, date_trunc('month',fatura_tarihi) ay, sum(satir_tutar) tut FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND fatura_tarihi >= date_trunc('month',CURRENT_DATE) - INTERVAL '6 months' AND fatura_tarihi < date_trunc('month',CURRENT_DATE) AND satir_tutar>0 GROUP BY 1, date_trunc('month',fatura_tarihi)), agg AS (SELECT kod, max(ad) ad, COALESCE(sum(tut) FILTER (WHERE ay >= date_trunc('month',CURRENT_DATE)-INTERVAL '3 months'),0) son3, COALESCE(sum(tut) FILTER (WHERE ay < date_trunc('month',CURRENT_DATE)-INTERVAL '3 months'),0) onceki3, count(DISTINCT ay) aysayi FROM m GROUP BY kod) SELECT kod, ad, son3, onceki3 FROM agg WHERE onceki3 > 0 AND aysayi >= 4 ORDER BY (son3+onceki3) DESC LIMIT 40";
          const tr = (await query(_trendSql, [T])).rows;
          for (const r of tr) {
            const son3 = Number(r.son3 || 0), on3 = Number(r.onceki3 || 0);
            if (on3 <= 0) continue;
            let sinif = null;
            if (son3 < on3 * 0.6) sinif = 'alimini belirgin azaltti (kayip riski)';
            else if (son3 > on3 * 1.5) sinif = 'alimini belirgin artirdi (buyuyen musteri)';
            if (!sinif) continue;
            n += await _madenciUpsert(tenantId, r.kod + '|trend', 'oruntu', String(r.ad) + ': alim trendi — ' + sinif + ' (son 3 ay vs onceki 3 ay gozlem; kesin rakam icin canli veriye bak)');
          }
        } catch (e) { console.error("[madenci]", e && e.message); }
        return n;
      }

'''
rep(A2, FUNCS + A2, "fonksiyonlar")

# ── E3) _buildBrainPrompt imzasi: session (GERCEK) + _hMsg ──
rep("async function _buildBrainPrompt(tenantId) {",
    "async function _buildBrainPrompt(tenantId, session, _hMsg) { /* HAFIZA_FULL */", "imza")

# ── E4) hafizaCtx blok (notesCtx'ten sonra) ──
A4 = r"""          if (r.rows.length) notesCtx = '\n\nHatırlat: ' + r.rows.map(n => n.content).join(' | ');
        } catch {}"""
HAF = A4 + r'''
        let hafizaCtx = '';
        try {
          const _hu = (session && session.userId) || null;
          const _hp = await query("SELECT icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND kisi=true AND (user_id=$2 OR user_id IS NULL) AND gecerli ORDER BY son_gorulme DESC LIMIT 8", [tenantId, _hu]);
          const _hc = await query("SELECT konu, icerik, kaynak FROM bi_tenant_hafiza WHERE tenant_id=$1 AND (kisi IS NOT TRUE) AND gecerli ORDER BY (kaynak='gozlem') DESC, guven DESC, son_gorulme DESC LIMIT 200", [tenantId]);
          const _q = String(_hMsg || '').toLocaleLowerCase('tr');
          const _toks = _q.split(/[^a-zçğıöşü0-9]+/i).filter(w => w.length > 3);
          const _scored = _hc.rows.map(r => { const hay = ((r.konu || '') + ' ' + r.icerik).toLocaleLowerCase('tr'); let sc = 0; for (const t of _toks) if (hay.indexOf(t) >= 0) sc++; return { r, sc }; });
          const _rel = _scored.filter(x => x.sc > 0).sort((a, b) => b.sc - a.sc).slice(0, 10).map(x => x.r);
          const _recent = _hc.rows.slice(0, 5);
          const _seen = new Set(); const _facts = [];
          for (const r of [..._rel, ..._recent]) { if (!_seen.has(r.icerik)) { _seen.add(r.icerik); _facts.push(r); } }
          let _blk = '';
          if (_hp.rows.length) _blk += '\n\nKIM KONUSUYOR (kalici profil — konusanin oncelik/tarz/beklentileri; tonunu buna gore ayarla ama profili YUZE VURMA): ' + _hp.rows.map(r => r.icerik).join(' | ');
          if (_facts.length) _blk += '\n\nTENANT HAFIZASI (1. gunden damitilmis KALICI gercekler — ipucu, SAYI/ANLIK DURUM DEGIL; guncel rakam icin MUTLAKA canli araci cagir; (gozlem)=veriden, (beyan)=soylenen — CELISIRSE gozleme guven, soz-eylem farkini fark et): ' + _facts.slice(0, 12).map(r => '\n- ' + r.icerik + (r.kaynak === 'gozlem' ? ' (gözlem)' : ' (beyan)')).join('');
          hafizaCtx = _blk;
        } catch {}'''
rep(A4, HAF, "hafizaCtx")

# ── E5) return concat: + hafizaCtx ──
rep("+ notesCtx + selfCtx +", "+ notesCtx + hafizaCtx + selfCtx +", "return-concat")

# ── E6) cagri: session + userMsg ──
rep("let systemPrompt = await _buildBrainPrompt(tenantId);",
    "let systemPrompt = await _buildBrainPrompt(tenantId, session, userMsg);", "cagri")

# ── E7) madenci tetik (ensureBrainDb + let body arasi) ──
A7 = "        await _ensureBrainDb();\n        let body;"
rep(A7, "        await _ensureBrainDb();\n        try { const _mk = (globalThis.__madenciLast = globalThis.__madenciLast || new Map()); const _lk = String(session.tenantId); const _nowm = Date.now(); if (!_mk.get(_lk) || (_nowm - _mk.get(_lk)) > 72000000) { _mk.set(_lk, _nowm); _madenciCalistir(session.tenantId).catch(function(){}); } } catch (e) {} /* HAFIZA_FULL */\n        let body;", "madenci-tetik")

# ── E8) damitici tetik (asistan INSERT'ten sonra) ──
A8 = "await query('INSERT INTO brain_conversations (tenant_id, role, content) VALUES ($1,$2,$3)', [tenantId, 'assistant', fullResp.trim()]);"
rep(A8, A8 + "\n          _distillHafiza(tenantId, session.userId, userMsg, fullResp.trim()).catch(function(){}); /* HAFIZA_FULL */", "damitici-tetik")

# ── E9) unut_hafiza + davranis_yenile arac tanimlari (save_note def'ten sonra) ──
SN_DEF = r'''        {
          name: 'save_note',
          description: 'Save an important insight, decision, or piece of information for future context.',
          input_schema: {
            type: 'object',
            properties: {
              content: { type: 'string', description: 'Note content' },
              tags: { type: 'array', items: { type: 'string' }, description: 'Optional tags' }
            },
            required: ['content']
          }
        },'''
NEW_DEFS = SN_DEF + r'''
        {
          name: 'unut_hafiza',
          description: 'Kalici hafizadaki bir bilgiyi GECERSIZ kil (soft-forget). Kullanici "onu unut", "o dogru degil", "beni/durumu yanlis tanidin", "artik gecerli degil" derse cagir. Eslesen kalici gercek(ler) gecerli=false olur.',
          input_schema: { type: 'object', properties: { konu: { type: 'string', description: 'Unutulacak bilginin konusu ya da iceriginden bir ifade' } }, required: ['konu'] }
        },
        {
          name: 'davranis_yenile',
          description: 'Musteri DAVRANIS gozlemlerini (odeme suresi/gec odeme oruntusu, alim trendi) canli veriden yeniden hesaplayip hafizaya gozlem olarak yazar. "davranislari guncelle / kim yavas oduyor / alimi dusen var mi" gibi sorunca cagir. Deterministik, sayi uydurmaz.',
          input_schema: { type: 'object', properties: {} }
        },'''
rep(SN_DEF, NEW_DEFS, "arac-tanimlari")

# ── E10) unut_hafiza + davranis_yenile handler (save_note handler'indan sonra) ──
SN_H = r'''        if (toolName === 'save_note') {
          const { content, tags = [] } = input;
          await query('INSERT INTO brain_notes (tenant_id, content, tags) VALUES ($1,$2,$3)', [tenantId, content, tags]);
          return { success: true, message: 'Not kaydedildi.' };
        }'''
NEW_H = SN_H + r'''
        if (toolName === 'unut_hafiza') { /* HAFIZA_FULL */
          const _uq = String((input && input.konu) || '').trim();
          if (_uq.length < 2) return { success: false, message: 'Ne unutulacak belirtilmedi.' };
          const _ur = await query("UPDATE bi_tenant_hafiza SET gecerli=false WHERE tenant_id=$1 AND gecerli=true AND (icerik ILIKE '%'||$2||'%' OR konu ILIKE '%'||$2||'%') RETURNING id", [tenantId, _uq]);
          return { success: true, message: (_ur.rowCount || 0) + ' kayit unutuldu.' };
        }
        if (toolName === 'davranis_yenile') { /* HAFIZA_FULL */
          const _mn = await _madenciCalistir(tenantId);
          return { success: true, message: _mn + ' davranis gozlemi guncellendi (odeme/alim oruntusu).' };
        }'''
rep(SN_H, NEW_H, "handler")

# ── E11) sistem prompt kural 6: hafiza farkindaligi ──
rep("6. Önemli bilgileri save_note kaydet.",
    '6. Önemli bilgileri save_note kaydet. Kalıcı hafızan var: gozlem (veriden) beyandan (soylenen) guvenilir — celisirse gozleme guven; kullanıcı "unut / yanlis tanidin" derse unut_hafiza cagir.',
    "kural6")

s = s + "\n/* HAFIZA_FULL */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] HAFIZA_FULL — birlesik hafiza (session-fix + race-safe): damitma + hatirlama + beyan/gozlem + madenci + unut")
