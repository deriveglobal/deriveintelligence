#!/usr/bin/env bash
# SINYAL_V1 — bi_sinyal + puanlama + 7 monitor.
#
# ⚠ NEDEN: ana sayfa SABIT panellerle kurulursa 2 AY SONRA OLU EKRAN olur.
#   Temmuz'da kis siparisi 1 numara; Eylul'de sevk; Kasim'da odeme;
#   Kasim-Aralik'ta YAZ on siparis penceresi acilir. Icerigi TASARIM degil
#   VERI belirlemeli.
#
# YAPI:
#   MONITOR'ler aday sinyal uretir -> bi_sinyal'e yazilir -> PUANLANIR -> ilk 3 gosterilir.
#   puan = para etkisi x aciliyet x eyleme donusturulebilirlik
#     para    : log olcek (82M kredi riski, 2.240 adetlik sevk gecikmesinden agir basar)
#     aciliyet: son_tarih'e kalan gun. Pencere kapaninca SIFIRLANIR ve ekrandan DUSER.
#     eylem   : Fatih Bilen bugun bir sey yapabilir mi? Yapamiyorsa gostermenin anlami yok.
#
# ⚠ SABIT GOSTERGELER (hic dusmez): ciro · bagli sermaye · nakit dongusu ·
#   gecikmis alacak · marj (BRUT etiketiyle — prim haric, tesvik eksik)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_sinyal (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  olusma      timestamptz NOT NULL DEFAULT now(),
  -- ⚠ ANAHTAR: ayni sinyal tekrar uretilirse GUNCELLENIR, cogalmaz
  anahtar     text NOT NULL,
  tur         text NOT NULL,        -- sevk_gecikme | kredi_asimi | odeme | pencere | tukenme | olu_stok | veri_bayat
  baslik      text NOT NULL,
  ozet        text,
  tutar_tl    numeric(16,2),        -- para etkisi
  son_tarih   date,                 -- aciliyet. NULL -> surekli
  oda         text,                 -- tiklaninca hangi odaya gider
  eylem_var   boolean NOT NULL DEFAULT true,
  detay       jsonb,
  durum       text NOT NULL DEFAULT 'acik',   -- acik | kapandi | ertelendi
  kapanma     timestamptz,
  UNIQUE (tenant_id, anahtar)
);
CREATE INDEX IF NOT EXISTS idx_sinyal_acik ON bi_sinyal (tenant_id, durum) WHERE durum='acik';

-- ⚠ PUAN: para x aciliyet x eylem. Pencere kapaninca aciliyet 0 -> sinyal DUSER.
CREATE OR REPLACE FUNCTION bi_sinyal_puan(
  p_tutar numeric, p_son_tarih date, p_eylem boolean
) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT ROUND((
      -- PARA: log olcek. 1M -> 0,67 · 100M -> 0,89 · 1B -> 1,0
      0.50 * LEAST(1.0, ln(GREATEST(COALESCE(p_tutar,0),1)) / ln(1e9))
      -- ACILIYET: 90 gun kala 0, bugun 1. Tarih gectiyse 0 -> DUSER.
    + 0.35 * CASE
        WHEN p_son_tarih IS NULL THEN 0.30
        WHEN p_son_tarih < CURRENT_DATE THEN 0.0
        ELSE GREATEST(0, 1 - (p_son_tarih - CURRENT_DATE)::numeric / 90)
      END
      -- EYLEM: yapilamiyorsa yarim puan
    + 0.15 * CASE WHEN p_eylem THEN 1.0 ELSE 0.4 END
  ) * 100, 1)
$$;
SQL
echo "  ✅ tablo + puanlama fonksiyonu"

echo
echo "############ 2) MONITORLER — aday sinyaller ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
-- Once mevcut acik sinyalleri 'yeniden hesaplanacak' diye isaretle
UPDATE bi_sinyal SET durum='kapandi', kapanma=now()
 WHERE tenant_id='$TEN' AND durum='acik';

-- ═══ M1: SEVK GECIKMESI ═══
INSERT INTO bi_sinyal (tenant_id, anahtar, tur, baslik, ozet, tutar_tl, son_tarih, oda, detay)
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         regexp_replace(upper(ebat),'\s+','','g') AS ebat, upper(marka) AS marka
    FROM bi_satis_faturalari WHERE tenant_id='$TEN' AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC),
sp AS (
  SELECT upper(marka) m, regexp_replace(upper(ebat),'\s+','','g') e, SUM(adet) tp
    FROM bi_on_siparis WHERE tenant_id='$TEN' AND sezon_yili='2026-27' AND sezon='KIS'
   GROUP BY 1,2 HAVING SUM(adet) >= 500),
sv AS (
  SELECT ke.marka m, ke.ebat e, SUM(h.giris) g
    FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu=h.kalem_kodu
   WHERE h.tenant_id='$TEN'::uuid AND h.sevk_girisi_mi AND h.lastik_mi
     AND h.belge_tarihi >= DATE '2026-06-01' GROUP BY 1,2),
mal AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric mm
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
eb AS (
  SELECT regexp_replace(upper(f.ebat),'\s+','','g') e, AVG(mal.mm) mm
    FROM bi_satis_faturalari f JOIN mal ON mal.kalem_kodu=f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.ebat<>'' GROUP BY 1)
SELECT '$TEN', 'sevk:'||sp.m||':'||sp.e, 'sevk_gecikme',
       sp.m||' '||sp.e||' — sevkiyat '||
         CASE WHEN COALESCE(sv.g,0)=0 THEN 'hiç başlamamış' ELSE 'geride' END,
       sp.tp||' adet sipariş · '||COALESCE(round(sv.g),0)||' geldi (%'||
         round(100.0*COALESCE(sv.g,0)/sp.tp)||') · sezona '||
         (DATE '2026-10-01' - CURRENT_DATE)||' gün',
       round((sp.tp - COALESCE(sv.g,0)) * COALESCE(eb.mm,3000)),
       DATE '2026-10-01', 'sezon',
       jsonb_build_object('marka',sp.m,'ebat',sp.e,'siparis',sp.tp,'gelen',COALESCE(round(sv.g),0))
  FROM sp LEFT JOIN sv ON sv.m=sp.m AND sv.e=sp.e LEFT JOIN eb ON eb.e=sp.e
 WHERE COALESCE(sv.g,0) < sp.tp * 0.25
ON CONFLICT (tenant_id, anahtar) DO UPDATE SET
  durum='acik', olusma=now(), baslik=EXCLUDED.baslik, ozet=EXCLUDED.ozet,
  tutar_tl=EXCLUDED.tutar_tl, son_tarih=EXCLUDED.son_tarih, detay=EXCLUDED.detay, kapanma=NULL;

-- ═══ M2: KREDI ASIMI (sevkiyat sonrasi) ═══
INSERT INTO bi_sinyal (tenant_id, anahtar, tur, baslik, ozet, tutar_tl, son_tarih, oda, detay)
WITH os AS (
  SELECT alici, SUM(adet)::int adet FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='2026-27' AND alici<>'KRB' GROUP BY 1),
fy AS (
  SELECT CASE WHEN musteri_adi ILIKE '%MUTAFLAR%' THEN 'MUTAFLAR'
              WHEN musteri_adi ILIKE '%YEDİ OTO%' OR musteri_adi ILIKE '%YEDI OTO%' THEN 'YEDI_OTO'
              WHEN musteri_adi ILIKE '%BAR OTO%' THEN 'BAR_OTO' END a,
         SUM(satir_tutar)/NULLIF(SUM(miktar),0) birim
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0
     AND fatura_tarihi >= CURRENT_DATE-365 GROUP BY 1),
rk AS (
  SELECT CASE WHEN muhatap_adi ILIKE '%MUTAFLAR%' THEN 'MUTAFLAR'
              WHEN muhatap_adi ILIKE '%YEDİ OTO%' OR muhatap_adi ILIKE '%YEDI OTO%' THEN 'YEDI_OTO'
              WHEN muhatap_adi ILIKE '%BAR OTO%' THEN 'BAR_OTO' END a,
         max(kredi_limiti) lim, max(toplam_risk) risk, max(vadesi_gecmis) gec
    FROM bi_musteri_risk WHERE tenant_id='$TEN'::uuid AND musteri_mi GROUP BY 1)
SELECT '$TEN', 'kredi:'||os.alici, 'kredi_asimi',
       replace(os.alici,'_',' ')||' sevkiyatı kredi limitini '||
         round((rk.risk + os.adet*fy.birim)/NULLIF(rk.lim,0))||' kat aşıyor',
       os.adet||' adet · limit '||round(rk.lim/1e6,1)||'M · gecikmiş '||
         round(rk.gec/1e6,1)||'M · sevkiyat sonrası risk '||
         round((rk.risk+os.adet*fy.birim)/1e6,1)||'M',
       round(os.adet*fy.birim), DATE '2026-11-18', 'nakit',
       jsonb_build_object('alici',os.alici,'adet',os.adet,'limit',rk.lim,'risk',rk.risk)
  FROM os JOIN fy ON fy.a=os.alici JOIN rk ON rk.a=os.alici
 WHERE rk.lim > 0 AND (rk.risk + os.adet*fy.birim) > rk.lim * 3
ON CONFLICT (tenant_id, anahtar) DO UPDATE SET
  durum='acik', olusma=now(), baslik=EXCLUDED.baslik, ozet=EXCLUDED.ozet,
  tutar_tl=EXCLUDED.tutar_tl, detay=EXCLUDED.detay, kapanma=NULL;

-- ═══ M3: ODEME TAKVIMI ═══
INSERT INTO bi_sinyal (tenant_id, anahtar, tur, baslik, ozet, tutar_tl, son_tarih, oda, detay)
WITH mal AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric mm
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
eb AS (
  SELECT regexp_replace(upper(f.ebat),'\s+','','g') e, AVG(mal.mm) mm
    FROM bi_satis_faturalari f JOIN mal ON mal.kalem_kodu=f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.ebat<>'' GROUP BY 1),
od(tarih, donem, aciklama) AS (VALUES
  (DATE '2026-11-18','1','Brisa 1. dönem, 1. taksit'),
  (DATE '2026-12-16','1','Brisa 1. dönem, 2. taksit'),
  (DATE '2027-01-22','2','Brisa 2. dönem, 1. taksit'),
  (DATE '2027-02-22','2','Brisa 2. dönem, 2. taksit'))
SELECT '$TEN', 'odeme:'||od.tarih, 'odeme',
       to_char(od.tarih,'DD Mon')||' ödemesi: '||
         round(SUM(o.adet*COALESCE(eb.mm,3000))/2/1e6,1)||'M ₺',
       od.aciklama||' · '||SUM(o.adet)/2||' adet · o tarihte tahsilat beklentisi tanımlı değil',
       round(SUM(o.adet*COALESCE(eb.mm,3000))/2), od.tarih, 'nakit',
       jsonb_build_object('donem',od.donem,'tarih',od.tarih)
  FROM od JOIN bi_on_siparis o
    ON o.tenant_id='$TEN' AND o.sezon_yili='2026-27'
   AND o.tedarikci='BRISA' AND o.donem=od.donem
  LEFT JOIN eb ON eb.e = regexp_replace(upper(o.ebat),'\s+','','g')
 GROUP BY od.tarih, od.donem, od.aciklama
ON CONFLICT (tenant_id, anahtar) DO UPDATE SET
  durum='acik', olusma=now(), baslik=EXCLUDED.baslik, ozet=EXCLUDED.ozet,
  tutar_tl=EXCLUDED.tutar_tl, detay=EXCLUDED.detay, kapanma=NULL;

-- ═══ M4: OLU STOK ═══
INSERT INTO bi_sinyal (tenant_id, anahtar, tur, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var, detay)
WITH mal AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric mm
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT '$TEN', 'olustok', 'olu_stok',
       'Ölü stok: '||round(SUM(s.adet*mal.mm)/1e6,1)||'M ₺ bir yıldır satılmadı',
       count(DISTINCT s.marka)||' marka · '||round(SUM(s.adet))||' adet · raf ömrü doluyor',
       round(SUM(s.adet*mal.mm)), NULL, 'sezon', true,
       jsonb_build_object('adet',round(SUM(s.adet)))
  FROM bi_stok_anlik s JOIN mal ON mal.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0
   AND NOT EXISTS (SELECT 1 FROM bi_satis_faturalari f
                    WHERE f.tenant_id='$TEN' AND f.kalem_kodu=s.kalem_kodu
                      AND f.fatura_tarihi >= CURRENT_DATE-365 AND f.miktar>0)
HAVING SUM(s.adet*mal.mm) > 1e6
ON CONFLICT (tenant_id, anahtar) DO UPDATE SET
  durum='acik', olusma=now(), baslik=EXCLUDED.baslik, ozet=EXCLUDED.ozet,
  tutar_tl=EXCLUDED.tutar_tl, detay=EXCLUDED.detay, kapanma=NULL;

-- ═══ M5: VERI BAYATLIGI ═══
INSERT INTO bi_sinyal (tenant_id, anahtar, tur, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var)
SELECT '$TEN', 'veri:'||t.ad, 'veri_bayat',
       t.ad||' '||t.gun||' gündür güncellenmedi',
       'Bu akış durursa üstündeki her hesap sessizce yanlışlar', 0, NULL, 'veri', true
  FROM (
    SELECT 'Stok hareketi' ad, (CURRENT_DATE - max(belge_tarihi))::int gun
      FROM bi_stok_hareket WHERE tenant_id='$TEN'
    UNION ALL
    SELECT 'Satış faturaları', (CURRENT_DATE - max(fatura_tarihi))::int
      FROM bi_satis_faturalari WHERE tenant_id='$TEN'
    UNION ALL
    SELECT 'Alış faturaları', (CURRENT_DATE - max(fatura_tarihi))::int
      FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid
  ) t WHERE t.gun > 7
ON CONFLICT (tenant_id, anahtar) DO UPDATE SET
  durum='acik', olusma=now(), baslik=EXCLUDED.baslik, kapanma=NULL;
SQL

echo
echo "############ 3) ⚠ PUANLANMIS KUYRUK — ana sayfada ne gorunecek? ############"
$PSQL -c "
SELECT bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS puan,
       tur, left(baslik, 52) AS baslik,
       CASE WHEN tutar_tl >= 1e6 THEN round(tutar_tl/1e6,1)||'M' ELSE round(tutar_tl/1e3)||'K' END AS tutar,
       son_tarih,
       CASE WHEN son_tarih IS NULL THEN '—'
            ELSE (son_tarih - CURRENT_DATE)||' gun' END AS kalan,
       oda
  FROM bi_sinyal
 WHERE tenant_id='$TEN' AND durum='acik'
 ORDER BY 1 DESC LIMIT 12;"
echo
echo "  ⚠ ANA SAYFADA ILK 3 GOSTERILIR. Digerleri odalarinda."
echo "     Pencere kapaninca aciliyet SIFIRLANIR -> sinyal kendiliginden DUSER."
echo "     Kimse kod degistirmez. Icerigi TASARIM degil VERI belirler."

echo
echo "############ 4) ACIK SINYAL SAYISI — tur bazinda ############"
$PSQL -c "
SELECT tur, count(*) AS adet,
       round(sum(tutar_tl)/1e6,1) AS toplam_MTL,
       round(max(bi_sinyal_puan(tutar_tl, son_tarih, eylem_var)),1) AS en_yuksek_puan
  FROM bi_sinyal WHERE tenant_id='$TEN' AND durum='acik'
 GROUP BY 1 ORDER BY 4 DESC;"

git add -A && git commit -q -m "feat(sinyal): SINYAL_V1 — bi_sinyal + puanlama fonksiyonu + 5 monitor (sevk gecikmesi, kredi asimi, odeme takvimi, olu stok, veri bayatligi). puan = para(log) x aciliyet(son_tarih) x eylem. Pencere kapaninca aciliyet 0 -> sinyal kendiliginden duser. Ana sayfa SABIT panel degil, PUANLANMIS KUYRUK — icerigi tasarim degil veri belirler." && echo "  COMMITTED"
