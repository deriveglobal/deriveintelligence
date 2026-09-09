#!/usr/bin/env python3
# HAFIZA_V2 — DAVRANIS MADENCISI. HAFIZA_V15 uzerine biner.
#   Deterministik SQL ile canli veriden (bi_tahsilat odeme davranisi, bi_satis alim trendi)
#   KALICI davranis oruntusu turetir ve hafizaya kaynak='gozlem' (yuksek guven) yazar.
#   Ilke: "insan yalan soyler, davranis soylemez" — gozlem gercekleri LLM'siz, veriden, kandirilamaz.
#   GUARDRAIL: sayi degil KALICI SINIF yazar (kronik gec / hizli / alimi dusen / buyuyen); kesin rakam
#   canli SQL'den. Sinif degisirse eskisini gecersiz kilar (ogrenme). Tenant-scoped (top-40 goreli).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "HAFIZA_V2" in s:
    print("[skip] HAFIZA_V2 zaten var"); sys.exit(0)
if "HAFIZA_V15" not in s:
    print("HATA: once HAFIZA_V15 uygulanmali"); sys.exit(1)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor bulunamadi -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# ── 1) Madenci fonksiyonlari: _getBrainWeather'dan once ──
A1 = "      async function _getBrainWeather(lat, lon) {"
MAD = r'''      async function _madenciUpsert(tenantId, sig, kat, ic) { /* HAFIZA_V2 */
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
      async function _madenciCalistir(tenantId) { /* HAFIZA_V2 — deterministik davranis madencisi */
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
rep(A1, MAD + A1, "madenci-fonksiyonlar")

# ── 2) Otomatik tetik: _handleBrainChat basinda, gunde ~1 kez (fire-and-forget) ──
A2 = "        await _ensureBrainDb();\n        let body;"
TRIG = "        await _ensureBrainDb();\n        try { const _mk = (globalThis.__madenciLast = globalThis.__madenciLast || new Map()); const _lk = String(session.tenantId); const _nowm = Date.now(); if (!_mk.get(_lk) || (_nowm - _mk.get(_lk)) > 72000000) { _mk.set(_lk, _nowm); _madenciCalistir(session.tenantId).catch(function(){}); } } catch (e) {} /* HAFIZA_V2 */\n        let body;"
rep(A2, TRIG, "madenci-tetik")

# ── 3) davranis_yenile arac tanimi (unut_hafiza tanimindan sonra) ──
UNUT_DEF = r'''        {
          name: 'unut_hafiza',
          description: 'Kalici hafizadaki bir bilgiyi GECERSIZ kil (soft-forget, silme degil). Kullanici "onu unut", "o dogru degil", "beni/durumu yanlis tanidin", "bu artik gecerli degil" derse cagir. Eslesen kalici gercek(ler) gecerli=false olur, bir daha baglama girmez.',
          input_schema: {
            type: 'object',
            properties: {
              konu: { type: 'string', description: 'Unutulacak bilginin konusu ya da iceriginden bir ifade (eslestirme icin)' }
            },
            required: ['konu']
          }
        },'''
YENILE_DEF = UNUT_DEF + r'''
        {
          name: 'davranis_yenile',
          description: 'Musteri DAVRANIS gozlemlerini (odeme suresi/gec odeme oruntusu, alim trendi) canli veriden yeniden hesaplayip kalici hafizaya gozlem olarak yazar. Owner "davranislari guncelle / kim yavas oduyor / alimi dusen var mi / gozlemleri tazele" gibi sorunca cagir. Deterministik, veriden turer, sayi uydurmaz.',
          input_schema: { type: 'object', properties: {} }
        },'''
rep(UNUT_DEF, YENILE_DEF, "yenile-arac-tanimi")

# ── 4) davranis_yenile handler (unut_hafiza handler'indan sonra) ──
UNUT_H = r'''        if (toolName === 'unut_hafiza') { /* HAFIZA_V15 */
          const _uq = String((input && input.konu) || '').trim();
          if (_uq.length < 2) return { success: false, message: 'Ne unutulacak belirtilmedi.' };
          const _ur = await query("UPDATE bi_tenant_hafiza SET gecerli=false WHERE tenant_id=$1 AND gecerli=true AND (icerik ILIKE '%'||$2||'%' OR konu ILIKE '%'||$2||'%') RETURNING id", [tenantId, _uq]);
          return { success: true, message: (_ur.rowCount || 0) + ' kayit unutuldu (gecersiz kilindi).' };
        }'''
YENILE_H = UNUT_H + r'''
        if (toolName === 'davranis_yenile') { /* HAFIZA_V2 */
          const _mn = await _madenciCalistir(tenantId);
          return { success: true, message: _mn + ' davranis gozlemi guncellendi (odeme/alim oruntusu, gozlem).' };
        }'''
rep(UNUT_H, YENILE_H, "yenile-handler")

s = s + "\n/* HAFIZA_V2 */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] HAFIZA_V2 — davranis madencisi (odeme + alim trendi -> gozlem) + davranis_yenile araci + gunluk otomatik tetik")
