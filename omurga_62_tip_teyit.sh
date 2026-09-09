#!/usr/bin/env bash
# OMURGA 62 — TİP TEYİT: esasen TEDARİKÇİ olanı müşteri domain'inden çıkar (Sailun sızıntısı).
# Ayrım: cari_bakiye'de bize borç var (tedarikci_bakiye<0) AMA onların bize borcu ~0 → müşteri değil.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. SAILUN vs MUTAFLAR cari — ayrımı doğrula (onlar_bize vs biz_onlara)"
$PSQL -c "SELECT left(COALESCE(tedarikci_adi,'?'),28) ad, round(musteri_bakiye/1e6,1) onlar_bize_M, round(tedarikci_bakiye/1e6,1) biz_onlara_M
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND (tedarikci_adi ILIKE '%SAILUN%' OR tedarikci_adi ILIKE '%MUTAFLAR%' OR musteri_kodu IN ('M4115532') );" 2>&1 | sed 's/^/  /'

hr "1. icgoru_uret_musteri — tip teyit (pure-tedarikçi hariç)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION icgoru_uret_musteri(p_tenant uuid) RETURNS int AS $fn$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='musteri' AND durum='yeni';
  WITH r AS (
    SELECT mr.muhatap_kodu kod, mr.muhatap_adi ad, COALESCE(mr.vadesi_gecmis,0) vg
    FROM bi_musteri_risk mr
    WHERE mr.tenant_id=p_tenant AND mr.musteri_mi IS TRUE
      -- TİP TEYİT: esasen tedarikçi (bize borç var, onların bize borcu ~0) → müşteri değil
      AND NOT EXISTS (SELECT 1 FROM bi_cari_bakiye cb WHERE cb.tenant_id=p_tenant
                        AND (cb.tedarikci_kodu=mr.muhatap_kodu OR cb.musteri_kodu=mr.muhatap_kodu)
                        AND COALESCE(cb.tedarikci_bakiye,0) < 0
                        AND COALESCE(cb.musteri_bakiye,0) < 1000000)),
  cb AS (
    SELECT COALESCE(musteri_kodu,tedarikci_kodu) kod,
           COALESCE(musteri_bakiye,0) - COALESCE(CASE WHEN tedarikci_bakiye<0 THEN -tedarikci_bakiye ELSE 0 END,0) net_exp
    FROM bi_cari_bakiye WHERE tenant_id=p_tenant),
  s AS (
    SELECT musteri_kodu kod,
      sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '6 month' AND fatura_tarihi<m0) cs,
      sum(satir_tutar) FILTER (WHERE fatura_tarihi>=m0-interval '12 month' AND fatura_tarihi<m0-interval '6 month') co
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text AND fatura_tarihi>=m0-interval '12 month' GROUP BY musteri_kodu),
  j AS (
    SELECT r.kod, r.ad, r.vg, COALESCE(s.cs,0) cs, COALESCE(s.co,0) co, COALESCE(cb.net_exp, r.vg) net_exp
    FROM r LEFT JOIN s ON s.kod=r.kod LEFT JOIN cb ON cb.kod=r.kod)
  INSERT INTO bi_icgoru (tenant_id,bolum,tip,ozet,kanit,surpriz_skoru,guven,durum)
  SELECT p_tenant,'musteri',
    CASE WHEN co>0 AND cs<co*0.5 THEN 'ciro-dususu' ELSE 'tahsilat-riski' END,
    ad||': '||CASE WHEN co>0 AND cs<co*0.5 THEN 'ciro '||round(co/1e6,1)||'→'||round(cs/1e6,1)||'M' ELSE 'net risk '||round(net_exp/1e6,1)||'M (vadesi geçmiş '||round(vg/1e6,1)||'M)' END,
    jsonb_build_object('kod',kod,'musteri',ad,'ciro_o_m',round(co/1e6,1),'ciro_s_m',round(cs/1e6,1),'vadesi_gecmis_m',round(vg/1e6,1),'net_risk_m',round(net_exp/1e6,1)),
    round(greatest(0,net_exp)/1e6 + greatest(0,(co-cs)/1e6)),
    'yaklasik','yeni'
  FROM j
  WHERE (net_exp > 5000000 AND vg > 1000000) OR (co > 3000000 AND cs < co*0.6);
  SELECT count(*) INTO n FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='musteri' AND durum='yeni';
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ icgoru_uret_musteri (tip teyit)"

hr "2. YENİDEN SEÇ — Sailun düştü mü, Mutaflar kaldı mı"
$PSQL -c "SELECT icgoru_uret_musteri('$T'::uuid) AS secilen;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT tip, ozet FROM bi_icgoru WHERE tenant_id='$T'::uuid AND bolum='musteri' AND durum='yeni' AND (ozet ILIKE '%SAILUN%' OR ozet ILIKE '%MUTAFLAR%');" 2>&1 | sed 's/^/  /'
echo "  → Sailun içeren kalan içgörü sayısı:"
$PSQL -tA -c "SELECT count(*) FROM bi_icgoru WHERE tenant_id='$T'::uuid AND bolum='musteri' AND durum='yeni' AND ozet ILIKE '%SAILUN%';" 2>&1 | sed 's/^/  /'

hr "BITTI — tip teyit uygulandı. Sonra nabiz'i tekrar çalıştır (isim+Sailun temiz)."
