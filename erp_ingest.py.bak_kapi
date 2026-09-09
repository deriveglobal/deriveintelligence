#!/usr/bin/env python3
"""ERP_INGEST — SUNUCU TARAFI yukleme motoru.

⚠ NEDEN VAR: bugune kadar her dosyayi BEN donusturdum, CSV urettim, scp ettim,
   psql ile yukledim. Fatih bunu yapamaz. Sistem AYDA BIR BANA BAGIMLI kaliyordu.
   Bu, bir demo ile bir urun arasindaki fark.

⚠ ICINE GOMULEN ONARIMLAR (hepsi 13 Temmuz'da aci cekilerek ogrenildi):
   1. TARIH TAKASI — Excel, ERP'nin GG/AA metnini AA/GG sanip gun<=12 olanlari
      TAKAS ETMIS (datetime tipi), gun>12 olanlari METIN birakmis.
      Kanit: her yilin max tarihi tam olarak YYYY-12-12.
      -> datetime ise gun/ay GERI TAKAS. str ise DOGRU.  TAHMIN YOK.
   2. SAYI OLCEGI — Excel bazi Turkce sayilarin ayracini ATIP tam sayi yapmis:
      '932,203' -> int 932203.  Her kolonun ondalik basamagi SABIT.
      -> int / 10**basamak.  ('Price'=3, 'Fiyat'=4, 'Miktar'=2, 'Balance'=2)
   3. TURKCE FORMAT — '1.458,342': nokta BINLIK, virgul ONDALIK.
   4. x10.000 VIRGUL — bazi kolonlarda deger 10.000 kat sisik (kullanilabilir).

⚠ KAPILAR: biri duserse VERI YUKLENMEZ. Eski veri yerinde kalir.
   Ekranda "yeni veri REDDEDILDI, sebep su" yazar.
   Bugun kapilar UC KEZ yanlis veriyi durdurdu.

⚠ HER YUKLEME bi_ingestion_log'a yazar -> monitor gorur.
"""
import openpyxl, sys, os, json, datetime, decimal, hashlib, pathlib, re
import psycopg2, psycopg2.extras

# ⚠ KONTEYNERDE PGHOST/PGPASSWORD YOK. Sadece DATABASE_URL var — ve DOGRU.
#   PGHOST varsayilanini 'krb-assessment-postgres' yazmistim; konteyner aginda
#   servis adi 'postgres'. Ve sifre DATABASE_URL icinde, ayri degiskende degil.
#   Ortamin SOYLEDIGINI oku, ne olmasi gerektigini VARSAYMA.
def _db():
    u = os.getenv("DATABASE_URL", "")
    if u:
        return {"dsn": u}
    return dict(host=os.getenv("PGHOST", "postgres"),
                dbname=os.getenv("PGDATABASE", "assessment_platform"),
                user=os.getenv("PGUSER", "assessment_app"),
                password=os.getenv("PGPASSWORD", ""))

def _baglan():
    d = _db()
    return psycopg2.connect(d["dsn"]) if "dsn" in d else psycopg2.connect(**d)
BUGUN = datetime.date.today()


# ══════════════════════════════════════════════════════════════════════
#  ONARIMLAR
# ══════════════════════════════════════════════════════════════════════
def tarih_onar(v):
    """⚠ Excel, gun<=12 olanlari AA/GG sanip TAKAS ETMIS (datetime).
       gun>12 olanlar gecersiz ay olacagi icin METIN kalmis (dogru).
       Tipten ayirt edilebiliyor -> tahmin YOK."""
    if v is None or v == "":
        return None, "yok"
    if isinstance(v, datetime.datetime):
        v = v.date()
    if isinstance(v, datetime.date):
        try:
            return datetime.date(v.year, v.day, v.month), "takas"
        except ValueError:
            return v, "dokunulmadi"      # takas gecersiz -> zaten dogruydu
    s = str(v).strip()
    for f in ("%d/%m/%Y", "%d.%m.%Y", "%Y-%m-%d", "%d/%m/%y"):
        try:
            return datetime.datetime.strptime(s, f).date(), "metin"
        except ValueError:
            pass
    return None, "okunamadi"


def sayi_onar(v, basamak=2):
    """⚠ Excel bazi Turkce sayilarin AYRACINI ATIP tam sayi yapmis.
       '2,0000' -> int 20000 · '932,203' -> int 932203
       Geri olceklemek icin O KOLONUN ondalik basamak sayisi lazim -> int / 10**basamak.
       Metin ise Turkce cozumle: nokta BINLIK, virgul ONDALIK."""
    if v is None or v == "":
        return 0.0
    if isinstance(v, bool):
        return 0.0
    if isinstance(v, int):
        return float(v) / (10 ** basamak)
    if isinstance(v, (float, decimal.Decimal)):
        return float(v)
    s = str(v).strip().replace("\xa0", "")
    if not s:
        return 0.0
    neg = s.startswith("-")
    s = s.lstrip("-").replace(".", "").replace(",", ".")
    try:
        return -float(s) if neg else float(s)
    except ValueError:
        return 0.0


def basamak_bul(sh, hdr, ornek=800):
    """⚠⚠ ONDALIK BASAMAGI DOSYADAN OKU — elle yazma.

    Excel, Turkce sayilarin ayracini atarken TUM satirlari BOZMAZ:
    bazi hucreler METIN kalir ('1.458,342'). O metin, kolonun ondalik
    basamagini SOYLER. Int hucreleri geri olceklemek icin bu yeterli.

    ⚠ Ben basamaklari ELLE yazmistim (Price=3, Fiyat=4). Kirilgan:
      yeni bir kolon gelirse, ya da SAP formati degisirse, SESSIZCE
      bin kat sapan bir maliyet uretirdi. Dosyadan okumak KENDI KENDINI
      DUZELTIR.

    ⚠ Metin ornegi HIC yoksa (tum hucreler int) basamak BILINEMEZ ->
      None doner ve kolon icin varsayilan kullanilir; ama bu bir RISKTIR
      ve raporlanir.
    """
    say = {h: {} for h in hdr}
    n = 0
    for r in sh.iter_rows(min_row=2, max_row=ornek + 1, values_only=True):
        if not r:
            continue
        n += 1
        for i, h in enumerate(hdr):
            if i >= len(r):
                continue
            v = r[i]
            if isinstance(v, str) and "," in v:
                ond = len(v.rsplit(",", 1)[1])
                if 0 < ond <= 6 and v.rsplit(",", 1)[1].isdigit():
                    say[h][ond] = say[h].get(ond, 0) + 1
    # her kolon icin EN SIK gorulen ondalik basamak
    return {h: (max(d, key=d.get) if d else None) for h, d in say.items()}


def metin(v, uzunluk=None):
    if v is None:
        return ""
    s = str(v).strip()
    return s[:uzunluk] if uzunluk else s


# ══════════════════════════════════════════════════════════════════════
#  DOSYA KAYIT DEFTERI
#  ⚠ Sistem hangi dosyayi bekledigini BILIR. Eksik gelirse SOYLER.
#     Bugun 'account balance'in AYLARDIR gelmedigini TESADUFEN bulduk.
# ══════════════════════════════════════════════════════════════════════
KAYIT = {

  "stok_hareket": {
    "ad": "Stok hareketleri (stockmoving)",
    "imza": ["Belge Türü", "Belge No", "Belge Tarihi", "Giriş Miktarı", "Çıkış Miktarı"],
    "tablo": "bi_stok_hareket",
    "tenant_tip": "uuid",
    # ⚠⚠ ZAMAN SERISI — "ne oldu" der, eskiye EKLENIR.
    #   Son veri 07/12 iken 07/12–10/12 dosyasi gelirse:
    #     DELETE-hepsi -> GECMISI KAYBEDERIZ
    #     hic silme    -> MUKERRER
    #   COZUM: dosyanin [min,max] araligindaki satirlari sil, sonra yukle.
    #          Aralik disi gecmis KORUNUR, cakisma IMKANSIZ.
    "yukleme_modu": "tarih_araligi",
    "tarih_alani": "belge_tarihi",
    "dogal_anahtar": ["belge_no", "belge_tarihi", "kalem_kodu", "depo"],
    "yil_bazli": True,          # ⚠ her yil ayri dosya, hepsi birlikte yuklenir
    "kolonlar": {
      "belge_tarihi"      : ("Belge Türü__TARIH", "Belge Tarihi", "tarih"),
      "belge_turu"        : (None, "Belge Türü", "metin"),
      "belge_no"          : (None, "Belge No", "metin"),
      "muhatap_kodu"      : (None, "Muhatap Kodu", "metin"),
      "muhatap_adi"       : (None, "Muhatap Tanımı", "metin"),
      "satis_calisani"    : (None, "Sales Employee Name", "metin"),
      "depo"              : (None, "Warehouse Name", "metin"),
      "kalem_kodu"        : (None, "Kalem Kodu", "metin"),
      "grup_adi"          : (None, "Group Name", "metin"),
      "kategori"          : (None, "Kategori1 ad", "metin"),
      "marka"             : (None, "Marka ad", "metin"),
      "kalem_tanimi"      : (None, "Kalem Tanımı", "metin"),
      # ⚠ 'Price' = BIRIM maliyet, 3 ondalik
      "birim_maliyet"     : (None, "Price", "sayi3"),
      "giris"             : (None, "Giriş Miktarı", "sayi2"),
      # ⚠ 'Fiyati' FIYAT DEGIL, SATIR TUTARI. 4 ondalik.
      "giris_tutari"      : (None, "Giriş Fiyatı", "sayi4"),
      "cikis"             : (None, "Çıkış Miktarı", "sayi2"),
      "cikis_tutari"      : (None, "Çıkış Fiyatı", "sayi4"),
      "stok_bakiye_tutari": (None, "Stock Balance", "sayi2"),
      "notlar"            : (None, "Remarks", "metin200"),
    },
    "turet": {
      # ⚠ SIRA KRITIK: iadeler ONCE. 'Musteri Faturasi Iadesi' -> SATIS_IADE,
      #   yoksa 'Musteri Faturasi' desenine takilip SATIS sayilir.
      "hareket_sinifi": lambda r: (
        "SATIS_IADE"       if "müşteri faturası iadesi" in r["belge_turu"].lower() else
        "ALIS_IADE"        if ("satıcı faturası iadesi" in r["belge_turu"].lower()
                               or "iptal" in r["belge_turu"].lower()) else
        # ⚠ '162' = maliyet duzeltme (EMANET STOK DUZELTME) — ADET YOK
        # ⚠ '69'  = ithalat maliyet dagitimi (GUMRUK DEPO) — ADET YOK
        "MALIYET_DUZELTME" if r["belge_turu"] in ("162", "69") else
        # ⚠ SAP devreye alma acilis bakiyesi (2021, DEVIR HESABI)
        "ACILIS"           if "açılış" in r["belge_turu"].lower() else
        "TRANSFER"         if "stok nakli" in r["belge_turu"].lower() else
        "SATIS_SEVK"       if "teslimat" in r["belge_turu"].lower() else
        "MAL_GIRISI"       if "mal giriş" in r["belge_turu"].lower() else
        "ALIS_FATURA"      if "satıcı faturası" in r["belge_turu"].lower() else
        "SATIS_FATURA"     if "müşteri faturası" in r["belge_turu"].lower() else
        "CIKIS"            if "mal çıkış" in r["belge_turu"].lower() else
        "IADE"             if "iade" in r["belge_turu"].lower() else "DIGER"),
      "lastik_mi"     : lambda r: "LASTIK" in r["grup_adi"].upper(),
      "sevk_girisi_mi": lambda r: "mal giriş" in r["belge_turu"].lower(),
    },
    "kapilar": [
      ("gelecek_tarih",  lambda R: sum(1 for r in R if r["belge_tarihi"] > BUGUN),
                          0, "Gelecek tarihli satır — tarih onarımı çalışmadı"),
      ("maliyet_tutarsiz", lambda R: sum(
          1 for r in R
          if r["cikis"] > 0 and r["cikis_tutari"] > 0 and r["birim_maliyet"] > 0
          and abs((r["cikis_tutari"]/r["cikis"])/r["birim_maliyet"] - 1) > 0.02),
                          1000, "tutar/adet ≠ birim maliyet — sayı ölçeği yanlış"),
      ("bos_kalem",      lambda R: sum(1 for r in R if not r["kalem_kodu"]),
                          100, "kalem_kodu boş (NOT NULL)"),
      ("diger_sinif",    lambda R: sum(1 for r in R if r["hareket_sinifi"] == "DIGER"),
                          3000, "Tanınmayan belge türü — eşleme eksik"),
    ],
  },

  "cari_bakiye": {
    "ad": "Cari bakiye (account balance)",
    # ⚠ Bu dosya AYLARDIR gelmemisti. Icinde: tedarikci borcu (403,4M) ve
    #   ERP'nin KENDI tedarikci↔musteri eslemesi ('Bagli Musteri Kodu').
    #   Olmadan NET pozisyon hesaplanamaz -> sistem BRUT alacaga duser -> YALAN SOYLER.
    "imza": ["BP Code", "BP Name", "Account Balance", "Bağlı Müşteri Kodu"],
    "tablo": "bi_cari_bakiye",
    "tenant_tip": "uuid",
    # ⚠ ANLIK GORUNTU — "su an ne var" der. Yeni dosya eskisinin YERINE gecer.
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "tedarikci_kodu"  : (None, "BP Code", "metin"),
      "tedarikci_adi"   : (None, "BP Name", "metin"),
      # ⚠ NEGATIF = KRB BORCLU. Isaret KORUNUR.
      "tedarikci_bakiye": (None, "Account Balance", "sayi2"),
      "musteri_kodu"    : (None, "Bağlı Müşteri Kodu", "metin"),
      "musteri_bakiye"  : (None, "Bağlı Müşteri Bakiyesi", "sayi2"),
    },
    "turet": {
      "net_pozisyon": lambda r: r["musteri_bakiye"] + r["tedarikci_bakiye"],
    },
    "kapilar": [
      ("bos_kod", lambda R: sum(1 for r in R if not r["tedarikci_kodu"]),
                  5, "BP Code boş"),
      ("borc_yok", lambda R: 0 if any(r["tedarikci_bakiye"] < 0 for r in R) else 1,
                  0, "Hiç negatif bakiye yok — dosya yanlış olabilir"),
    ],
  },
  "stok_anlik": {
    "ad": "Anlık stok (inventory)",
    "imza": ["Warehouse Name", "Item No.", "In Stock", "Kullanılabilir Miktar"],
    "tablo": "bi_stok_anlik",
    "tenant_tip": "uuid",
    # ⚠ ANLIK GORUNTU — "su an ne var". Yeni dosya eskisinin YERINE gecer.
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "depo"          : (None, "Warehouse Name", "metin"),
      "kalem_kodu"    : (None, "Item No.", "metin"),
      "kalem_tanimi"  : (None, "Item Description", "metin"),
      "grup_adi"      : (None, "Group Name", "metin"),
      "marka"         : (None, "Marka ad", "metin"),
      "sezon"         : (None, "Kategori1 ad", "metin"),
      "kategori2"     : (None, "Kategori2 ad", "metin"),
      "kategori3"     : (None, "Kategori3 ad", "metin"),
      "adet"          : (None, "In Stock", "sayi2"),
      "taahhut"       : (None, "Taahhüt Edilen", "sayi2"),
      # ⚠ "x10.000 bozulmasi" diye AYRI bir hata sandigimiz sey, aslinda
      #   AYNI mekanizmaydi: kaynakta "2,0000" (4 ondalik), Excel ayraci atinca
      #   20000 oldu. basamak_bul() bunu dosyadan okuyup kendiliginden duzeltir.
      "kullanilabilir": (None, "Kullanılabilir Miktar", "sayi4"),
      "liste_fiyati"  : (None, "List Price", "sayi3"),
      "min_seviye"    : (None, "Minimum Inventory Level", "sayi2"),
      "max_seviye"    : (None, "Maximum Inventory Level", "sayi2"),
    },
    "kapilar": [
      ("bos_kalem", lambda R: sum(1 for r in R if not r["kalem_kodu"]), 10,
       "Item No. boş"),
      # ⚠ kullanilabilir <= adet OLMALI. Buyukse olcek yanlis okunmus.
      ("kullanilabilir_asiyor", lambda R: sum(
         1 for r in R if r["adet"] > 0 and r["kullanilabilir"] > r["adet"] * 1.01),
       50, "kullanılabilir > eldeki — sayı ölçeği yanlış"),
    ],
  },

  "musteri_risk": {
    "ad": "Müşteri risk raporu (accountriskreport)",
    "imza": ["Muhatap Kodu", "Muhatap Adı", "Kredi Limiti", "Toplam Risk"],
    "tablo": "bi_musteri_risk",
    "tenant_tip": "uuid",
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "muhatap_kodu"        : (None, "Muhatap Kodu", "metin"),
      "muhatap_adi"         : (None, "Muhatap Adı", "metin"),
      "vergi_no"            : (None, "Vergi No / TCKN", "metin"),
      "vergi_dairesi"       : (None, "Vergi Dairesi", "metin"),
      "grup"                : (None, "Grup", "metin"),
      "odeme_kosulu"        : (None, "Ödeme Koşulu", "metin"),
      "satis_calisani"      : (None, "Satış Çalışanı", "metin"),
      "kredi_limiti"        : (None, "Kredi Limiti", "sayi2"),
      "toplam_risk"         : (None, "Toplam Risk", "sayi4"),
      "vadesi_gecmis"       : (None, "Vadesi Geçmiş Bakiye", "sayi4"),
      "hesap_bakiyesi"      : (None, "Hesap Bakiyesi", "sayi2"),
      "cek_senet_riski"     : (None, "Çek ve Senet Riski", "sayi4"),
      "kullanilabilir_limit": (None, "Kullanılabilir Açık Limit", "sayi4"),
      "taahhut_limiti"      : (None, "Taahhüt Limiti", "sayi2"),
      "dbs_limit"           : (None, "DBS Limit", "sayi4"),
      "odenmemis_cekler"    : (None, "Ödenmemiş Çekler", "sayi4"),
      "odenmemis_senetler"  : (None, "Ödenmemiş Senetler", "sayi4"),
      "bekleyen_siparis"    : (None, "Bekleyen Sipariş Tutarı", "sayi4"),
    },
    "turet": {
      "limit_asimi": lambda r: max(0.0, r["toplam_risk"] - r["kredi_limiti"]),
      "musteri_mi" : lambda r: r["muhatap_kodu"].upper().startswith("M"),
    },
    "kapilar": [
      ("bos_kod", lambda R: sum(1 for r in R if not r["muhatap_kodu"]), 10,
       "Muhatap Kodu boş"),
      # ⚠ Gecikmis, toplam riski asamaz. Asiyorsa olcek ya da kaynak yanlis.
      #   Eski bi_musteri_bakiye tablosunda tam bu vardi: gecikmis 566M, bakiye 11M.
      ("gecikmis_riski_asiyor", lambda R: sum(
         1 for r in R if r["toplam_risk"] > 0
         and r["vadesi_gecmis"] > r["toplam_risk"] * 1.05),
       200, "vadesi geçmiş > toplam risk — imkânsız"),
    ],
  },

  "on_siparis": {
    "ad": "Ön sipariş (winter/summer order)",
    "imza": ["Alt. Ebat", "Marka", "Mevsim"],
    "tablo": "bi_on_siparis",
    "tenant_tip": "uuid",
    "yukleme_modu": "tam_degistir",
    "kolonlar": {
      "ebat"         : (None, "Alt. Ebat", "metin"),
      "marka"        : (None, "Marka", "metin"),
      "mevsim"       : (None, "Mevsim", "metin"),
      "siparis_adet" : (None, "Genel Toplam Sipariş", "sayi2"),
    },
    "kapilar": [
      ("bos_ebat", lambda R: sum(1 for r in R if not r["ebat"]), 20, "Ebat boş"),
    ],
  },

  "satis_faturalari": {
    "ad": "Satış faturaları (full sales)",
    "imza": ["Belge Numarası", "Kalem Numarası", "Miktar", "Satır Toplamı", "Satış Kanalı Tanım"],
    "tablo": "bi_satis_faturalari",
    "tenant_tip": "text",          # ⚠ BU TABLO TEXT. Digerleri UUID. Sema tutarsizligi.
    "yukleme_modu": "tarih_araligi",
    "tarih_alani": "fatura_tarihi",
    "dogal_anahtar": ["fatura_no", "kalem_kodu", "fatura_tarihi"],
    # ⚠ 'Miktar' kolonunda METIN ORNEGI YOK -> olcek bilinemez.
    #   KIMLIKTEN COZ: Miktar = Satir Toplami / Indirim Sonrasi Fiyat
    "olcek_coz": {"Miktar": ("Satır Toplamı", "İndirim Sonrası Fiyat")},
    "kolonlar": {
      "fatura_tarihi"  : (None, "Kayıt Tarihi", "tarih"),
      "vade_tarihi"    : (None, "Vade Tarihi", "tarih"),
      "fatura_no"      : (None, "Belge Numarası", "metin"),
      "depo_adi"       : (None, "Depo Adı", "metin"),
      "sube"           : (None, "Sube Adı", "metin"),
      "fatura_kesen"   : (None, "Oluşturan", "metin"),
      "satis_temsilcisi": (None, "Satış Çalışanı", "metin"),
      "musteri_kodu"   : (None, "Muhatap Kodu", "metin"),
      "musteri_adi"    : (None, "Muhatap Adı", "metin"),
      "satis_kanali"   : (None, "Satış Kanalı Tanım", "metin"),
      "sehir"          : (None, "Şehir Adı", "metin"),
      "odeme_kosulu"   : (None, "Ödeme Koşulu", "metin"),
      "kalem_kodu"     : (None, "Kalem Numarası", "metin"),
      "kalem_tanimi"   : (None, "Kalem Tanımı", "metin"),
      "grup_adi"       : (None, "Kalem Grubu", "metin"),
      "kategori"       : (None, "Kategori1", "metin"),
      "kategori2"      : (None, "Kategori2", "metin"),
      "kategori3"      : (None, "Kategori3", "metin"),
      "ebat"           : (None, "Ebat", "metin"),
      "jant_capi"      : (None, "Jant Çapı", "metin"),
      "marka"          : (None, "Marka", "metin"),
      "vergi_no"       : (None, "Vergi No", "metin"),
      "vergi_dairesi"  : (None, "Vergi Dairesi", "metin"),
      "tc_no"          : (None, "TC No", "metin"),
      "para_birimi"    : (None, "Para Birimi", "metin"),
      "miktar"         : (None, "Miktar", "sayi4"),
      # ⚠⚠ 'Birim Fiyat' LISTE FIYATIDIR, satis fiyati DEGIL.
      #   20 adet × Birim Fiyat 3.083 = 61.666 ama Satir Toplami 33.333.
      #   Gercek fiyat 'Indirim Sonrasi Fiyat'ta (1.666,67 × 20 = 33.333 ✓).
      #   Bunu fark etmeseydim marji %52 hesaplardim; gercek %10,9.
      "birim_fiyat"    : (None, "İndirim Sonrası Fiyat", "sayi4"),
      "satir_tutar"    : (None, "Satır Toplamı", "sayi4"),
    },
    "kapilar": [
      # ⚠ KIMLIK 1 — dosyanin kendi ic tutarliligi. %99,7 tutuyordu.
      ("kimlik_bozuk", lambda R: sum(
         1 for r in R
         if r["miktar"] > 0 and r["birim_fiyat"] > 0 and r["satir_tutar"] > 0
         and abs(r["satir_tutar"] / (r["miktar"] * r["birim_fiyat"]) - 1) > 0.02),
       500, "Satır Toplamı ≠ Miktar × Fiyat — sayı ölçeği yanlış"),
      ("gelecek_tarih", lambda R: sum(1 for r in R if r["fatura_tarihi"] > BUGUN),
       0, "Gelecek tarihli fatura — tarih onarımı çalışmadı"),
      ("bos_kalem", lambda R: sum(1 for r in R if not r["kalem_kodu"]),
       50, "Kalem Numarası boş"),
      # ⚠ Vade, faturadan ONCE olamaz. 2021-2025'te 7.877 ters vade bulmustuk.
      ("ters_vade", lambda R: sum(
         1 for r in R if r["vade_tarihi"] and r["fatura_tarihi"]
         and r["vade_tarihi"] < r["fatura_tarihi"]),
       500, "Vade tarihi faturadan önce — tarih bozulması"),
    ],
  },

  "tedarikci_faturalari": {
    "ad": "Tedarikçi faturaları (full tedarikci)",
    "imza": ["Posting Date", "Document Number", "Customer/Vendor Code", "Item No.", "Quantity"],
    "tablo": "bi_tedarikci_faturalari",
    "tenant_tip": "uuid",
    "yukleme_modu": "tarih_araligi",
    "tarih_alani": "fatura_tarihi",
    "dogal_anahtar": ["fatura_no", "kalem_kodu", "fatura_tarihi"],
    # ⚠ KIMLIKTEN COZ: Quantity = Row Total / Unit Price
    "olcek_coz": {"Quantity": ("Row Total", "Unit Price")},
    "kolonlar": {
      "fatura_tarihi"        : (None, "Posting Date", "tarih"),
      "fatura_no"            : (None, "Document Number", "metin"),
      "tedarikci_fatura_no"  : (None, "Customer/Vendor Ref. No.", "metin"),
      "satin_alma_siparis_no": (None, "Satın Alma Sipariş No", "metin"),
      "sube"                 : (None, "Branch Name", "metin"),
      "tedarikci_kodu"       : (None, "Customer/Vendor Code", "metin"),
      "tedarikci_adi"        : (None, "Customer/Vendor Name", "metin"),
      "kalem_kodu"           : (None, "Item No.", "metin"),
      "kalem_tanimi"         : (None, "Item Description", "metin"),
      "grup_adi"             : (None, "Group Name", "metin"),
      "kategori"             : (None, "Kategori1 ad", "metin"),
      "jant_capi"            : (None, "Lastik Jant Çapı", "metin"),
      "marka"                : (None, "Marka ad", "metin"),
      "vade_turu"            : (None, "Payment Terms Code", "metin"),
      "miktar"               : (None, "Quantity", "sayi2"),
      # ⚠⚠ 'Unit Price' SATIR ISKONTOSUNDAN ONCEKI FIYAT — GERCEK ODENEN DEGIL.
      #   Kimlik: Row Total = Qty × Unit Price × (1 − Discount%)   -> %97,8 tutuyor
      #           Row Total = Qty × Unit Price                     -> %46,0  (yalan)
      #   Ornek: 1 adet, Unit Price 300, satir iskontosu %35 -> gercek 195.
      #   ⚠ Bu kolonu 'birim_fiyat_kdv_haric' diye yuklemistik -> "son alis fiyati"
      #     diye kullandigimiz HER RAKAM iskonto oncesi, yani SISKIN'di.
      #     Stok degerlemesi (268,5M), maliyet karsilastirmalari, marka sapma
      #     analizi — hepsi bu sisik fiyata dayaniyordu.
      #   ✅ GERCEK FIYAT: Row Total / Quantity  (turetiliyor, asagida)
      "satir_kdv_haric"      : (None, "Row Total", "sayi2"),
      "satir_kdv_dahil"      : (None, "Gross Total", "sayi2"),
      "satir_iskonto_pct"    : (None, "Discount % per Row", "sayi4"),
      "liste_birim_fiyat"    : (None, "Unit Price", "sayi3"),
    },
    "turet": {
      # ⚠ GERCEK ODENEN BIRIM FIYAT — iskonto DAHIL
      "birim_fiyat_kdv_haric": lambda r: (r["satir_kdv_haric"] / r["miktar"]) if r["miktar"] > 0 else 0.0,
      "birim_fiyat_kdv_dahil": lambda r: (r["satir_kdv_dahil"] / r["miktar"]) if r["miktar"] > 0 else 0.0,
    },
    "kapilar": [
      # ⚠ DOGRU KIMLIK: iskonto DAHIL. Iskontosuz hali %46 tutuyordu (yalan).
      ("kimlik_bozuk", lambda R: sum(
         1 for r in R
         if r["miktar"] > 0 and r["liste_birim_fiyat"] > 0 and r["satir_kdv_haric"] > 0
         and abs(r["satir_kdv_haric"] /
                 (r["miktar"] * r["liste_birim_fiyat"] * (1 - r["satir_iskonto_pct"]/100.0)) - 1) > 0.02),
       500, "Row Total ≠ Qty × Unit Price × (1−iskonto) — sayı ölçeği yanlış"),
      ("gelecek_tarih", lambda R: sum(1 for r in R if r["fatura_tarihi"] > BUGUN),
       0, "Gelecek tarihli fatura"),
      # ⚠ KDV dahil, haricten KUCUK olamaz.
      ("kdv_ters", lambda R: sum(
         1 for r in R if r["satir_kdv_haric"] > 0
         and 0 < r["satir_kdv_dahil"] < r["satir_kdv_haric"] * 0.99),
       100, "KDV dahil < KDV hariç — imkânsız"),
    ],
  },

}


# ══════════════════════════════════════════════════════════════════════
def tip_tani(hdr):
    """⚠ Dosya tipini BASLIKLARINDAN tani. Dosya adina GUVENME —
       kullanici 'kopya (2).xlsx' diye yukleyebilir."""
    h = set(x for x in hdr if x)
    for tip, k in KAYIT.items():
        if all(im in h for im in k["imza"]):
            return tip
    return None


def oku(yol):
    wb = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    sh = wb.active
    it = sh.iter_rows(min_row=1, values_only=True)
    hdr = [metin(x) for x in next(it)]
    tip = tip_tani(hdr)
    if not tip:
        wb.close()
        return None, None, {"basliklar": hdr}
    k = KAYIT[tip]
    ix = {h: i for i, h in enumerate(hdr)}

    # ⚠⚠ ONDALIK BASAMAGI DOSYADAN OKU. Elle yazmak kirilgan:
    #    yeni kolon ya da format degisikliginde SESSIZCE bin kat sapardi.
    wb2 = openpyxl.load_workbook(yol, read_only=True, data_only=True)
    basamaklar = basamak_bul(wb2.active, hdr)
    wb2.close()

    # ⚠⚠ OLCEK BILINMIYORSA — ONCE KIMLIKTEN COZ, sonra pes et.
    #   'Bilmiyorsan dokunma' kurali DOGRU ama EKSIK: once COZMEYE CALIS.
    #   Verinin kendi FAZLALIGI cozumu tasiyor: ayni bilgi uc kolonda var
    #   (Satir Toplami = Miktar × Fiyat), biri bilinmiyorsa digerinden TURETILIR.
    #   Miktar kolonunda metin ornegi YOKTU; kimlikle cozulunce 4 ondalik cikti
    #   ve 8.275 satirda oran TAM 10.000 oldu. Tahmin degil, TURETME.
    for hedef, (pay, bolen) in (k.get("olcek_coz") or {}).items():
        if basamaklar.get(hedef) is not None:
            continue
        import collections as _c, math as _m
        say = _c.Counter()
        wb3 = openpyxl.load_workbook(yol, read_only=True, data_only=True)
        for i2, r2 in enumerate(wb3.active.iter_rows(min_row=2, values_only=True)):
            if i2 > 20000:
                break
            if not r2 or hedef not in ix or pay not in ix or bolen not in ix:
                break
            mv = r2[ix[hedef]]
            pv = sayi_onar(r2[ix[pay]],   basamaklar.get(pay)   or 2)
            bv = sayi_onar(r2[ix[bolen]], basamaklar.get(bolen) or 2)
            if isinstance(mv, int) and pv > 0 and bv > 0:
                gercek = pv / bv
                if gercek > 0:
                    o = round(mv / gercek)
                    if o in (1, 10, 100, 1000, 10000, 100000):
                        say[o] += 1
        wb3.close()
        if say:
            en = say.most_common(1)[0][0]
            basamaklar[hedef] = int(round(_m.log10(en)))

    satir, istat = [], {"takas": 0, "metin": 0, "okunamadi": 0, "dokunulmadi": 0, "yok": 0,
                        "basamaklar": {h: b for h, b in basamaklar.items() if b is not None},
                        "olcek_kimlikten": [h for h in (k.get("olcek_coz") or {})
                                            if basamaklar.get(h) is not None],
                        "basamagi_bilinmeyen": []}

    for r in it:
        if not r or all(x is None for x in r):
            continue
        d = {}
        atla = False
        for alan, (_, kolon, tur) in k["kolonlar"].items():
            v = r[ix[kolon]] if kolon in ix else None
            if tur == "tarih":
                t, kay = tarih_onar(v)
                istat[kay] = istat.get(kay, 0) + 1
                if t is None:
                    atla = True
                d[alan] = t
            elif tur.startswith("sayi"):
                # ⚠⚠ BILMIYORSAN DOKUNMA.
                #   Dosyadan okunan basamak KAZANIR (kendi kendini duzeltir).
                #   Metin ornegi YOKSA olcek BILINEMEZ -> 0 basamak (dokunma).
                #   Yanlis olceklemek, hic olceklememekten KOTUDUR:
                #   'Genel Toplam Siparis' kolonunda varsayilanim 2'ydi ve
                #   1.588 adet siparisi 15,88'e bolecekti. Kapi yoktu, motor
                #   KENDI BILMEDIGINI SOYLEDI ve oyle yakalandi.
                b = basamaklar.get(kolon)
                if b is None:
                    b = 0
                    if kolon not in istat["basamagi_bilinmeyen"]:
                        istat["basamagi_bilinmeyen"].append(kolon)
                d[alan] = sayi_onar(v, b)
            elif tur == "metin200":
                d[alan] = metin(v, 200)
            else:
                d[alan] = metin(v)
        if atla:
            continue
        for alan, fn in (k.get("turet") or {}).items():
            d[alan] = fn(d)
        satir.append(d)
    wb.close()
    return tip, satir, istat


def kapilari_kos(tip, satir):
    """⚠ KAPI DUSERSE VERI YUKLENMEZ. Eski veri yerinde kalir.
       Bugun kapilar UC KEZ yanlis veriyi durdurdu."""
    sonuc = []
    for ad, fn, esik, aciklama in KAYIT[tip]["kapilar"]:
        try:
            v = fn(satir)
        except Exception as e:
            v, aciklama = -1, f"kapı çalışmadı: {e}"
        gecti = (v <= esik)
        sonuc.append({"kapi": ad, "deger": v, "esik": esik,
                      "gecti": gecti, "aciklama": aciklama})
    return sonuc


def mukerrer_bul(tip, satir):
    """⚠ DOSYANIN KENDI ICINDEKI mukerrer. ERP export'u ayni belgeyi iki kez
       verebilir (customercollection'da KARTEZYEN CARPIM bulmustuk: tek fatura
       235 satir). Bu bir ERP sorunudur ve SOYLENMELIDIR."""
    anahtar = KAYIT[tip].get("dogal_anahtar")
    if not anahtar:
        return 0, []
    gorulen, mukerrer = {}, []
    for r in satir:
        k = tuple(str(r.get(a, "")) for a in anahtar)
        if k in gorulen:
            gorulen[k] += 1
            if len(mukerrer) < 5:
                mukerrer.append(dict(zip(anahtar, k)))
        else:
            gorulen[k] = 1
    return sum(v - 1 for v in gorulen.values() if v > 1), mukerrer


def yukle(yol, tenant_id):
    tip, satir, istat = oku(yol)
    if not tip:
        return {"ok": False, "hata": "Dosya tipi tanınmadı",
                "ipucu": "Beklenen dosyalar: " + ", ".join(k["ad"] for k in KAYIT.values())}
    if not satir:
        return {"ok": False, "tip": tip, "hata": "Dosya boş"}

    k = KAYIT[tip]
    mod = k.get("yukleme_modu", "tam_degistir")

    # ⚠ DOSYA ICI MUKERRER — ERP'nin kendi sorunu, gizlenmez.
    muk_adet, muk_ornek = mukerrer_bul(tip, satir)

    kapilar = kapilari_kos(tip, satir)
    dusenler = [g for g in kapilar if not g["gecti"]]
    if dusenler:
        # ⚠ REDDET. Ve NEDEN reddettigini SOYLE. Eski veri YERINDE KALIR.
        return {"ok": False, "tip": tip, "ad": k["ad"], "satir": len(satir),
                "hata": "Kapı düştü — veri YÜKLENMEDİ, eski veri yerinde duruyor",
                "kapilar": kapilar, "dusenler": dusenler,
                "mukerrer": muk_adet}

    alanlar = list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys())
    cast = "::uuid" if k["tenant_tip"] == "uuid" else ""

    # ⚠⚠ CAKISMA YONETIMI — bugunun en kritik tasarim karari.
    #   Son veri 07/12 iken 07/12–10/12 kapsayan dosya gelirse, DELETE-hepsi
    #   yaparsam GECMISI KAYBEDERIM; hic silmezsem MUKERRER olur.
    #   COZUM: TARIH ARALIGI DEGISTIRME.
    #     zaman serisi -> yeni dosyanin [min,max] araligindaki satirlar silinir,
    #                     aralik disi GECMIS KORUNUR. Cakisma IMKANSIZ.
    #     anlik goruntu -> tam degistir ("su an ne var" der, eskisinin yerine gecer)
    tarih_alani = k.get("tarih_alani")
    aralik = None
    if mod == "tarih_araligi" and tarih_alani:
        t = [r[tarih_alani] for r in satir if r.get(tarih_alani)]
        aralik = (min(t), max(t)) if t else None

    cn = _baglan()
    silinen = 0
    try:
        with cn, cn.cursor() as cur:
            if mod == "tarih_araligi" and aralik:
                cur.execute(
                    f"DELETE FROM {k['tablo']} WHERE tenant_id=%s{cast} "
                    f"AND {tarih_alani} BETWEEN %s AND %s",
                    (tenant_id, aralik[0], aralik[1]))
                silinen = cur.rowcount
            else:
                cur.execute(f"DELETE FROM {k['tablo']} WHERE tenant_id=%s{cast}", (tenant_id,))
                silinen = cur.rowcount

            psycopg2.extras.execute_values(
                cur,
                f"INSERT INTO {k['tablo']} (tenant_id, {', '.join(alanlar)}) VALUES %s",
                [tuple([tenant_id] + [r[a] for a in alanlar]) for r in satir],
                template="(%s" + cast + "," + ",".join(["%s"] * len(alanlar)) + ")",
                page_size=2000)

            # ⚠ KAPI: yukleme SONRASI mukerrer kalmis mi? (aralik disi cakisma)
            if mod == "tarih_araligi" and k.get("dogal_anahtar"):
                da = ", ".join(k["dogal_anahtar"])
                cur.execute(
                    f"SELECT count(*) FROM (SELECT {da} FROM {k['tablo']} "
                    f"WHERE tenant_id=%s{cast} GROUP BY {da} HAVING count(*)>1) x",
                    (tenant_id,))
                kalan = cur.fetchone()[0]
            else:
                kalan = 0

            cur.execute("""
              INSERT INTO bi_ingestion_log
                (tenant_id, query_type, export_date, received_at, processed_at,
                 row_count_raw, row_count_kept, status, ingest_version)
              VALUES (%s::uuid, %s, CURRENT_DATE, now(), now(), %s, %s, 'ok', 'erp_ingest_v1')
            """, (tenant_id, tip, len(satir) + muk_adet, len(satir)))
    finally:
        cn.close()

    # ⚠ TURET_SONRASI — yeni veri geldi, turetilmis tablolar YENILENMELI.
    #   Yoksa yukleme "calisir" ama EKRAN ESKI VERIYI gosterir: sessiz yalan.
    try:
        t = turet(tenant_id, tip)
    except Exception as e:
        t = {"turetilen": [], "uyari": [f"⚠ türetme hatası: {str(e)[:160]}"]}

    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),
            "turetme": t,
            "mod": mod,
            "aralik": [str(aralik[0]), str(aralik[1])] if aralik else None,
            "silinen": silinen,
            "tarih_onarim": istat,
            # ⚠ MUKERRER GIZLENMEZ — ERP'nin sorunu ama kullanici BILMELI
            # ⚠ Bu bir SORUN DEGIL: ayni belge/kalem/depo birden fazla satirda
            #   olabilir (parti, lot, farkli fiyat). Cakismayi TARIH ARALIGI
            #   DEGISTIRME cozuyor; bu sayi sadece BILGI.
            "cok_satirli_belge": muk_adet,
            "ornek": muk_ornek,
            "yukleme_sonrasi_mukerrer": kalan,
            "kapilar": kapilar}


def kuru(yol):
    """⚠ KURU MOD — veritabanina DOKUNMAZ. Sadece oku, onar, kapilari kos.
       Motoru canliya baglamadan once DOGRULAMAK icin."""
    tip, satir, istat = oku(yol)
    if not tip:
        return {"ok": False, "hata": "Dosya tipi tanınmadı"}
    muk, ornek = mukerrer_bul(tip, satir)
    kapilar = kapilari_kos(tip, satir)
    k = KAYIT[tip]
    ta = k.get("tarih_alani")
    t = [r[ta] for r in satir if ta and r.get(ta)] if ta else []
    return {"ok": all(g["gecti"] for g in kapilar),
            "tip": tip, "ad": k["ad"], "mod": k.get("yukleme_modu"),
            "satir": len(satir),
            "aralik": [str(min(t)), str(max(t))] if t else None,
            "tarih_onarim": istat,
            "dosya_ici_mukerrer": muk,
            "kapilar": kapilar}

if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--kuru":
        print(json.dumps(kuru(sys.argv[2]), ensure_ascii=False, default=str, indent=2))
    elif len(sys.argv) >= 3:
        print(json.dumps(yukle(sys.argv[1], sys.argv[2]), ensure_ascii=False, default=str))
    else:
        sys.exit("kullanım: erp_ingest.py --kuru <dosya.xlsx>  |  erp_ingest.py <dosya.xlsx> <tenant_id>")


# ══════════════════════════════════════════════════════════════════════
#  TURET_SONRASI — yukleme bitince turetilmis tablolari YENIDEN KUR
#
#  ⚠ ONCEDEN YENILENMIYORDU: yeni veri geliyordu ama bi_marj_fact ve
#    sinyaller ESKI kaliyordu. Yani yukleme "calisiyor" ama EKRAN ESKI
#    VERIYI gosteriyordu. Bu, "yuklendi" demenin EN KOTU turu — sessiz yalan.
#
#  ⚠ MUTABAKAT KAPISI: kup marji, bagimsiz dogrulanmis degerden 3 puandan
#    fazla saparsa YENI KUP KURULMAZ ve ESKISI KALIR. Bozuk bir kup, eski
#    bir kupten kotudur.
# ══════════════════════════════════════════════════════════════════════
BAGIMLILIK = {
    "stok_hareket"        : ["maliyet_ay", "marj_fact"],
    "tedarikci_faturalari": ["maliyet_sku", "marj_fact"],
    "satis_faturalari"    : ["marj_fact"],
    "musteri_risk"        : ["sinyal_kredi"],
    "cari_bakiye"         : ["sinyal_kredi"],
}

SQL_TURET = {
  "maliyet_ay": """
    DROP TABLE IF EXISTS bi_maliyet_ay CASCADE;
    CREATE TABLE bi_maliyet_ay AS
    SELECT tenant_id, date_trunc('month', belge_tarihi)::date AS ay, kalem_kodu,
           sum(cikis_tutari)/NULLIF(sum(cikis),0) AS birim_maliyet, sum(cikis) AS adet
      FROM bi_stok_hareket
     WHERE tenant_id=%(t)s::uuid AND cikis>0 AND cikis_tutari>0
       -- ⚠ SATILAN MALIN MALIYETI, SATIS HAREKETINDEN GELIR.
       --   Transfer/mal girisi/iade SATIS DEGIL; ortalamaya karisinca
       --   kup marji %%0,9 cikiyordu (gercek %%8,3).
       AND hareket_sinifi IN ('SATIS_SEVK','SATIS_FATURA')
     GROUP BY 1,2,3;
    CREATE INDEX ON bi_maliyet_ay(tenant_id, ay, kalem_kodu);
  """,
  "maliyet_sku": """
    DROP TABLE IF EXISTS bi_maliyet_sku CASCADE;
    CREATE TABLE bi_maliyet_sku AS
    SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
           bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS birim_maliyet
      FROM bi_tedarikci_faturalari
     WHERE tenant_id=%(t)s::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
     ORDER BY 1, fatura_tarihi DESC;
    CREATE INDEX ON bi_maliyet_sku(sku);
  """,
  "marj_fact": """
    DROP TABLE IF EXISTS bi_marj_fact_yeni;
    CREATE TABLE bi_marj_fact_yeni AS
    SELECT f.tenant_id, date_trunc('month', f.fatura_tarihi)::date AS ay,
           f.sube, f.satis_kanali, f.sehir, f.satis_temsilcisi,
           upper(f.marka) AS marka, f.ebat, bi_ebat_norm(f.ebat) AS ebat_norm,
           f.kategori, f.jant_capi, f.musteri_kodu, f.musteri_adi, f.kalem_kodu,
           max(f.kalem_tanimi) AS kalem_tanimi,
           sum(f.miktar) AS adet, sum(f.satir_tutar) AS ciro,
           sum(f.satir_tutar)/NULLIF(sum(f.miktar),0) AS ort_fiyat,
           COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet)) AS birim_maliyet,
           CASE WHEN max(ma.birim_maliyet) IS NOT NULL THEN 'satis_hareketi'
                WHEN max(ms.birim_maliyet) IS NOT NULL THEN 'son_alis'
                ELSE 'yok' END AS maliyet_kaynak,
           COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar) AS smm,
           sum(f.satir_tutar) - COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar) AS brut_kar,
           100.0*(sum(f.satir_tutar) - COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar))
                /NULLIF(sum(f.satir_tutar),0) AS marj_pct
      FROM bi_satis_faturalari f
      LEFT JOIN bi_maliyet_ay  ma ON ma.tenant_id=f.tenant_id::uuid
                                 AND ma.ay = date_trunc('month', f.fatura_tarihi)::date
                                 AND ma.kalem_kodu = f.kalem_kodu
      LEFT JOIN bi_maliyet_sku ms ON ms.sku = bi_sku_norm(f.kalem_kodu)
     WHERE f.tenant_id=%(t)s::text AND f.miktar>0
       AND f.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')
       AND f.fatura_tarihi >= CURRENT_DATE-730
     GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14;
  """,
  "sinyal_kredi": """
    DELETE FROM bi_sinyal WHERE tenant_id=%(t)s::uuid AND tur='kredi_asimi';
    INSERT INTO bi_sinyal (tenant_id, tur, anahtar, baslik, ozet, tutar_tl, oda, eylem_var, detay, durum)
    SELECT %(t)s::uuid, 'kredi_asimi', 'net_limit:' || b.musteri_kodu,
           left(b.tedarikci_adi, 30) ||
           CASE WHEN r.kredi_limiti > 1000
                THEN ' — net risk limitin ' || round(b.net_pozisyon/r.kredi_limiti,1) || ' katı'
                ELSE ' — kredi limiti TANIMSIZ' END,
           'net ' || round(b.net_pozisyon/1e6,1) || 'M · ' ||
           CASE WHEN r.kredi_limiti > 1000 THEN 'limit ' || round(r.kredi_limiti/1e6,2) || 'M'
                ELSE 'limit yok' END ||
           ' · brüt alacak ' || round(b.musteri_bakiye/1e6,1) || 'M' ||
           CASE WHEN b.tedarikci_bakiye < -1e5
                THEN ' · KRB borcu ' || round(abs(b.tedarikci_bakiye)/1e6,1) || 'M' ELSE '' END,
           b.net_pozisyon, 'nakit', true,
           jsonb_build_object('musteri', b.tedarikci_adi, 'net', b.net_pozisyon,
                              'brut', b.musteri_bakiye, 'krb_borcu', b.tedarikci_bakiye,
                              'limit', r.kredi_limiti),
           'acik'
      FROM bi_cari_bakiye b
      JOIN bi_musteri_risk r ON r.tenant_id=b.tenant_id AND r.muhatap_kodu=b.musteri_kodu
     WHERE b.tenant_id=%(t)s::uuid AND b.net_pozisyon > 2e6
       -- ⚠ NET pozisyon. Brut alacak YANILTICI: MUTAFLAR brut 47,6M ama
       --   KRB'nin ona borcu 46,6M -> net 1,0M, TAM LIMITTE. Yonetilen mahsuplasma.
       AND (r.kredi_limiti <= 1000 OR b.net_pozisyon > r.kredi_limiti * 1.5);
  """,
}


def turet(tenant_id, tip):
    """⚠ Yukleme sonrasi turetilmis tablolari yeniden kur.
       MUTABAKAT KAPISI gecmezse ESKI KUP KALIR."""
    isler = BAGIMLILIK.get(tip, [])
    if not isler:
        return {"turetilen": [], "not": "bu dosya turetilmis tablo etkilemiyor"}
    sonuc, uyari = [], []
    cn = _baglan()
    try:
        with cn, cn.cursor() as cur:
            for i in isler:
                if i == "marj_fact":
                    continue                     # en sona, kapiyla
                cur.execute(SQL_TURET[i], {"t": tenant_id})
                sonuc.append(i)

            if "marj_fact" in isler:
                cur.execute(SQL_TURET["marj_fact"], {"t": tenant_id})
                # ⚠⚠ MUTABAKAT KAPISI — bagimsiz dogrulanmis %8,3 ile 3 puan icinde tutmali
                cur.execute("""
                    SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)
                      FROM bi_marj_fact_yeni
                     WHERE ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok'""")
                m = cur.fetchone()[0]
                if m is None or abs(float(m) - 8.3) > 3:
                    cur.execute("DROP TABLE IF EXISTS bi_marj_fact_yeni")
                    uyari.append(
                        f"⚠ MARJ KUBU KURULMADI: yeni kup %{m} veriyor, "
                        f"beklenen %8,3 (±3). ESKI KUP YERINDE KALDI. "
                        f"Bozuk bir kup, eski bir kupten kotudur.")
                else:
                    cur.execute("DROP TABLE IF EXISTS bi_marj_fact")
                    cur.execute("ALTER TABLE bi_marj_fact_yeni RENAME TO bi_marj_fact")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, ay DESC)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, ebat_norm, marka)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, sube, satis_kanali)")
                    cur.execute("CREATE INDEX ON bi_marj_fact(tenant_id, satis_temsilcisi)")
                    sonuc.append(f"marj_fact (%{m})")
    finally:
        cn.close()
    return {"turetilen": sonuc, "uyari": uyari}
