#!/usr/bin/env bash
# ZINCIR_KESIF — baglantiyi kurmadan ONCE. Sadece OKUR.
#
# ⚠ KRITIK SORU: durum'u master_musteri'den hesapliyorum.
#   Peki master_musteri NE ZAMAN tazeleniyor?
#   Eger ERP yuklendiginde tazelenmiyorsa, zinciri YANLIS YERE baglarim:
#     yeni faturalar gelir -> master_musteri eski kalir -> durum eski master'dan hesaplanir
#     -> ve HER SEY CALISIYORMUS GIBI GORUNUR.
#   Sessizce yanlis olan tam olarak bu tur bir sey. Once ZINCIRI gorecegim.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) master_musteri'yi KIM tazeliyor? ############"
grep -rn "master_musteri" --include=*.py --include=*.mjs --include=*.sh . 2>/dev/null \
  | grep -iv "^\./server_container.mjs.bak\|shells/.*bak" \
  | grep -i "insert\|create\|refresh\|truncate\|delete\|drop\|def \|kur" | head -15
echo
echo "  --- cron ne calistiriyor? ---"
crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "  (root crontab bos)"

echo
echo "############ 2) master_musteri NE KADAR TAZE? ############"
$PSQL -c "
SELECT max(refreshed_at) AS son_tazeleme,
       now() - max(refreshed_at) AS yas,
       max(son_fatura) AS master_son_fatura
  FROM master_musteri;"
$PSQL -c "SELECT max(fatura_tarihi) AS ham_veri_son_fatura FROM bi_satis_faturalari;"
echo "  ⚠ Ikisi ayni olmali. master_son_fatura geride ise master BAYAT."

echo
echo "############ 3) KURULUM sozlugu — adim adlari nerede tanimli? ############"
awk 'NR>=760 && NR<=770 { printf "%5d| %s\n", NR, $0 }' erp_ingest.py
echo "  --- sozlugun adi ve adimlarin listesi ---"
grep -n '^[A-Z_]* = {' erp_ingest.py | head
grep -n '^  "[a-z_]*": """' erp_ingest.py

echo
echo "############ 4) Adimlari calistiran fonksiyon (847 civari) ############"
awk 'NR>=840 && NR<=890 { printf "%5d| %s\n", NR, $0 }' erp_ingest.py
