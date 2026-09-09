import sys
F="/opt/krb-assessment/server_container.mjs"; MARK="KOKPIT_KANON_BUAY_V1"
s=open(F,encoding="utf-8").read()
if MARK in s:
    print("[kok-kanon] ZATEN YAMALI — atlaniyor"); sys.exit(0)

# --- 1) _clx.adet: retread dahil (LASTIK%) — to_char oneki ile _clx'e ozgu (benzersiz) ---
old_adet="to_char(date_trunc('month',CURRENT_DATE),'YYYY-MM') ay, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar) FILTER (WHERE grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))::int adet"
new_adet="to_char(date_trunc('month',CURRENT_DATE),'YYYY-MM') ay, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar) FILTER (WHERE grup_adi LIKE 'LASTIK%')::int adet"

# --- 2) _clb: catal = kategori_segment, evren = LASTIK% (retread ticaride) ---
old_clb="SELECT CASE WHEN grup_adi='LASTIK TUKETICI' THEN 'tuk' ELSE 'tic' END u, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar)::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI') AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND satir_tutar>0 GROUP BY 1"
new_clb="SELECT CASE WHEN kategori_segment(kategori)='PSR' THEN 'tuk' ELSE 'tic' END u, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar)::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND satir_tutar>0 GROUP BY 1"

# --- 3) _clm yorumu: kanon isareti ---
old_cmt="/* canli marj = AYNI BAZ (donem maliyeti: bi_marj_atom son-bilinen birim_maliyet, ETL ile ayni). Temmuz'a tasinir; kesinlesmemis. */"
new_cmt="/* KOKPIT_KANON_BUAY_V1: canli marj = KANON v_marj_cari_ay (akis maliyeti, catal=kategori_segment, retread dahil). Finans ile birebir. */"

# --- 4) _clm sorgusu: carry-forward -> v_marj_cari_ay ---
old_clm="WITH lc AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet bm FROM bi_marj_atom WHERE tenant_id::text=$1 AND birim_maliyet IS NOT NULL ORDER BY kalem_kodu, ay DESC) SELECT round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL)-sum(f.miktar*lc.bm))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL),0)*100,1)::float8 marj, round(100.0*sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL)/nullif(sum(f.satir_tutar),0),1)::float8 kapsam, round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TUKETICI')-sum(f.miktar*lc.bm) FILTER (WHERE f.grup_adi='LASTIK TUKETICI'))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TUKETICI'),0)*100,1)::float8 marj_tuk, round((sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TICARI')-sum(f.miktar*lc.bm) FILTER (WHERE f.grup_adi='LASTIK TICARI'))/nullif(sum(f.satir_tutar) FILTER (WHERE lc.bm IS NOT NULL AND f.grup_adi='LASTIK TICARI'),0)*100,1)::float8 marj_tic FROM bi_satis_faturalari f LEFT JOIN lc ON lc.kalem_kodu=f.kalem_kodu WHERE f.tenant_id::text=$1 AND date_trunc('month',f.fatura_tarihi)=date_trunc('month',CURRENT_DATE) AND f.satir_tutar>0 AND f.grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI')"
new_clm="WITH v AS (SELECT catal, ciro, brut_kar FROM v_marj_cari_ay WHERE tenant_id=$1::uuid), t AS (SELECT sum(satir_tutar) ct FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND satir_tutar>0 AND date_trunc('month',fatura_tarihi)=date_trunc('month',CURRENT_DATE)) SELECT round(100*sum(brut_kar)/nullif(sum(ciro),0),1)::float8 marj, round(100.0*sum(ciro)/nullif((SELECT ct FROM t),0),1)::float8 kapsam, round(100*sum(brut_kar) FILTER (WHERE catal='TUK')/nullif(sum(ciro) FILTER (WHERE catal='TUK'),0),1)::float8 marj_tuk, round(100*sum(brut_kar) FILTER (WHERE catal='TIC')/nullif(sum(ciro) FILTER (WHERE catal='TIC'),0),1)::float8 marj_tic FROM v"

reps=[("_clx.adet",old_adet,new_adet),("_clb",old_clb,new_clb),("_clm.yorum",old_cmt,new_cmt),("_clm.sorgu",old_clm,new_clm)]
for ad,o,n in reps:
    c=s.count(o)
    if c!=1:
        print("[kok-kanon] %s eslesme=%d (1 olmali) — DURDU, dokunulmadi"%(ad,c)); sys.exit(2)
for ad,o,n in reps:
    s=s.replace(o,n,1)
open(F,"w",encoding="utf-8").write(s)
print("[kok-kanon] OK — _clx.adet + _clb + _clm(yorum+sorgu) kanona baglandi (marker eklendi)")
