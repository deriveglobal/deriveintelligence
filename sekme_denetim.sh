#!/usr/bin/env bash
# ⚠ SEKME DENETIMI — 6 sekme, hepsi eski mantikla yazildi.
#
# BUGUN KANITLANDI: pricing/ccc DSO'yu 0,1 GUN gosteriyordu (AVG yerine SUM).
#   Ayni donemde, ayni kafayla yazilmis 6 sekme daha var.
#
# BILINEN BOZUK KAYNAKLAR (bugun olculdu):
#   bi_musteri_bakiye      399 musteri (taban %1) · vadesi_gecmis_tutar x10.000 BOZUK
#   bi_stok_hareketleri    12 HAZIRAN'DA DONMUS · birim_maliyet 6,7 KAT sisik
#   bi_stok_durumu         donmus
#   AVG(vade_gun)          AGIRLIKSIZ — 1 TL ile 1M TL esit agirlikta
#   AVG(birim_fiyat...)    AGIRLIKSIZ maliyet
#   grup_adi filtresi YOK  ISCILIK/PRIM/SERVIS satirlari markaya/urune karisiyor
#   miktar>0 filtresi YOK  IADE satirlari ortalamalari SESSIZCE kaydiriyor
#
# DOGRU KAYNAKLAR (bugun kuruldu, kapidan gecti):
#   bi_musteri_risk        38.604 muhatap · 145,4M gecikmis · 165 limit asimi
#   bi_fatura_tahsilat     175.649 fatura · gercek tahsilat tarihleri
#   bi_stok_anlik          2.185 SKU · 52.295 lastik · son alis maliyetiyle
S=/opt/krb-assessment/server_container.mjs

UCLAR=(
  "/api/bi/sales/kpis"
  "/api/bi/sales/trend"
  "/api/bi/pricing/kpis"
  "/api/bi/pricing/monitor"
  "/api/bi/pricing/brand-incentives"
  "/api/bi/warehouse/kpis"
  "/api/bi/warehouse/movements"
  "/api/bi/orders/daily"
  "/api/bi/orders/preorder"
  "/api/bi/orders/size-opportunities"
  "/api/bi/it/kpis"
  "/api/bi/analytics/financial-perspective"
  "/api/bi/analytics/size-index"
  "/api/bi/analytics/cash-cycle-history"
)

for U in "${UCLAR[@]}"; do
  L=$(grep -n "\"$U\"" $S | head -1 | cut -d: -f1)
  [ -z "$L" ] && { echo "❓ $U — BULUNAMADI"; continue; }
  BLOK=$(sed -n "${L},$((L+70))p" $S)

  echo "══════════════════════════════════════════════════════════════"
  echo "  $U   (satir $L)"
  echo "══════════════════════════════════════════════════════════════"

  echo "  TABLOLAR:"
  echo "$BLOK" | grep -oE "FROM [a-z_]+|JOIN [a-z_]+" | awk '{print $2}' | sort -u | sed 's/^/    /'

  echo "  ⚠ BULGULAR:"
  BULGU=0
  echo "$BLOK" | grep -q "bi_musteri_bakiye" && { echo "    🔴 bi_musteri_bakiye — 399 musteri, vadesi_gecmis x10.000 BOZUK"; BULGU=1; }
  echo "$BLOK" | grep -q "bi_stok_hareketleri\|bi_stok_durumu" && { echo "    🔴 donmus stok tablosu (12 Haziran)"; BULGU=1; }
  echo "$BLOK" | grep -qE "AVG\(vade_gun|AVG\(birim" && { echo "    🟡 AGIRLIKSIZ ortalama (tutar agirlikli olmali)"; BULGU=1; }
  echo "$BLOK" | grep -q "bi_satis_faturalari" && ! echo "$BLOK" | grep -q "grup_adi" && { echo "    🟡 grup_adi filtresi YOK -> ISCILIK/PRIM/SERVIS karisiyor"; BULGU=1; }
  echo "$BLOK" | grep -q "bi_satis_faturalari\|bi_tedarikci_faturalari" && ! echo "$BLOK" | grep -q "miktar > 0\|miktar>0" && { echo "    🟡 miktar>0 YOK -> IADE satirlari ortalamayi kaydirir"; BULGU=1; }
  echo "$BLOK" | grep -qE "vade_tarihi - fatura_tarihi" && { echo "    🔴 'DSO' diye VADE SURESI hesapliyor — para ne zaman GELDI degil, faturada ne YAZIYOR"; BULGU=1; }
  echo "$BLOK" | grep -qiE "\|\| *0\.[0-9]|= *0\.[0-9]{2}" && { echo "    🟡 SABIT KATSAYI var — nereden geldigi belli mi?"; BULGU=1; }
  [ $BULGU -eq 0 ] && echo "    ✅ acik bir kirmizi bayrak yok (yine de mantik kontrolu gerek)"
  echo
done

echo "══════════════════════════════════════════════════════════════"
echo "  ⚠ SEKMELERI BESLEYEN YENI TABLOLAR — kim KULLANIYOR?"
echo "══════════════════════════════════════════════════════════════"
for T in bi_musteri_risk bi_fatura_tahsilat bi_stok_anlik bi_tedarikci_tesvik bi_tedarikci_kampanya; do
  N=$(grep -c "$T" $S)
  printf "  %-24s kodda %2d kez geciyor  %s\n" "$T" "$N" \
    "$([ "$N" -le 1 ] && echo '🔴 HIC KULLANILMIYOR' || echo '')"
done
echo
echo "  ^ Bugun 4 tablo yukledik. Sekmeler hala ESKI kaynaklari okuyor."
