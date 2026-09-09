#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# TAHSILAT_GUNLUK_V1 — tahsilat.xlsx'teki TARIHLI odeme satirlarini bi_odeme_gecmisi'ne yukler.
#   erp_ingest.py tahsilat'i musteri basina TEK satira topluyor (bi_tahsilat) ve gunluk grani ATIYOR.
#   Bu betik ayni dosyayi okur, MUSTERI odeme satirlarini (Tahsilat Tarihi + Odenen Tutar) korur.
#   Boylece "dun tahsil edilen ₺" sorgulanabilir olur. tam_degistir: tenant icin eskiyi siler, yeniden yazar.
#
# KULLANIM:
#   Kuru (DB'ye DOKUNMAZ, sadece ayrıştır + istatistik):
#     python3 load_odeme_gecmisi.py tahsilat.xlsx <tenant_id> --dry
#   Gercek yukleme (erp_ingest ile AYNI DATABASE_URL ortami gerekli):
#     DATABASE_URL=postgres://... python3 load_odeme_gecmisi.py tahsilat.xlsx <tenant_id>
#
# NOT: tenant_id = erp_ingest.py'de kullandiginiz KRB tenant kimligiyle AYNI olmali.
import sys, os, datetime

DRY = "--dry" in sys.argv
args = [a for a in sys.argv[1:] if not a.startswith("--")]
if len(args) < 2:
    sys.exit("kullanım: load_odeme_gecmisi.py <tahsilat.xlsx> <tenant_id> [--dry]")
XLSX, TENANT = args[0], args[1]

import openpyxl

# tahsilat.xlsx kolon başlıkları (17):
# Customer/Vendor Code, Customer/Vendor Name, Group Name, Sales Employee Name, e-Belge ID,
# Account Balance, Fatura Belge Numarası, Fatura Tarihi, Fatura Vade Tarihi, Fatura Tutarı,
# Tahsilat Belge Numarası, Tahsilat türü, Tahsilat Tarihi, Tahsilat Vade Tarihi, Ödenen Tutar,
# Tahsilat Süresi, Vadesi Geçen Gün
COL = {
    "musteri_kodu":  "Customer/Vendor Code",
    "musteri_adi":   "Customer/Vendor Name",
    "grup":          "Group Name",
    "fatura_no":     "Fatura Belge Numarası",
    "fatura_tarihi": "Fatura Tarihi",
    "vade_tarihi":   "Fatura Vade Tarihi",
    "fatura_tutari": "Fatura Tutarı",
    "odeme_tarihi":  "Tahsilat Tarihi",
    "odenen_tutar":  "Ödenen Tutar",
    "gecikme_gun":   "Vadesi Geçen Gün",
}

def _date(v):
    if v is None or v == "":
        return None
    if isinstance(v, datetime.datetime):
        return v.date()
    if isinstance(v, datetime.date):
        return v
    s = str(v).strip()
    for f in ("%Y-%m-%d", "%d/%m/%Y", "%d.%m.%Y", "%m/%d/%Y"):
        try:
            return datetime.datetime.strptime(s[:10] if f == "%Y-%m-%d" else s, f).date()
        except Exception:
            pass
    return None

def _num(v):
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip().replace(" ", "").replace(" ", "")
    # TR biçimi: 1.234,56 -> 1234.56 ; ya da düz 1234.56
    if "," in s and "." in s:
        s = s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", ".")
    try:
        return float(s)
    except Exception:
        return None

def _int(v):
    n = _num(v)
    return int(round(n)) if n is not None else None

def _is_musteri(grup):
    G = str(grup or "").upper()
    return ("TEDAR" not in G) and ("PERSONEL" not in G)

wb = openpyxl.load_workbook(XLSX, read_only=True, data_only=True)
sh = wb.active
it = sh.iter_rows(min_row=1, values_only=True)
hdr = [str(x).strip() if x is not None else "" for x in next(it)]
ix = {h: i for i, h in enumerate(hdr)}
missing = [c for c in COL.values() if c not in ix]
if missing:
    sys.exit("HATA: beklenen kolon(lar) yok: %s\nDosyadaki başlıklar: %s" % (missing, hdr))

def g(r, key):
    i = ix[COL[key]]
    return r[i] if i < len(r) else None

rows = []
stat = {"okunan": 0, "musteri_disi": 0, "odemesiz": 0, "kodsuz": 0, "yuklenen": 0,
        "sum_odenen": 0.0, "min_odeme": None, "max_odeme": None, "gun_kumesi": set()}
for r in it:
    if not r or all(x is None for x in r):
        continue
    stat["okunan"] += 1
    grup = g(r, "grup")
    if not _is_musteri(grup):
        stat["musteri_disi"] += 1
        continue
    od_tarih = _date(g(r, "odeme_tarihi"))
    odenen = _num(g(r, "odenen_tutar"))
    if od_tarih is None or odenen is None:
        stat["odemesiz"] += 1
        continue
    kod = g(r, "musteri_kodu")
    if kod is None or str(kod).strip() == "":
        stat["kodsuz"] += 1
        continue
    rec = {
        "fatura_no":     (str(g(r, "fatura_no")).strip() if g(r, "fatura_no") is not None else ""),
        "fatura_tarihi": _date(g(r, "fatura_tarihi")),
        "vade_tarihi":   _date(g(r, "vade_tarihi")),
        "odeme_tarihi":  od_tarih,
        "musteri_kodu":  str(kod).strip(),
        "musteri_adi":   (str(g(r, "musteri_adi")).strip() if g(r, "musteri_adi") is not None else None),
        "grup":          (str(grup).strip() if grup is not None else None),
        "fatura_tutari": _num(g(r, "fatura_tutari")),
        "odenen_tutar":  odenen,
        "gecikme_gun":   _int(g(r, "gecikme_gun")),
    }
    rows.append(rec)
    stat["yuklenen"] += 1
    stat["sum_odenen"] += odenen
    stat["gun_kumesi"].add(od_tarih)
    if stat["min_odeme"] is None or od_tarih < stat["min_odeme"]:
        stat["min_odeme"] = od_tarih
    if stat["max_odeme"] is None or od_tarih > stat["max_odeme"]:
        stat["max_odeme"] = od_tarih
wb.close()

print("── tahsilat.xlsx → bi_odeme_gecmisi ──")
print("okunan satır          :", stat["okunan"])
print("müşteri-dışı (tedar.)  :", stat["musteri_disi"])
print("ödemesiz (açık fatura) :", stat["odemesiz"])
print("kodsuz atlanan         :", stat["kodsuz"])
print("YÜKLENECEK satır       :", stat["yuklenen"])
print("toplam ödenen ₺        :", round(stat["sum_odenen"], 2))
print("tarih aralığı          :", stat["min_odeme"], "→", stat["max_odeme"])
print("farklı ödeme günü      :", len(stat["gun_kumesi"]))
if rows[:2]:
    print("örnek satır            :", rows[0])

if DRY:
    print("\n[DRY] DB'ye yazılmadı. Gerçek yükleme için --dry olmadan çalıştırın.")
    sys.exit(0)

import psycopg2, psycopg2.extras
def _conn():
    u = os.getenv("DATABASE_URL", "")
    if u:
        return psycopg2.connect(u)
    return psycopg2.connect(host=os.getenv("PGHOST", "postgres"),
                            dbname=os.getenv("PGDATABASE", "assessment_platform"),
                            user=os.getenv("PGUSER", "assessment_app"),
                            password=os.getenv("PGPASSWORD", ""))

cols = ["fatura_no", "fatura_tarihi", "vade_tarihi", "odeme_tarihi", "musteri_kodu",
        "musteri_adi", "grup", "fatura_tutari", "odenen_tutar", "gecikme_gun"]
cn = _conn()
try:
    with cn, cn.cursor() as cur:
        # grup kolonu şemada yok — idempotent ekle (kanal/segment filtresi için).
        cur.execute("ALTER TABLE bi_odeme_gecmisi ADD COLUMN IF NOT EXISTS grup text")
        cur.execute("CREATE INDEX IF NOT EXISTS idx_bog_tenant_odeme ON bi_odeme_gecmisi (tenant_id, odeme_tarihi)")
        cur.execute("DELETE FROM bi_odeme_gecmisi WHERE tenant_id=%s::uuid", (TENANT,))
        silinen = cur.rowcount
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO bi_odeme_gecmisi (tenant_id, export_date, %s) VALUES %%s" % (", ".join(cols)),
            [tuple([TENANT, datetime.date.today()] + [r[c] for c in cols]) for r in rows],
            template="(%s::uuid,%s," + ",".join(["%s"] * len(cols)) + ")",
            page_size=5000)
        cur.execute("SELECT count(*), coalesce(sum(odenen_tutar),0)::numeric(18,2), max(odeme_tarihi) FROM bi_odeme_gecmisi WHERE tenant_id=%s::uuid", (TENANT,))
        c2 = cur.fetchone()
    print("\n[OK] silinen: %s · yüklenen: %s · tablo toplam: %s satır, ₺%s, son ödeme: %s" %
          (silinen, len(rows), c2[0], c2[1], c2[2]))
finally:
    cn.close()
