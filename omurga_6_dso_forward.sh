#!/usr/bin/env bash
# OMURGA 6 — snapshot runner'a DSO forward ekle (bugün+ileri GERÇEK alacak=snapshot). Cron yolu aynı.
set -u
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. RUNNER'I YENİDEN YAZ — ciro (akış) + DSO/alacak GERÇEK (pozisyon, snapshot)"
cat > /opt/krb-assessment/metrik_snapshot_gunluk.sh <<'RUNNER'
#!/usr/bin/env bash
# Metrik geçmişi — GÜNLÜK SNAPSHOT. Tüm kiracılar. Ciro=trailing 3 ay akış; DSO=içinde bulunulan ay GERÇEK alacak.
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
-- A. CIRO (akış = kesin) — son 3 ay, tüm kiracılar
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

-- B. DSO + bileşenleri — İÇİNDE BULUNULAN AY, GERÇEK alacak (bi_musteri_risk) = snapshot KESİN
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
         jsonb_build_object('tam',false,'yontem','gercek alacak / gunluk_kredili') FROM comp
  UNION ALL
  SELECT tenant_id,'alacak','ay',date_trunc('month',CURRENT_DATE)::date,round(alacak),'TL','snapshot','bi_musteri_risk',
         jsonb_build_object('tam',false) FROM comp
  UNION ALL
  SELECT tenant_id,'gunluk_kredili_satis','ay',date_trunc('month',CURRENT_DATE)::date,round(gunluk),'TL','kesin','bi_satis_faturalari',
         jsonb_build_object('tam',false) FROM comp
) x
ON CONFLICT (tenant_id,metrik,periyot,donem)
  DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
echo "[$(date '+%F %T')] metrik snapshot tamam (ciro + dso)"
RUNNER
chmod +x /opt/krb-assessment/metrik_snapshot_gunluk.sh
echo "  ✅ runner güncellendi (ciro + DSO forward)"

hr "2. TEST — çalıştır (içinde bulunulan ay DSO'su gerçek alacağa dönmeli)"
bash /opt/krb-assessment/metrik_snapshot_gunluk.sh

hr "3. ⚠ DOĞRULA — içinde bulunulan ay DSO artık 'snapshot' + gerçek ~130 mu (recon 143'ten döndü mü)"
$PSQL -c "SELECT metrik, to_char(donem,'YYYY-MM') ay,
                 CASE WHEN metrik='dso' THEN round(deger) ELSE round(deger/1e6,1) END deger,
                 guven, kaynak
          FROM bi_metrik_gecmis
          WHERE tenant_id='$T'::uuid AND periyot='ay' AND donem=date_trunc('month',CURRENT_DATE)::date
            AND metrik IN ('dso','alacak','gunluk_kredili_satis') ORDER BY metrik;"
echo "  ⚠ dso 'snapshot' + ~130, alacak 'snapshot' + ~209M olmalı (recon 143/226'dan gerçeğe döndü)."

hr "4. GÜVEN GEÇİŞİ — geçmiş yaklasik, bugün snapshot (birlikte, etiketli)"
$PSQL -c "SELECT guven, count(*) FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='dso' AND periyot='ay' GROUP BY 1;"
echo "  ⚠ 45 yaklasik (geçmiş recon) + 1 snapshot (bugün gerçek) = dürüst karışım."

hr "BITTI — DSO artık ciro gibi kendi kendine yürüyor: geçmiş recon, bugün+ileri gerçek. Cron 08:15."
