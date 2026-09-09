#!/usr/bin/env bash
# NET MARJ ETKİSİ — teşvik maliyete katılınca marj ne oluyor. SADECE GÖSTERİR (henüz baz değiştirmez).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. Marka bazında: BRÜT marj  vs  KESİN-net (fatura-altı)  vs  POTANSİYEL-net (max_toplam)"
$PSQL -c "
WITH tv AS (   -- marka başına temsili teşvik (segment ortalaması — kaba, ilk büyüklük)
  SELECT upper(marka) marka, avg(fatura_alti_pct) f_pct, avg(max_toplam_pct) m_pct
  FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid GROUP BY 1),
a AS (   -- son 6 ay atom
  SELECT upper(marka) marka, sum(ciro) ciro, sum(ciro-brut_kar) smm, sum(brut_kar) brut
  FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month'
  GROUP BY 1)
SELECT a.marka,
  round(a.ciro/1e6,1) ciro_M,
  round(100*a.brut/nullif(a.ciro,0),1)                                             brut_marj_pct,
  round(tv.f_pct,0)                                                                fatura_alti_pct,
  round(100*(a.ciro - a.smm*(1-tv.f_pct/100))/nullif(a.ciro,0),1)                  kesin_net_marj_pct,
  round(tv.m_pct,0)                                                                max_toplam_pct,
  round(100*(a.ciro - a.smm*(1-tv.m_pct/100))/nullif(a.ciro,0),1)                  potansiyel_net_marj_pct
FROM a JOIN tv USING(marka)
ORDER BY a.ciro DESC;" 2>&1 | sed 's/^/  /'

hr "2. Makuliyet: kesin-net marj mantıklı aralıkta mı (0-40 iyi; >60 ya da <-10 = baz zaten net olabilir)"
$PSQL -c "
WITH tv AS (SELECT upper(marka) marka, avg(fatura_alti_pct) f_pct FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid GROUP BY 1),
a AS (SELECT upper(marka) marka, sum(ciro) ciro, sum(ciro-brut_kar) smm, sum(brut_kar) brut
      FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY 1)
SELECT count(*) marka, count(*) FILTER (WHERE km BETWEEN 0 AND 45) makul, count(*) FILTER (WHERE km>60 OR km<-10) supheli
FROM (SELECT round(100*(a.ciro - a.smm*(1-tv.f_pct/100))/nullif(a.ciro,0),1) km FROM a JOIN tv USING(marka)) z;" 2>&1 | sed 's/^/  /'

hr "3. Toplam etki — 6 teşvikli markada brüt kâr vs kesin-net kâr (TL)"
$PSQL -c "
WITH tv AS (SELECT upper(marka) marka, avg(fatura_alti_pct) f_pct FROM bi_tedarikci_tesvik WHERE tenant_id='$T'::uuid GROUP BY 1),
a AS (SELECT upper(marka) marka, sum(ciro) ciro, sum(ciro-brut_kar) smm, sum(brut_kar) brut
      FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY 1)
SELECT round(sum(a.brut)/1e6,1) brut_kar_M, round(sum(a.ciro - a.smm*(1-tv.f_pct/100))/1e6,1) kesin_net_kar_M,
       round((sum(a.ciro - a.smm*(1-tv.f_pct/100)) - sum(a.brut))/1e6,1) fark_M
FROM a JOIN tv USING(marka);" 2>&1 | sed 's/^/  /'

hr "BITTI — büyüklük görüldü. Baz zaten net mi (muhasebe sorusu) + segment kırılımı sıradaki karar."
