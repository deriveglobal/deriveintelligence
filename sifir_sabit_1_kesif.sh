#!/usr/bin/env bash
# SIFIR_SABIT_1 — "ekranda HICBIR SEY sabit olmayacak."
#
# ⚠ ILKE: ekrandaki her SAYI veriden gelecek. Her CUMLE bir KURAL olacak.
#   Isim veren, rakam veren, "su su kadardir" diyen her sabit metin
#   ya DEGISKENE baglanacak ya SILINECEK.
#
# ⚠ SU AN EKRANDA YALAN SOYLEYEN CUMLE VAR:
#   bi.js:284 — "Gercek DSO 116 gun". Sistem az once 102 hesapladi.
#   Ekranin kendi metni, ekranin kendi sayisini yalanliyor.
#
# ⚠ VE MUTAFLAR CUMLESI IKI YERDE SABIT (453 ve 735):
#   "brut 47,6M · borcumuz 46,6M · net 1,0M"
#   MUTAFLAR yarin borcunu kapatsa, ekran HALA ayni seyi yazacak.
#   Yerine KURAL gelecek: "bir musteri ayni zamanda tedarikci olabilir;
#   net pozisyon gosterilir" — ve zaten her satirda brut/borc VERIDEN yaziliyor.
#
# ⚠ ONCE TAM ENVANTER. Korlemesine 20 satir degistirmem — bugun uc kez yamada hata yaptik.
# Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) GORUNUR METINDEKI HER SABIT SAYI — satir satir ############"
python3 - <<'PY'
import re, pathlib
lines = pathlib.Path("shells/bi.js").read_text(encoding="utf-8").split("\n")
# yorum satirlarini atla; sadece KULLANICIYA GORUNEN metin
sayi = re.compile(r"(\d+[.,]\d+\s*M|\d+\s*M\b|%\s?\d+[,.]?\d*|\d+[,.]?\d*\s*kat|\d+\s*gün|\d+[.,]\d+)")
for i, l in enumerate(lines, 1):
    t = l.strip()
    if t.startswith("//") or t.startswith("/*") or t.startswith("*"):
        continue
    # sadece string literal iceren satirlar
    if not ("'" in l or '"' in l):
        continue
    # hesaplanan degerler (degisken) haric
    if re.search(r"_M\(|_tl\(|toFixed|Number\(|Math\.|parseInt|parseFloat", l):
        # ama AYNI satirda sabit sayi da olabilir
        pass
    m = sayi.findall(l)
    if not m:
        continue
    # css/px/renk/opacity gibi seyleri ele
    if re.search(r"px|rgba|#[0-9a-fA-F]{3,6}|font-size|padding|margin|width|height|opacity|border|flex|grid|z-index|line-height|letter-spacing", l):
        continue
    print(f"{i:5d}| {t[:150]}")
PY

echo
echo "############ 2) SERMAYE MALIYETI %40 — kod ve ekran ############"
grep -n "0\.40\|%40 / yıl\|sermaye_yuku\|yillik_yuk" server_container.mjs shells/bi.js | grep -v "^\s*//" | head -8

echo
echo "############ 3) BRISA SINYALLERI — ureten kod VAR MI? ############"
grep -rn "odeme:2026\|Brisa 1. dönem\|tur='odeme'\|'odeme'" --include=*.py --include=*.mjs --include=*.sh . 2>/dev/null \
  | grep -iv "bak_\|srv_broken\|donmus\|sifir_sabit" | head -8
echo "  ⚠ Ureten kod YOKSA: elle girilmis. O zaman EKRAN KAYNAGINI YAZMALI."

echo
echo "############ 4) AYAR TABLOSU VAR MI? (varsayimlari oraya tasiyacagim) ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT table_name FROM information_schema.tables
 WHERE table_name LIKE '%ayar%' OR table_name LIKE '%setting%' OR table_name LIKE '%config%';"
