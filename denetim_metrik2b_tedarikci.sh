#!/usr/bin/env bash
# METRIK 2B — tedarikci borcu: yogunlasma + ic tutarlilik capraz-kontrol + tire-mix. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YOGUNLASMA — en cok borçlu oldugumuz 12 tedarikci (dogru kolon: tedarikci_adi)"
$PSQL -c "
SELECT left(tedarikci_adi,42) AS tedarikci, round(abs(tedarikci_bakiye)/1e6,1) AS borc_m
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0
 ORDER BY abs(tedarikci_bakiye) DESC LIMIT 12;"

hr "2. YOGUNLASMA ORANI — tek/uc/bes tedarikci payi (SINIR)"
$PSQL -c "
WITH b AS (SELECT abs(tedarikci_bakiye) v FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0 ORDER BY 1 DESC)
SELECT round(sum(v)/1e6,1) AS toplam_m,
       round(100.0*(SELECT sum(v) FROM (SELECT v FROM b LIMIT 1) x)/sum(v)) AS tek_pct,
       round(100.0*(SELECT sum(v) FROM (SELECT v FROM b LIMIT 3) x)/sum(v)) AS uc_pct,
       round(100.0*(SELECT sum(v) FROM (SELECT v FROM b LIMIT 5) x)/sum(v)) AS bes_pct
  FROM b;"
echo "  ⚠ Tek tedarikci payi yuksekse: borc TEK NOKTADA yogun — bir DURUM, oran degil (SINIR)."

hr "3. ⚠ IC TUTARLILIK (tek capraz-kontrol) — tedarikci + musteri = net_pozisyon mu?"
$PSQL -c "
SELECT round(sum(tedarikci_bakiye)/1e6,1) AS ted_toplam_m,
       round(sum(musteri_bakiye)/1e6,1)   AS mus_toplam_m,
       round(sum(net_pozisyon)/1e6,1)     AS net_toplam_m,
       round((sum(tedarikci_bakiye)+sum(musteri_bakiye)-sum(net_pozisyon))/1e6,3) AS fark_m
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"
echo "  ⚠ fark_m ~0 ise: ERP'nin kendi aritmetigi tutarli. Bagimsiz degil ama ic tutarli."

hr "4. ⚠ TIRE-MIX — tedarikciler lastik mi hizmet mi? (bolunebilir mi)"
$PSQL -c "
SELECT
  count(*) FILTER (WHERE tedarikci_adi ~* 'lastik|brisa|bridgestone|lassa|michelin|goodyear|petlas|pirelli|continental|hankook|kumho|starmaxx') AS lastik_ismi,
  count(*) FILTER (WHERE tedarikci_adi ~* 'avukat|hukuk|nakliy|kargo|elektrik|dogalgaz|kira|sigorta|muhasebe|danisman') AS hizmet_ismi,
  count(*) AS toplam
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0;"
echo "  ⚠ Hizmet tedarikcisi varsa: borc SAF LASTIK degil (avukat ornegi). Sirket geneli + SINIR."

hr "5. #119 baglantisi — master_musteri.bizim_borcumuz NEREDEN? (kirli mi)"
$PSQL -c "
SELECT round(sum(bizim_borcumuz)/1e6,1) AS mm_bizim_borc_m,
       round((SELECT sum(tedarikci_bakiye) FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid)/1e6,1) AS cb_ted_toplam_m
  FROM master_musteri WHERE tenant_id='$T'::uuid;"
echo "  ⚠ Ikisi esitse: TUM tedarikci borcu master_musteri'ye kopyalanmis (dagitilmamis) — #119 kirliligi."

hr "BITTI"
