#!/usr/bin/env bash
# EFTAL_EPOSTA — dun 23 hata aldi ve kimse ona bir sey demedi.
#
# ⚠ Bir kullanicinin DUYULDUGUNU gormesi, hatanin kendisinden onemli.
#   Fatih Bilen'i kaybettiren sey buydu: sistem yanlis soyledi, kimse aciklamadi.
#
# ⚠ ONCE KAPI: SMTP ayarlari var mi? Yoksa "gonderdim" demem. Gondermedim derim.
set -uo pipefail

echo "############ 1) SMTP — konteynerde ayar var mi? ############"
docker exec krb-assessment sh -c 'echo "  SMTP_HOST=$SMTP_HOST"; echo "  SMTP_PORT=$SMTP_PORT";
  echo "  SMTP_USER=$SMTP_USER"; echo "  SMTP_FROM_EMAIL=$SMTP_FROM_EMAIL";
  echo "  SMTP_PASS: $([ -n \"$SMTP_PASS\" ] && echo VAR || echo YOK)"'

H=$(docker exec krb-assessment sh -c 'echo -n "$SMTP_HOST"')
[ -n "$H" ] || { echo "  ❌ SMTP_HOST YOK — e-posta GONDERILMEDI. Metni asagida biraktim, elle gonderebilirsin."; }

echo
echo "############ 2) GONDER ############"
docker exec -i krb-assessment python3 - <<'PY'
import os, smtplib, sys
from email.message import EmailMessage
from email.utils import formatdate

host = os.environ.get("SMTP_HOST", "")
if not host:
    print("  ❌ SMTP yok — gonderilmedi.")
    sys.exit(0)

METIN = """Merhaba Eftal,

Dün uygulamada aldığın hataları gördük. Sana kimse bir şey söylemeden önce
biz fark ettik ve üçünü de düzelttik. Neyin bozuk olduğunu ve ne yaptığımızı
açıkça yazıyorum, çünkü senin bilmeye hakkın var.

1) İskonto ekranı — açılmıyordu (5 kez denedin, 5'inde de hata verdi)
   Bu ekran kurulduğu günden beri hiç çalışmamış. Veritabanında müşteri
   numarasının tipi yanlış tanımlanmıştı. Senin bir hatan yoktu; ekran
   kimsede çalışmıyordu. Düzeltildi, test ettik, açılıyor.

2) Başka temsilcinin müşterisini açamıyordun (13 kez engellendin)
   Sistem "bu müşteri size atanmamış" diyordu. Böyle bir kural aslında
   hiç konulmamıştı — yazılım bunu kendi kendine varsaymış. Kaldırıldı.
   Artık her müşteriyi açabilir ve düzenleyebilirsin.

   ⚠ Bunun sessiz bir sonucu vardı ve bunu da söylemem lazım:
   Ziyaret kaydettiğinde, formda seçtiğin "nokta durumu" müşteri kartına
   yazılamıyordu. Ziyaretin ve notun kaydoldu — merak etme, hepsi duruyor.
   Ama o seçim düşüyordu ve sana ekranda yine de "✓" gösteriliyordu.
   Yani sistem sana yanlış söyledi. Bunun için özür dileriz.

3) Ziyaret detayı açılmıyordu (yorum kutusu da bu yüzden patlıyordu)
   Uygulamanın istediği bir işlev sunucuda hiç yazılmamıştı. Eklendi.

Ayrıca bir şey daha değişti, işini kolaylaştıracak:

   "Yeni nokta / aktif müşteri / eski nokta" etiketini artık sen elle
   seçmiyorsun. Sistem bunu ERP'deki gerçek satış geçmişinden kendisi
   hesaplıyor ve her veri güncellemesinde kendini yeniliyor.

   Neden: ziyaret ettiğin PRATİK OTOMOTİV'in ERP'de 1.453 faturası var ve
   en son 10 Temmuz'da satış yapılmış — ama ekranda "YENİ NOKTA" yazıyordu.
   TEKROT'un 647 faturası var, o da "yeni nokta" görünüyordu.
   Kontrol ettik: 1.028 müşterinin 674'ü yanlış etiketliydi.
   Sen dört yıllık müşterilerin kapısını "yeni nokta" yazan bir ekranla
   çalıyormuşsun. Artık müşteri kartında etiketin yanında kanıtı da
   göreceksin: kaç fatura, ilk satış, son satış, ciro, bakiye.

Senin yeniden girmen gereken hiçbir şey yok. Düşen bilgi zaten artık
otomatik hesaplanıyor.

Bir şey daha görürsen — çalışmayan, yanlış görünen, mantıksız gelen —
lütfen yaz. Şikayet değil, sistemi düzelten en değerli şey bu.
Dünkü hatalar sayesinde uygulamanın üç ayrı yerindeki bozukluğu bulduk.

Teşekkürler,
Derive Intelligence
"""

msg = EmailMessage()
msg["Subject"] = "Dünkü hatalar düzeltildi — ve neyin bozuk olduğu"
msg["From"] = os.environ.get("SMTP_FROM_EMAIL") or os.environ.get("SMTP_USER")
msg["To"] = "eyildiz@krb.com.tr"
msg["Cc"] = "fatih@deriveglobal.com"
msg["Date"] = formatdate(localtime=True)
msg.set_content(METIN)

port = int(os.environ.get("SMTP_PORT") or 587)
try:
    if port == 465:
        sv = smtplib.SMTP_SSL(host, port, timeout=25)
    else:
        sv = smtplib.SMTP(host, port, timeout=25); sv.starttls()
    if os.environ.get("SMTP_USER"):
        sv.login(os.environ["SMTP_USER"], os.environ.get("SMTP_PASS", ""))
    sv.send_message(msg)
    sv.quit()
    print("  ✅ GONDERILDI -> eyildiz@krb.com.tr (kopya: fatih@deriveglobal.com)")
except Exception as e:
    # ⚠ SUSMAZ. Gonderilmediyse GONDERILMEDI derim.
    print("  ❌ GONDERILEMEDI:", e)
    print("  Metin yukarida; elle gonderilebilir.")
PY
