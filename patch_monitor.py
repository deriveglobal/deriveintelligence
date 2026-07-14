#!/usr/bin/env python3
"""MONITOR_V2 — monitor LOGU degil, TABLOLARIN KENDISINI okusun.

⚠ ESKI HALI: bi_ingestion_log'u query_type bazinda gruplayip yasina bakiyordu.
   Log = yukleyicinin SOYLEDIGI sey.  Tablo = GERCEKTE OLAN sey.
   Yeni yukleyiciler loga YAZMIYORDU -> log'da Haziran'in emekli kayitlari kaldi
   -> monitor HAKLI olarak "31 gundur beslenmiyor" dedi -> 4 SAHTE crit.

⚠ LOGA SATIR EKLEMEK COZUM DEGIL, YAMA:
   yarin yeni dosya yuklenince yukleyici yine loga yazmaz, monitor yine sahte alarm
   verir, ve biri yine ELLE kayit acar. Kestirme.

✅ KALICI COZUM: monitor GERCEGI izlesin.
   Her beslemenin HEDEF TABLOSUNDAKI son veri tarihine baksin.
   O zaman kimin log yazip yazmadigi ONEMSIZLESIR, ve yeni tablo eklendiginde
   de kendiliginden calisir.

⚠ TAZELIK OLCUSU: export_date varsa O (verinin ait oldugu tarih),
   yoksa ingested_at (yuklenme zamani). Ikisi FARKLI seyler:
   dun yuklenmis ama 3 ay onceki veriyi tasiyan bir dosya TAZE DEGILDIR.
"""
import re, sys, pathlib

p = pathlib.Path("ops_monitor.py")
src = p.read_text(encoding="utf-8")
if "MONITOR_V2" in src:
    sys.exit("ZATEN YAMALI")

# eski: bi_ingestion_log'dan GROUP BY query_type
eski = '''                     "FROM bi_ingestion_log GROUP BY query_type"):'''
if eski not in src:
    # tam satiri bul
    m = re.search(r'for [^\n]*bi_ingestion_log GROUP BY query_type[^\n]*\n', src)
    if not m:
        sys.exit("❌ anchor yok: bi_ingestion_log GROUP BY query_type")

# ingest kontrol blogunu KOMPLE degistir
m = re.search(
    r'(iw = float\(ayar\("ingest_warn_days".*?)\nif ing:\n(.*?)\n\nfor kaynak, hrs in',
    src, re.S)
if not m:
    sys.exit("❌ ingest blogu bulunamadi")

yeni_blok = '''iw = float(ayar("ingest_warn_days", "2")); ic = float(ayar("ingest_crit_days", "5"))

# ─── MONITOR_V2 ─────────────────────────────────────────────────────────────
# ⚠ LOGU DEGIL, TABLOLARIN KENDISINI oku.
#   Log = yukleyicinin SOYLEDIGI. Tablo = GERCEKTE OLAN.
#   Yeni yukleyici loga yazmazsa eski hali sahte crit uretiyordu.
#   Bu liste tek dogruluk kaynagi: yeni besleme eklenince BURAYA eklenir.
#
# ⚠ TAZELIK: export_date varsa O (verinin AIT OLDUGU tarih), yoksa ingested_at.
#   Dun yuklenmis ama 3 ay onceki veriyi tasiyan dosya TAZE DEGILDIR.
BESLEMELER = [
    # (ad,               tablo,                 tarih_kolonu,   yedek_kolon)
    ("satis_faturalari", "bi_satis_faturalari", "export_date",  None),
    ("tedarikci_fatura", "bi_tedarikci_faturalari", "export_date", None),
    ("stok_anlik",       "bi_stok_anlik",       "export_date",  "ingested_at"),
    ("musteri_risk",     "bi_musteri_risk",     "export_date",  "ingested_at"),
    ("stok_hareket",     "bi_stok_hareket",     None,           "ingested_at"),
    ("fatura_tahsilat",  "bi_fatura_tahsilat",  None,           "ingested_at"),
    ("on_siparis",       "bi_on_siparis",       None,           "ingested_at"),
]
ing = []
for ad, tablo, kol, yedek in BESLEMELER:
    ifade = kol if kol else yedek
    if kol and yedek:
        ifade = "GREATEST(MAX(%s)::date, MAX(%s)::date)" % (kol, yedek)
        sql = "SELECT %s, COUNT(*) FROM %s" % (ifade, tablo)
    else:
        sql = "SELECT MAX(%s)::date, COUNT(*) FROM %s" % (ifade, tablo)
    try:
        r = psql(sql)
        if not r or r[0][0] in (None, ""):
            add("pipeline.ingest.%s" % ad, "pipeline", "ERP aktarim: %s" % ad, "crit",
                "veri yok", "Tablo BOS: %s" % tablo, None)
            ing.append("crit"); continue
        son = r[0][0]; n = int(r[0][1])
        from datetime import date, datetime as _dt
        if isinstance(son, str):
            son = _dt.strptime(son[:10], "%Y-%m-%d").date()
        d = (date.today() - son).days
        st = "crit" if d > ic else ("warn" if d > iw else "ok")
        add("pipeline.ingest.%s" % ad, "pipeline", "ERP aktarim: %s" % ad, st,
            "%d gun" % d,
            "Son veri %s (%d gun once) · %d satir · kaynak: %s" % (son, d, n, tablo), d)
        ing.append(st)
    except Exception as e:
        add("pipeline.ingest.%s" % ad, "pipeline", "ERP aktarim: %s" % ad, "warn",
            "okunamadi", "Kontrol hatasi: %s" % e, None)
        ing.append("warn")

if ing:
    add("pipeline.ingest.overall", "pipeline", "ERP veri aktarimi (genel)", worst(ing), "",
        "En kotu besleme durumu. Kaynak: TABLOLARIN KENDISI (log degil).")

for kaynak, hrs in'''

src = src[:m.start()] + yeni_blok + src[m.end():]
src = src.replace("for kaynak, hrs in\n", "for kaynak, hrs in ", 1)
p.write_text(src, encoding="utf-8")
print("  ✅ ops_monitor.py -> tablolarin KENDISINI okuyor (log degil)")
print("  ⚠ Yeni besleme eklenince BESLEMELER listesine eklenecek — tek dogruluk kaynagi.")
