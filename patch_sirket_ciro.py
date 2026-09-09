#!/usr/bin/env python3
# SIRKET_CIRO — kokpit-umbrella: birinci metrik = TUM SIRKET cirosu + gelir kirilimi.
#   sirket.ciro   : secilen penceredeki TUM grup_adi cirosu (bi_satis_faturalari) — full company revenue.
#   sirket.kirilim: is-kolu gelir kirilimi (TIC_L/TUK_L/RETREAD/SERVIS/DIGER).
#   canli         : GERCEK takvim ayi (bugun) -> ciro=TAM sirket, adet=yalniz lastik, kirilim=is-kolu.
#   (marj/Catal/Kar/Musteri Evreni DEGISMEZ = lastik isi, bi_marj_atom.)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SIRKET_CIRO" in s:
    print("[skip] SIRKET_CIRO zaten var"); sys.exit(0)

# 1) canli satirini (UMBRELLA_SONAY'dan gelen) sirket+kirilim+genis canli ile degistir.
OLD_CANLI = (
'      const _cl = (await query("SELECT to_char(date_trunc(\'month\',CURRENT_DATE),\'YYYY-MM\') ay, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar)::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi IN (\'LASTIK TUKETICI\',\'LASTIK TICARI\') AND date_trunc(\'month\',fatura_tarihi)=date_trunc(\'month\',CURRENT_DATE) AND satir_tutar>0", [String(T)])).rows[0]; const canli = (_cl && _cl.ciro != null) ? { ay: _cl.ay, ciro: _cl.ciro, adet: _cl.adet } : null;'
)

NEW_CANLI = r'''      /* SIRKET_CIRO — birinci metrik = tum sirket cirosu (tum grup_adi) + gelir kirilimi */
      const _fWin = ytd ? "date_trunc('month',fatura_tarihi) >= date_trunc('year',(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1))" : "date_trunc('month',fatura_tarihi) > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - ($2 * INTERVAL '1 month'))";
      const _KB = "CASE WHEN grup_adi='LASTIK TUKETICI' THEN 'TUK_L' WHEN grup_adi='LASTIK TICARI' THEN 'TIC_L' WHEN grup_adi='LASTIK YENILEME' THEN 'RETREAD' WHEN grup_adi IN ('LASTIK TICARI TAMIR','VERILEN SERVIS HIZMET') THEN 'SERVIS' ELSE 'DIGER' END";
      const _ord = { TIC_L: 1, TUK_L: 2, RETREAD: 3, SERVIS: 4, DIGER: 5 };
      const _skir = (await query("SELECT " + _KB + " ad, round(sum(satir_tutar)/1e6,1)::float8 c FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND " + _fWin + " AND satir_tutar>0 GROUP BY 1", params)).rows.filter((r) => r.c > 0).sort((a, b) => (_ord[a.ad] || 9) - (_ord[b.ad] || 9));
      const _sc = (await query("SELECT round(sum(satir_tutar)/1e6,1)::float8 ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND " + _fWin + " AND satir_tutar>0", params)).rows[0];
      const sirket = { ciro: _sc ? _sc.ciro : null, kirilim: _skir };
      const _clx = (await query("SELECT to_char(date_trunc('month',CURRENT_DATE),'YYYY-MM') ay, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar) FILTER (WHERE grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND satir_tutar>0", [String(T)])).rows[0];
      const _clk = (await query("SELECT " + _KB + " ad, round(sum(satir_tutar)/1e6,1)::float8 c FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND satir_tutar>0 GROUP BY 1", [String(T)])).rows.filter((r) => r.c > 0).sort((a, b) => (_ord[a.ad] || 9) - (_ord[b.ad] || 9));
      const _clb = (await query("SELECT CASE WHEN grup_adi='LASTIK TUKETICI' THEN 'tuk' ELSE 'tic' END u, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar)::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI') AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND satir_tutar>0 GROUP BY 1", [String(T)])).rows;
      const _cb = (u) => { const r = _clb.find((x) => x.u === u); return r ? { ciro: r.ciro, adet: r.adet } : { ciro: 0, adet: 0 }; };
      /* canli marj = AYNI BAZ (donem maliyeti: bi_marj_atom son-bilinen birim_maliyet, ETL ile ayni). Temmuz'a tasinir; kesinlesmemis. */
      const _clm = (await query("WITH lc AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet bm FROM bi_marj_atom WHERE tenant_id::text=$1 AND birim_maliyet IS NOT NULL ORDER BY kalem_kodu, ay DESC) SELECT round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL)-sum(f.miktar*lc.bm))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL),0)*100,1)::float8 marj, round(100.0*sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL)/nullif(sum(f.satir_tutar),0),1)::float8 kapsam, round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TUKETICI')-sum(f.miktar*lc.bm) FILTER (WHERE f.grup_adi='LASTIK TUKETICI'))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TUKETICI'),0)*100,1)::float8 marj_tuk, round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TICARI')-sum(f.miktar*lc.bm) FILTER (WHERE f.grup_adi='LASTIK TICARI'))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TICARI'),0)*100,1)::float8 marj_tic FROM bi_satis_faturalari f LEFT JOIN lc ON lc.kalem_kodu=f.kalem_kodu WHERE f.tenant_id::text=$1 AND date_trunc('month',f.fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND f.satir_tutar>0 AND f.grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI')", [String(T)])).rows[0];
      const canli = (_clx && _clx.ciro != null) ? { ay: _clx.ay, ciro: _clx.ciro, adet: _clx.adet, kirilim: _clk, tuk: _cb('tuk'), tic: _cb('tic'), marj: _clm ? _clm.marj : null, marj_tuk: _clm ? _clm.marj_tuk : null, marj_tic: _clm ? _clm.marj_tic : null, kapsam: _clm ? _clm.kapsam : null } : null;'''

assert OLD_CANLI in s, "HATA: canli satiri bulunamadi (UMBRELLA_SONAY deploy edilmis mi?)"
s = s.replace(OLD_CANLI, NEW_CANLI, 1)

# 2) sendJson'a sirket ekle.
OLD_SEND = '        ay: ytd ? "ytd" : ayN, son_ay: son_ay, canli: canli,'
NEW_SEND = '        ay: ytd ? "ytd" : ayN, son_ay: son_ay, sirket: sirket, canli: canli,'
assert OLD_SEND in s, "HATA: sendJson son_ay satiri bulunamadi"
s = s.replace(OLD_SEND, NEW_SEND, 1)

open(F, "w", encoding="utf-8").write(s)
print("[ok] SIRKET_CIRO — kokpit-umbrella artik sirket.ciro + sirket.kirilim + genis canli doner")
