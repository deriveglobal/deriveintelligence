#!/usr/bin/env bash
# OMURGA 3 — günlük snapshot cron. Runner'ı yazar + cron kurar + test eder + doğrular.
set -u
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. RUNNER YAZ — /opt/krb-assessment/metrik_snapshot_gunluk.sh (tüm kiracılar, trailing 3 ay)"
cat > /opt/krb-assessment/metrik_snapshot_gunluk.sh <<'RUNNER'
#!/usr/bin/env bash
# Metrik geçmişi — GÜNLÜK SNAPSHOT. Tüm kiracıları otomatik dolaşır, son 3 ayı idempotent tazeler.
#   Ay dönümünde önceki ay 'tam=true' olarak kesinleşir; içinde bulunulan ay 'tam=false'.
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
WITH t_sinir AS (
  SELECT tenant_id,
         date_trunc('month', max(fatura_tarihi))::date AS son_ay,
         date_trunc('month', min(fatura_tarihi))::date AS ilk_ay
    FROM bi_satis_faturalari GROUP BY tenant_id
),
aylar AS (
  SELECT generate_series(date_trunc('month',CURRENT_DATE)::date - interval '2 month',
                         date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date AS ay
)
INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, meta)
SELECT ts.tenant_id::uuid, m.metrik, 'ay', a.ay,
       metrik_ciro(ts.tenant_id::uuid, a.ay, m.lastik), 'TL', 'kesin', 'bi_satis_faturalari',
       jsonb_build_object('tam', a.ay < ts.son_ay)
  FROM t_sinir ts
  CROSS JOIN aylar a
  CROSS JOIN (VALUES ('ciro_lastik', true), ('ciro_tum', false)) AS m(metrik, lastik)
 WHERE a.ay >= ts.ilk_ay
ON CONFLICT (tenant_id, metrik, periyot, donem)
  DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
echo "[$(date '+%F %T')] metrik snapshot tamam"
RUNNER
chmod +x /opt/krb-assessment/metrik_snapshot_gunluk.sh
echo "  ✅ runner yazıldı + çalıştırılabilir"

hr "2. CRON KUR — 08:15 günlük (mevcut scraper cron'larını KORUR, sadece bunu ekler)"
LINE='15 8 * * * /opt/krb-assessment/metrik_snapshot_gunluk.sh >> /var/log/metrik_snapshot.log 2>&1'
( crontab -l 2>/dev/null | grep -v 'metrik_snapshot_gunluk.sh'; echo "$LINE" ) | crontab -
echo "  ✅ cron kuruldu:"
crontab -l | grep -n 'metrik_snapshot' | sed 's/^/    /'

hr "3. TEST — şimdi bir kez çalıştır (cron beklemeden)"
bash /opt/krb-assessment/metrik_snapshot_gunluk.sh

hr "4. DOĞRULA — hesaplanma_at az önce güncellendi mi (snapshot gerçekten yazdı mı)"
$PSQL -c "SELECT metrik, count(*) ay, max(hesaplanma_at) son_hesaplanma,
                 max(hesaplanma_at) > now() - interval '2 minute' AS az_once_yazildi
          FROM bi_metrik_gecmis GROUP BY 1;"
echo "  ⚠ az_once_yazildi = t ise cron runner çalışıyor demektir."

hr "5. İÇİNDE BULUNULAN AY — tam=false işaretli mi (kısmi ay yanlış okunmasın)"
$PSQL -c "SELECT metrik, to_char(donem,'YYYY-MM') ay, round(deger/1e6,1) ciro_m, meta->>'tam' tam
          FROM bi_metrik_gecmis WHERE periyot='ay' AND donem=date_trunc('month',CURRENT_DATE)::date ORDER BY 1;"

hr "BITTI — omurga artık KENDİ KENDİNE yürüyor. Her gün 08:15 son 3 ay tazelenir."
