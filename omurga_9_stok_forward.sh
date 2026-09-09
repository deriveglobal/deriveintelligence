#!/usr/bin/env bash
# OMURGA 9 — snapshot runner'a STOK forward ekle (bugün+ileri snapshot adet × maliyet = kesin). Cron yolu aynı.
set -u
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. RUNNER'I YENİDEN YAZ — A ciro + B dso + C stok (üçü de tüm kiracılar)"
cat > /opt/krb-assessment/metrik_snapshot_gunluk.sh <<'RUNNER'
#!/usr/bin/env bash
# Metrik geçmişi — GÜNLÜK SNAPSHOT. Tüm kiracılar. Ciro=trailing 3 ay akış; DSO+Stok=içinde bulunulan ay GERÇEK.
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
-- A. CIRO (akış = kesin) — son 3 ay
WITH t_sinir AS (
  SELECT tenant_id, date_trunc('month',max(fatura_tarihi))::date son_ay,
         date_trunc('month',min(fatura_tarihi))::date ilk_ay
    FROM bi_satis_faturalari GROUP BY tenant_id
),
aylar AS (
  SELECT generate_series(date_trunc('month',CURRENT_DATE)::date - interval '2 month',
                         date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date ay
)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT ts.tenant_id::uuid, m.metrik,'ay',a.ay,
       metrik_ciro(ts.tenant_id::uuid,a.ay,m.lastik),'TL','kesin','bi_satis_faturalari',
       jsonb_build_object('tam', a.ay < ts.son_ay)
  FROM t_sinir ts CROSS JOIN aylar a
  CROSS JOIN (VALUES ('ciro_lastik',true),('ciro_tum',false)) AS m(metrik,lastik)
 WHERE a.ay >= ts.ilk_ay
ON CONFLICT (tenant_id,metrik,periyot,donem)
  DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();

-- B. DSO + bileşenleri — içinde bulunulan ay, GERÇEK alacak (bi_musteri_risk) = snapshot
WITH comp AS (
  SELECT r.tenant_id,
         sum(r.hesap_bakiyesi) FILTER (WHERE COALESCE(r.musteri_mi,true)) AS alacak,
         metrik_gunluk_kredili(r.tenant_id, CURRENT_DATE) AS gunluk
    FROM bi_musteri_risk r GROUP BY r.tenant_id
)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT * FROM (
  SELECT tenant_id,'dso','ay',date_trunc('month',CURRENT_DATE)::date,
         CASE WHEN gunluk>0 THEN round(alacak/gunluk) END,'gun','snapshot','bi_musteri_risk',
         jsonb_build_object('tam',false) FROM comp
  UNION ALL SELECT tenant_id,'alacak','ay',date_trunc('month',CURRENT_DATE)::date,round(alacak),'TL','snapshot','bi_musteri_risk',jsonb_build_object('tam',false) FROM comp
  UNION ALL SELECT tenant_id,'gunluk_kredili_satis','ay',date_trunc('month',CURRENT_DATE)::date,round(gunluk),'TL','kesin','bi_satis_faturalari',jsonb_build_object('tam',false) FROM comp
) x
ON CONFLICT (tenant_id,metrik,periyot,donem)
  DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

-- C. STOK DEĞERİ — içinde bulunulan ay, GERÇEK (snapshot adet × ağırlıklı ort maliyet) = snapshot
WITH km AS (SELECT tenant_id, kalem_kodu, sum(giris_tutari) gt, sum(giris) g
              FROM bi_stok_hareket WHERE giris>0 GROUP BY tenant_id, kalem_kodu),
sd AS (SELECT a.tenant_id, sum(a.adet*(km.gt/km.g)) deger
         FROM bi_stok_anlik a JOIN km ON km.tenant_id=a.tenant_id AND km.kalem_kodu=a.kalem_kodu
        WHERE a.adet>0 GROUP BY a.tenant_id)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT tenant_id,'stok_deger','ay',date_trunc('month',CURRENT_DATE)::date,round(deger),'TL','snapshot','bi_stok_anlik',
       jsonb_build_object('tam',false) FROM sd
ON CONFLICT (tenant_id,metrik,periyot,donem)
  DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
echo "[$(date '+%F %T')] metrik snapshot tamam (ciro + dso + stok)"
RUNNER
chmod +x /opt/krb-assessment/metrik_snapshot_gunluk.sh
echo "  ✅ runner güncellendi (ciro + dso + stok)"

hr "2. TEST — çalıştır"
bash /opt/krb-assessment/metrik_snapshot_gunluk.sh

hr "3. ⚠ DOĞRULA — içinde bulunulan ay stok artık 'snapshot' + gerçek ~235M mı (recon 270'ten döndü)"
$PSQL -c "SELECT metrik,
                 CASE WHEN metrik IN ('dso') THEN round(deger) ELSE round(deger/1e6,1) END deger,
                 guven, kaynak
          FROM bi_metrik_gecmis
          WHERE tenant_id='$T'::uuid AND periyot='ay' AND donem=date_trunc('month',CURRENT_DATE)::date
            AND metrik IN ('ciro_lastik','dso','alacak','stok_deger') ORDER BY metrik;"

hr "4. TÜM METRİKLER — omurgada ne var (bakış)"
$PSQL -c "SELECT metrik, count(*) ay, min(donem)::text ilk, max(donem)::text son,
                 string_agg(DISTINCT guven,'+') guven
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND periyot='ay' GROUP BY 1 ORDER BY 1;"

hr "BITTI — 3 metrik (ciro/dso/stok) omurgada, kendi kendine yürüyor. Cron 08:15."
