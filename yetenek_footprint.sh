#!/usr/bin/env bash
# YETENEK FOOTPRINT — defteri tazele (tablo+fonksiyon+endpoint+cron) + deploy-log satırı.
# deploy.sh bunu her build sonrası çağırır. Tek başına da çalışır. Kullanım: bash yetenek_footprint.sh "aciklama"
set -uo pipefail
cd /opt/krb-assessment || exit 0
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
ACIKLAMA="${1:-footprint}"

# 1) DB: tablo + fonksiyon (yaşam döngüsü: yeni/değişen/kayıp)
$PSQL -c "SELECT yetenek_tara();" >/dev/null 2>&1 || echo "[footprint] uyarı: yetenek_tara() yok"

# 2) Kod: endpoint (server_container.mjs) + cron
{
  echo "CREATE TEMP TABLE _kod(ad text, tur text, fp text);"
  grep -oE "url\.pathname === '/api/[^']+'" server_container.mjs | grep -oE "/api/[^']+" | sort -u | while read -r p; do
    echo "INSERT INTO _kod VALUES('$p','endpoint',md5('$p'));"
  done
  crontab -l 2>/dev/null | grep -vE '^\s*#|^\s*$' | while read -r line; do
    ad=$(printf '%s' "$line" | sed "s/'//g" | cut -c1-90); fp=$(printf '%s' "$line" | md5sum | cut -c1-32)
    echo "INSERT INTO _kod VALUES('$ad','cron','$fp');"
  done
  cat <<'D'
  INSERT INTO bi_yetenek(ad,tur,durum,parmak_izi,son_gorulme)
    SELECT ad,tur,'tanimsiz',fp,now() FROM _kod k WHERE NOT EXISTS(SELECT 1 FROM bi_yetenek y WHERE y.ad=k.ad AND y.tur=k.tur);
  UPDATE bi_yetenek y SET
    durum=CASE WHEN y.durum IN('onayli','taslak') AND y.parmak_izi IS DISTINCT FROM k.fp AND y.parmak_izi IS NOT NULL THEN 'degisti' ELSE y.durum END,
    parmak_izi=k.fp, son_gorulme=now() FROM _kod k WHERE y.ad=k.ad AND y.tur=k.tur;
  UPDATE bi_yetenek y SET durum='kayip',aktif=false
    WHERE y.tur IN('endpoint','cron') AND y.durum<>'kayip' AND NOT EXISTS(SELECT 1 FROM _kod k WHERE k.ad=y.ad AND k.tur=y.tur);
D
} | $PSQL >/dev/null 2>&1 || echo "[footprint] uyarı: kod taraması atlandı"

# 3) deploy-log damgası
BIJS_HASH=$(md5sum shells/bi.js 2>/dev/null | cut -c1-10)
ACL=$(printf '%s' "$ACIKLAMA" | sed "s/'//g")
$PSQL -c "INSERT INTO bi_deploy_log(bijs_hash,aciklama,yetenek_ozet)
  SELECT '$BIJS_HASH','$ACL',(SELECT jsonb_object_agg(tur,c) FROM (SELECT tur,count(*) c FROM bi_yetenek GROUP BY tur) x);" >/dev/null 2>&1
echo "[footprint] defter + deploy-log güncellendi — $ACL (bi.js $BIJS_HASH)"
