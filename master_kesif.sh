#!/usr/bin/env bash
# MASTER_KESIF — master_musteri'yi KIM ve NE ZAMAN kuruyor?
#
# ⚠ IPUCU: refreshed_at = 1,5 dakika once. Konteyner tam o sirada yeniden basladi.
#   Yani master_musteri muhtemelen SUNUCU ACILISINDA kuruluyor — ERP yuklenince DEGIL.
#   Oyleyse zincirde CIDDI bir bosluk var:
#     yarin ERP dosyasi yuklenir, konteyner yeniden BASLAMAZ,
#     master_musteri ESKI kalir, durum ESKI master'dan hesaplanir,
#     ve HER SEY CALISIYOR GORUNUR.
#
# ⚠ Ama emin degilim: grep master_musteri INSERT'ini sadece srv_broken.mjs'te
#   (bayat, kullanilmayan dosya) buldu; CANLI sunucuda bulamadi. Bu TUTARSIZ.
#   Yamayi kurmadan once KESIN YERI gorecegim. Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) CANLI sunucuda master_musteri nerede geciyor? ############"
grep -n "master_musteri" server_container.mjs | head -20

echo
echo "############ 2) INSERT/kurma blogu — tam kod ############"
L=$(grep -n "INSERT INTO master_musteri" server_container.mjs | head -1 | cut -d: -f1)
if [ -n "$L" ]; then
  echo "  INSERT satiri: $L"
  awk -v s="$((L-40))" -v e="$((L+35))" 'NR>=s && NR<=e { printf "%5d| %s\n", NR, $0 }' server_container.mjs
else
  echo "  ⚠ CANLI SUNUCUDA 'INSERT INTO master_musteri' YOK."
  echo "     O zaman tabloyu BASKA bir sey dolduruyor. Nerede?"
fi

echo
echo "############ 3) Bu kurma islemini KIM cagiriyor? (acilista mi, endpoint'ten mi?) ############"
grep -n "masterMusteri\|master_musteri\|refreshMaster\|ensureMaster\|masterYenile" server_container.mjs \
  | grep -i "function\|await\|call\|await ensure\|setInterval\|boot\|start" | head -10
echo "  --- acilista calisan fonksiyonlar ---"
grep -n "^await \|^  await \|ensureSchema()\|bootstrap()\|init()" server_container.mjs | tail -15

echo
echo "############ 4) Baska dosyalar? (cron disi bir script olabilir) ############"
ls -la /opt/price_monitor/*.py 2>/dev/null | head -20
grep -rln "master_musteri" /opt/price_monitor/ 2>/dev/null | head

echo
echo "############ 5) ⚠ KANIT DENEMESI — konteyner yeniden baslayinca tazeleniyor mu? ############"
echo "  su anki refreshed_at:"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform \
  -tAc "SELECT max(refreshed_at) FROM master_musteri;" | sed 's/^/    /'
echo "  konteyner baslama zamani:"
docker inspect -f '{{.State.StartedAt}}' krb-assessment | sed 's/^/    /'
echo "  ⚠ Ikisi yakinsa: master ACILISTA kuruluyor demektir -> ERP yuklemesi onu TAZELEMEZ."
