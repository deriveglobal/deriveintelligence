#!/usr/bin/env python3
# ================================================================
# FAZ C — tahsilat feed'i bagla: erp_ingest "tahsilat" KAYIT -> HAM yazici
#         (bi_odeme_gecmisi, tarih_araligi/fatura_tarihi) + turet() dali
#         (bi_tahsilat_yenile) + sl_connector tahsilat REPORTS satiri.
# Markerlar: TAHSILAT_HAM_KAYIT_V1 (erp_ingest) + TAHSILAT_SL_ENABLE_V1 (sl_connector)
# Idempotent (marker guard) + py_compile dogrulamasi. Rollback: .bak_fazc_*
# ================================================================
import py_compile, shutil, time

EI = "/opt/krb-assessment/erp_ingest.py"
SC = "/opt/krb-assessment/sl_connector.py"
STAMP = str(int(time.time())) if False else "fazc"  # sabit son-ek (Date.now yok)

NEW_KAYIT = '''  "tahsilat": {   # TAHSILAT_HAM_KAYIT_V1 — HAM satir yazici; ozet bi_tahsilat_yenile() ile turet() icinde
    "ad": "Tahsilat durumu (odeme davranisi / gercek DSO) - HAM satir",
    "imza": ["Ödenen Tutar", "Tahsilat Süresi", "Tahsilat türü", "Fatura Vade Tarihi"],
    "tablo": "bi_odeme_gecmisi",
    "tenant_tip": "uuid",
    "yukleme_modu": "tarih_araligi",
    "tarih_alani": "fatura_tarihi",
    "dogal_anahtar": ["fatura_no", "odeme_tarihi", "odenen_tutar"],
    "kolonlar": {
      "fatura_no"       : (None, "Fatura Belge Numarası", "metin"),
      "fatura_tarihi"   : (None, "Fatura Tarihi", "tarih"),
      "vade_tarihi"     : (None, "Fatura Vade Tarihi", "tarih"),
      "odeme_tarihi"    : (None, "Tahsilat Tarihi", "tarih"),
      "musteri_kodu"    : (None, "Customer/Vendor Code", "metin"),
      "musteri_adi"     : (None, "Customer/Vendor Name", "metin"),
      "satis_calisani"  : (None, "Sales Employee Name", "metin"),
      "fatura_tutari"   : (None, "Fatura Tutarı", "sayi2"),
      "odenen_tutar"    : (None, "Ödenen Tutar", "sayi2"),
      "tahsilat_turu"   : (None, "Tahsilat türü", "metin"),
      "gecikme_gun"     : (None, "Vadesi Geçen Gün", "gun"),
      "dso_contribution": (None, "Tahsilat Süresi", "gun"),
      "grup"            : (None, "Group Name", "metin"),
    },
    "cikti_alanlar": ["fatura_no", "fatura_tarihi", "vade_tarihi", "odeme_tarihi", "musteri_kodu",
                      "musteri_adi", "satis_calisani", "fatura_tutari", "odenen_tutar",
                      "tahsilat_turu", "gecikme_gun", "dso_contribution", "grup"],
    "kapilar": [
      ("bos_fatura", lambda R: sum(1 for r in R if not r["fatura_no"]), 20, "Fatura Belge Numarasi bos"),
      ("gelecek_fatura", lambda R: sum(1 for r in R if r["fatura_tarihi"] and r["fatura_tarihi"] > BUGUN),
       0, "Gelecek tarihli fatura - tarih bozulmasi"),
    ],
  },

'''

# ---- erp_ingest.py ----
s = open(EI, encoding="utf-8").read()
if "TAHSILAT_HAM_KAYIT_V1" in s:
    print("SKIP erp_ingest zaten yamanmis")
else:
    shutil.copy(EI, EI + ".bak_" + STAMP)
    a = s.index('  "tahsilat": {')
    b = s.index('  "alacak_yaslandirma": {')
    assert a < b, "KAYIT anchor sirasi bozuk"
    s = s[:a] + NEW_KAYIT + s[b:]

    assert s.count("BAGIMLILIK = {\n") == 1, "BAGIMLILIK anchor tek degil"
    s = s.replace("BAGIMLILIK = {\n",
                  'BAGIMLILIK = {\n    "tahsilat"            : ["tahsilat_ozet"],  # TAHSILAT_HAM_KAYIT_V1\n', 1)

    assert s.count("SQL_TURET = {\n") == 1, "SQL_TURET anchor tek degil"
    s = s.replace("SQL_TURET = {\n",
                  'SQL_TURET = {\n  "tahsilat_ozet": "SELECT bi_tahsilat_yenile(%(t)s::uuid);",  # TAHSILAT_HAM_KAYIT_V1\n', 1)

    open(EI, "w", encoding="utf-8").write(s)
    py_compile.compile(EI, doraise=True)
    print("OK erp_ingest yamandi + py_compile OK")

# ---- sl_connector.py ----
c = open(SC, encoding="utf-8").read()
if "TAHSILAT_SL_ENABLE_V1" in c:
    print("SKIP sl_connector zaten yamanmis")
else:
    shutil.copy(SC, SC + ".bak_" + STAMP)
    OLD = '    # {"tip": "tahsilat", "path": "/api/IncomingPaymentReport", "alan_map": {...}},\n'
    NEW = (
        '    # tahsilat (IncomingPaymentReport) — CO1 08-07 "Tahsilat Durumu V2" (fatura-seviye). TAHSILAT_SL_ENABLE_V1\n'
        '    #   15-gun InvoiceDate penceresi -> bi_odeme_gecmisi tarih_araligi(fatura_tarihi); ozet bi_tahsilat turet() icinde.\n'
        '    {"tip": "tahsilat", "path": "/api/IncomingPaymentReport", "alan_map": {\n'
        '        "fatura_no": "InvoiceDocumentNumber", "fatura_tarihi": "InvoiceDate", "vade_tarihi": "InvoiceDueDate",\n'
        '        "odeme_tarihi": "PaymentDate", "musteri_kodu": "CardCode", "musteri_adi": "CardName",\n'
        '        "satis_calisani": "SalesEmployee", "fatura_tutari": "InvoiceAmount", "odenen_tutar": "PaidAmount",\n'
        '        "tahsilat_turu": "PaymentType", "gecikme_gun": "OverdueDays", "dso_contribution": "PaymentDuration",\n'
        '        "grup": "CustomerGroup"}},\n'
    )
    assert c.count(OLD) == 1, "connector anchor bulunamadi: " + str(c.count(OLD))
    c = c.replace(OLD, NEW, 1)
    open(SC, "w", encoding="utf-8").write(c)
    py_compile.compile(SC, doraise=True)
    print("OK sl_connector yamandi + py_compile OK")

print("FAZ_C_PATCH_DONE")
