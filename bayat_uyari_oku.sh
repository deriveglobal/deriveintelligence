#!/usr/bin/env bash
# Salt okuma. Yamalanacak BAYAT uyarilarin TAM metni lazim.
# Hafizadan anchor uydurmak bugun 2 kez basimi yakti.
S=/opt/krb-assessment/server_container.mjs

echo "═══════ A) 'ERP OLU / 69.1M' bayat uyarisi (25085-25115) ═══════"
echo "   ⚠ ARTIK YANLIS: 6 yil yuklendi, Haziran 121,76M."
sed -n '25085,25115p' $S

echo
echo "═══════ B) 'ciro' ile ilgili baska bayat metin var mi? ═══════"
grep -n "29 GUN\|29 gun\|69\.1\|69,1\|16 Haziran\|olu\|OLU" $S | grep -vi "coloured\|solution" | head -12

echo
echo "═══════ C) BRISA brifingi (tek seferlikti — hala duruyor mu?) ═══════"
grep -n "BRISA_V1\|Brisa'li\|uyandim" $S | head -5
echo "   ^ Fatih Bilen gordu mu? Gormediyse kalsin; gorduyse kaldirilmali."

echo
echo "═══════ D) CANLI RAKAMLAR — yeni uyari metni bunlari kullanacak ═══════"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT to_char(fatura_tarihi,'YYYY-MM') AS ay, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND fatura_tarihi >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 1;"

docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT 'satis' AS akis, count(*) AS satir, min(fatura_tarihi) AS ilk, max(fatura_tarihi) AS son
  FROM bi_satis_faturalari WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL
SELECT 'alis', count(*), min(fatura_tarihi), max(fatura_tarihi)
  FROM bi_tedarikci_faturalari WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid;"
