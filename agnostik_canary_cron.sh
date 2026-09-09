#!/usr/bin/env bash
set -uo pipefail
PSQL="${PSQL_CMD:-docker exec -i krb-assessment-postgres psql -v ON_ERROR_STOP=1 -U assessment_app -d assessment_platform}"

PREV=$($PSQL -tA -c "SELECT durum FROM v_agnostik_durum" 2>/dev/null | head -1)
PREV="${PREV:-YOK}"

FAILS=$($PSQL -tA <<'FAILQ'
\set KRB 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\set ANA '42822870-4ea3-424d-a16f-50b91afca32c'
WITH c(sira,probe,tur,krb,ana) AS (VALUES
 (1,'bi_marj_atom count','strict',
   (SELECT count(*)::numeric FROM bi_marj_atom WHERE tenant_id::text=:'KRB'),
   (SELECT count(*)::numeric FROM bi_marj_atom WHERE tenant_id::text=:'ANA')),
 (2,'bi_marj_fact count','strict',
   (SELECT count(*)::numeric FROM bi_marj_fact WHERE tenant_id::text=:'KRB'),
   (SELECT count(*)::numeric FROM bi_marj_fact WHERE tenant_id::text=:'ANA')),
 (3,'bi_satis ciro','strict',
   (SELECT round(sum(satir_tutar)) FROM bi_satis_faturalari WHERE tenant_id::text=:'KRB' AND satir_tutar>0),
   (SELECT round(sum(satir_tutar)) FROM bi_satis_faturalari WHERE tenant_id::text=:'ANA' AND satir_tutar>0)),
 (4,'v_finans dso','view',
   (SELECT round(dso) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'KRB'),
   (SELECT round(dso) FROM v_finans_ticari_sermaye WHERE tenant_id::text=:'ANA'))
)
SELECT probe||'|'||coalesce(krb::text,'NULL')||'|'||coalesce(ana::text,'NULL')||'|'||
  CASE
    WHEN tur='strict' AND (krb IS NULL OR ana IS NULL) THEN 'metrik NULL/hata'
    WHEN tur='strict' AND (krb=0 OR ana=0)             THEN 'tenant sifir satir'
    WHEN tur='strict' AND krb=ana                      THEN 'KRB=Anadolu -> tenant_id filtresi kacti'
    WHEN tur='view'   AND krb IS NULL                  THEN 'KRB metrik NULL (bozuk)'
    WHEN tur='view'   AND ana IS NOT NULL AND krb=ana  THEN 'KRB=Anadolu -> tenant_id filtresi kacti'
  END
FROM c
WHERE (tur='strict' AND (krb IS NULL OR ana IS NULL OR krb=0 OR ana=0 OR krb=ana))
   OR (tur='view'   AND (krb IS NULL OR (ana IS NOT NULL AND krb=ana)));
FAILQ
)
FAILS=$(printf '%s\n' "$FAILS" | grep -v '^$' || true)

COZUM='Kacan sorguya tenant_id filtresi ekle (WHERE tenant_id=$1); helper cagrisinda tenant SUTUN ver. Kural: devir kural 2. Duzeltip agnostik_canary.sh tekrar calistir.'

if [ -z "$FAILS" ]; then
  $PSQL -q -c "INSERT INTO bi_agnostik_alarm(durum,ne_oldu) VALUES('YESIL','tum probe tenant-ayrik');" >/dev/null 2>&1
  if [ "$PREV" = "KIRMIZI" ]; then
    $PSQL -q >/dev/null 2>&1 <<MARKG
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
VALUES('AGNOSTIK_ALARM_TEMIZLENDI',
 'Tenant izolasyon alarmi TEMIZLENDI (kirmizi->yesil)',
 'Canary tekrar tum probe tenant-ayrik buldu; onceki drift giderildi.',
 '{"kaynak":"agnostik_canary_cron.sh"}'::jsonb);
MARKG
  fi
  echo "AGNOSTIK CANARY CRON: YESIL — tenant izolasyonu saglam."
  exit 0
fi

echo "############################################################"
echo "# AGNOSTIK ALARM: TENANT IZOLASYONU BOZUK (KIRMIZI)"
echo "############################################################"
printf '%s\n' "$FAILS" | while IFS='|' read -r probe krb ana neden; do
  [ -z "$probe" ] && continue
  echo "  FAIL: $probe  (krb=$krb ana=$ana)  -> $neden"
  $PSQL -q >/dev/null 2>&1 <<WRITER
INSERT INTO bi_agnostik_alarm(durum,probe,krb,ana,ne_oldu,cozum)
VALUES('KIRMIZI',
  \$\$${probe}\$\$,
  NULLIF('${krb}','NULL')::numeric,
  NULLIF('${ana}','NULL')::numeric,
  \$\$${neden}\$\$,
  \$\$${COZUM}\$\$);
WRITER
done

if [ "$PREV" != "KIRMIZI" ]; then
  FIRST=$(printf '%s\n' "$FAILS" | head -1)
  $PSQL -q >/dev/null 2>&1 <<MARKR
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
VALUES('AGNOSTIK_ALARM_KIRMIZI',
 \$\$TENANT IZOLASYON ALARMI: bir sorgu tenant_id filtresini kacirdi -> veri sizabilir\$\$,
 \$\$Canary probe(ler) KRB=Anadolu ya da NULL buldu. SON DEPLOY tenant izolasyonunu bozdu. Ilk bulgu: ${FIRST}. Coz: ${COZUM}\$\$,
 jsonb_build_object('kaynak','agnostik_canary_cron.sh','ilk_bulgu',\$\$${FIRST}\$\$,'kural','devir kural 2 cok-tenant agnostik'));
MARKR
  echo "  -> bi_insa_gunlugu'na AGNOSTIK_ALARM_KIRMIZI yazildi (sonraki oturum cold-start'ta gorur)."
fi
echo "  Coz: $COZUM"
exit 1
