#!/usr/bin/env bash
# deploy_kokpit_kanon_v1.sh — Kokpit "bu ay" (canli/_clm) marjini KANONA (v_marj_cari_ay) bagla.
#   _clm : carry-forward son-birim_maliyet + grup_adi 2-grup  ->  v_marj_cari_ay (akis) + catal=kategori_segment
#   _clb : catal cirosu grup_adi -> kategori_segment (retread ticaride)
#   _clx : adet grup_adi 2-grup -> LASTIK% (retread dahil)
#   _clk : DOKUNULMADI (kirilim retread'i ayri gosteriyor)
# ONKOSUL: v_marj_cari_ay v3 CANLI (grup_adi LIKE 'LASTIK%', catal kolonu var).
# SUNUCUDA:  cd /opt/krb-assessment && bash deploy_kokpit_kanon_v1.sh
# node --check + canli DB-hakikat + COKME testi + OTOMATIK ROLLBACK. Yedek: server_container.mjs.bak_kokkanon_<ts>
# NOT: server_container.mjs PAYLASILAN — paralel deploy AKISTA OLMADIGINI dogrula.
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

echo "== [0] onkosul: v_marj_cari_ay + catal kolonu =="
CK=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM information_schema.columns WHERE table_name='v_marj_cari_ay' AND column_name='catal';")
if [ "$CK" != "1" ]; then echo "  !!! v_marj_cari_ay.catal YOK — once kanon_cari_ay_view_v3.sql calistir. DURDU."; exit 1; fi
echo "  v_marj_cari_ay.catal: var"

echo "== [1] server yedegi =="
cp server_container.mjs "server_container.mjs.bak_kokkanon_$TS"
echo "  yedek: server_container.mjs.bak_kokkanon_$TS"

echo "== [2] patch yaz + uygula =="
cat > /opt/krb-assessment/_patch_kokpit_kanon.py <<'PY_EOF'
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
PY_EOF
python3 /opt/krb-assessment/_patch_kokpit_kanon.py || { echo "patch DURDU — rollback"; cp "server_container.mjs.bak_kokkanon_$TS" server_container.mjs; exit 1; }

echo "== [3] node --check =="
if node --check server_container.mjs; then echo "  server OK"; else echo "  FAIL — rollback"; cp "server_container.mjs.bak_kokkanon_$TS" server_container.mjs; exit 1; fi
echo "  marker: $(grep -c KOKPIT_KANON_BUAY_V1 server_container.mjs) · v_marj_cari_ay ref: $(grep -c v_marj_cari_ay server_container.mjs) · eski carry-forward _clm kalinti (0 olmali): $(grep -c "lc AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet bm FROM bi_marj_atom" server_container.mjs)"

echo "== [4] build + restart =="
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment

echo "== [5] container dogrula =="
echo "  container: $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
echo "  srv marker: $(docker exec krb-assessment grep -c KOKPIT_KANON_BUAY_V1 /app/server.mjs)"

echo "== [6] canli DB-hakikat — kokpit _clm ARTIK v_marj_cari_ay okuyor; kanon degerleri =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "WITH v AS (SELECT catal, ciro, brut_kar FROM v_marj_cari_ay WHERE tenant_id='$T'::uuid) SELECT round(100*sum(brut_kar)/nullif(sum(ciro),0),1) genel_marj, round(100*sum(brut_kar) FILTER (WHERE catal='TUK')/nullif(sum(ciro) FILTER (WHERE catal='TUK'),0),1) tuk_marj, round(100*sum(brut_kar) FILTER (WHERE catal='TIC')/nullif(sum(ciro) FILTER (WHERE catal='TIC'),0),1) tic_marj, round(sum(ciro)/1e6,1) lastik_ciro_M FROM v;"
echo "  (beklenen: genel ~%7,1 · tuk ~%18,3 · tic ~%1,7 — finans 'bu ay' ile birebir)"

echo "== [7] COKME kontrolu (ERR_HTTP_HEADERS_SENT — 0 bekle) =="
HS=$(docker logs --since 90s krb-assessment 2>&1 | grep -c ERR_HTTP_HEADERS_SENT || true)
echo "  ERR_HTTP_HEADERS_SENT: $HS · container: $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
if [ "$HS" != "0" ]; then echo "  !!! COKME — OTOMATIK ROLLBACK !!!"; cp "server_container.mjs.bak_kokkanon_$TS" server_container.mjs; docker build -t krb-assessment:secure . >/dev/null 2>&1 && docker compose up -d --force-recreate krb-assessment; echo "geri alindi"; exit 1; fi

echo "== [8] fingerprint =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL_EOF'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'KOKPIT_KANON_BUAY_V1',
 'Kokpit cari-ay (canli/_clm) marji KANONA baglandi: v_marj_cari_ay (akis maliyeti) okuyor; catal=kategori_segment (retread TICARIDE). _clb catal cirosu + _clx adet de kategori_segment/LASTIK% ye cekildi. Eski carry-forward (bi_marj_atom DISTINCT ON son birim_maliyet, grup_adi 2-grup, retread DUSUYORDU) kaldirildi.',
 'Kokpit bu-ay marji finanstan farkli+yuksek gosteriyordu (retread dusurup %9,4; eski maliyet yontemi). Kanon: bu ay genel %7,1 / tuketici %18,3 / ticari %1,7 (retread dahil) — finansla birebir.',
 '{"marker":"KOKPIT_KANON_BUAY_V1","yuzey":"kokpit umbrella canli/_clm","kaynak":"v_marj_cari_ay","catal":"kategori_segment(PSR=TUK)","evren":"grup_adi LIKE LASTIK% (retread dahil)","onceki":"carry-forward son birim_maliyet + grup_adi 2-grup (retread haric)","dogrulama":{"genel":"7.1","tuk":"18.3","tic":"1.7"}}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='KOKPIT_KANON_BUAY_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'kokpit_buay_marj','uc','Kokpit cari-ay (bu ay) marji — canli/_clm. Finansla ayni kaynaktan.','v_marj_cari_ay (akis maliyeti); catal=kategori_segment; evren grup_adi LIKE LASTIK% (retread dahil)','kokpit','canli','kanitli','{"marker":"KOKPIT_KANON_BUAY_V1"}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='kokpit_buay_marj');
SQL_EOF
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT adim FROM bi_insa_gunlugu WHERE adim='KOKPIT_KANON_BUAY_V1'; SELECT ad,durum FROM bi_yetenek WHERE ad='kokpit_buay_marj';"
echo "== BITTI — Kokpit bu-ay KANON (v_marj_cari_ay) · finansla birebir =="
