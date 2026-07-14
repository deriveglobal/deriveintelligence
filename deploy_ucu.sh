#!/usr/bin/env bash
# UCU_V1 — uc eksik: sonuc ekranda kalsin · turetilmis tablolar yenilensin · monitor duzelsin.
#
# ⚠ 1) SONUC EKRANDA KALMIYORDU — 1,2 sn'de yenilenip siliniyordu. Kullanici
#      kapilarin gectigini OKUYAMADI. Bir sonucu gosterip 1 saniyede silmek,
#      hic gostermemekle esdeger.
#
# ⚠ 2) TURETILMIS TABLOLAR YENILENMIYORDU — yeni veri geldi ama bi_marj_fact,
#      bi_maliyet_ay ve sinyaller ESKI kaliyordu. Yani yukleme calisiyor ama
#      EKRAN ESKI VERIYI gosteriyordu. Bu, "yuklendi" demenin en kotu turu.
#      ✅ Yukleme sonrasi ILGILI turetilmis tablolar yeniden kuruluyor.
#      ✅ MUTABAKAT KAPISI: kup marji bagimsiz dogrulanmis degerden 3 puandan
#         fazla saparsa YENI KUP KURULMAZ, eskisi kalir. Cunku bozuk bir kup,
#         eski bir kupten kotudur.
#
# ⚠ 3) MONITOR SAHTE ALARM VERIYORDU — 'ERP 31,9 gun' diyordu, veri BUGUN geldi.
#      Logu okuyordu; log = yukleyicinin soyledigi, tablo = GERCEKTE OLAN.
#      Onceki yamam sc/sw degiskenlerini YUTMUS ve monitoru komple kirmisti;
#      geri almistim. Bu sefer o degiskenlere DOKUNMADAN yamaliyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SONUC EKRANDA KALSIN ############"
cp shells/bi.js shells/bi.js.bak_ucu
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
eski = "    if (r.ok) setTimeout(ciz_veri, 1200);"
assert eski in s, "auto-refresh anchor yok"
# ⚠ Sonucu 1,2 sn'de silmek, hic gostermemekle esdeger.
#   Dosya listesini AYRICA tazele, ama SONUC KARTINA DOKUNMA.
yeni = """    // ⚠ SONUC EKRANDA KALIR. Onceki hali 1,2 sn'de yenileyip SILIYORDU —
    //   kullanici kapilarin gectigini okuyamadi. Bir sonucu gosterip
    //   bir saniyede silmek, hic gostermemekle esdegerdir.
    if (r.ok) {
      // dosya listesini tazele ama SONUC KARTINI KORU
      fetch('/api/bi/yukle/durum', { credentials:'same-origin' })
        .then(x => x.json())
        .then(function(){ /* liste arka planda guncellendi; kart yerinde kaliyor */ })
        .catch(function(){});
      s.insertAdjacentHTML('beforeend',
        '<div style="font-size:13px;color:var(--tx-2);margin-top:10px">'
        + 'Türetilmiş tablolar (marj, sinyaller) yeniden kuruldu. '
        + '<span class="d-yesil">Bugün</span> sekmesini yenileyerek görebilirsin.</div>');
    }"""
s = s.replace(eski, yeni, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ sonuc kartı ekranda kalıyor")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_ucu shells/bi.js; echo "❌ NODE FAIL"; exit 1; }

echo
echo "############ 2) TURETILMIS TABLOLAR — yukleme sonrasi otomatik ############"
cp erp_ingest.py erp_ingest.py.bak_ucu
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("erp_ingest.py"); s = p.read_text(encoding="utf-8")
if "TURET_SONRASI" in s: sys.exit("ZATEN YAMALI")

BLOK = '''

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
'''
s = s.rstrip() + "\n" + BLOK

# yukle() sonunda turet() cagir
eski = '''    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),
            "mod": mod,'''
assert eski in s, "return anchor yok"
yeni = '''    # ⚠ TURET_SONRASI — yeni veri geldi, turetilmis tablolar YENILENMELI.
    #   Yoksa yukleme "calisir" ama EKRAN ESKI VERIYI gosterir: sessiz yalan.
    try:
        t = turet(tenant_id, tip)
    except Exception as e:
        t = {"turetilen": [], "uyari": [f"⚠ türetme hatası: {str(e)[:160]}"]}

    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),
            "turetme": t,
            "mod": mod,'''
s = s.replace(eski, yeni, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ turet() + mutabakat kapisi + yukle() cagriyor")
PY
python3 -c "import ast; ast.parse(open('erp_ingest.py').read())" || { cp erp_ingest.py.bak_ucu erp_ingest.py; echo "❌ PY FAIL"; exit 1; }
echo "  ✅ python sozdizimi"

echo
echo "############ 3) MONITOR — LOGU DEGIL TABLOLARI oku ############"
cp ops_monitor.py ops_monitor.py.bak_ucu
python3 - <<'PY' || exit 1
import pathlib, re, sys
p = pathlib.Path("ops_monitor.py"); s = p.read_text(encoding="utf-8")
if "MONITOR_TABLO" in s: sys.exit("ZATEN YAMALI")

# ⚠ ONCEKI YAMAM sc/sw DEGISKENLERINI YUTMUSTU ve monitoru KIRMISTI.
#   Bu sefer SADECE ingest dongusunu degistiriyorum, gerisine DOKUNMUYORUM.
m = re.search(r'for qt, d in psql\([^)]*\n?[^)]*\):\n(.*?)\nif ing:\n(.*?)\n', s, re.S)
if not m:
    # daha genis ara
    m = re.search(r'(for qt, d in psql\(.*?\n(?:.*?\n)*?)(?=for kaynak, hrs in)', s, re.S)
assert m, "ingest dongusu bulunamadi"

YENI = '''# ─── MONITOR_TABLO ───────────────────────────────────────────────────────────
# ⚠ LOGU DEGIL, TABLOLARIN KENDISINI oku.
#   Log = yukleyicinin SOYLEDIGI · tablo = GERCEKTE OLAN.
#   Log'da Haziran'in emekli query_type'lari duruyordu -> monitor HAKLI olarak
#   "31,9 gundur beslenmiyor" diyordu -> 4 SAHTE crit ana sayfada goruniyordu.
#   Her gun 4 sahte crit ureten alarm, insanlari alarma BAKMAMAYA egitir;
#   gercek yangin o zaman gorulmez.
# ⚠ Yeni besleme eklenince BURAYA eklenir — tek dogruluk kaynagi.
BESLEMELER = [
    ("satis_faturalari", "bi_satis_faturalari",     "export_date", None),
    ("tedarikci_fatura", "bi_tedarikci_faturalari", "export_date", None),
    ("stok_anlik",       "bi_stok_anlik",           "export_date", "ingested_at"),
    ("musteri_risk",     "bi_musteri_risk",         "export_date", "ingested_at"),
    ("stok_hareket",     "bi_stok_hareket",         None,          "ingested_at"),
    ("cari_bakiye",      "bi_cari_bakiye",          "export_date", "ingested_at"),
]
ing = []
for _ad, _tab, _kol, _yed in BESLEMELER:
    try:
        if _kol and _yed:
            _sql = "SELECT GREATEST(MAX(%s)::date, MAX(%s)::date), COUNT(*) FROM %s" % (_kol, _yed, _tab)
        else:
            _sql = "SELECT MAX(%s)::date, COUNT(*) FROM %s" % (_kol or _yed, _tab)
        _r = psql(_sql)
        if not _r or _r[0][0] in (None, ""):
            add("pipeline.ingest.%s" % _ad, "pipeline", "ERP aktarim: %s" % _ad, "crit",
                "veri yok", "Tablo BOS: %s" % _tab, None)
            ing.append("crit"); continue
        _son = _r[0][0]; _n = int(_r[0][1])
        if isinstance(_son, str):
            _son = datetime.datetime.strptime(_son[:10], "%Y-%m-%d").date()
        _d = (datetime.date.today() - _son).days
        _st = "crit" if _d > ic else ("warn" if _d > iw else "ok")
        add("pipeline.ingest.%s" % _ad, "pipeline", "ERP aktarim: %s" % _ad, _st,
            "%d gun" % _d,
            "Son veri %s (%d gun once) · %s satir · kaynak: %s" % (_son, _d, f"{_n:,}", _tab), _d)
        ing.append(_st)
    except Exception as _e:
        add("pipeline.ingest.%s" % _ad, "pipeline", "ERP aktarim: %s" % _ad, "warn",
            "okunamadi", "Kontrol hatasi: %s" % _e, None)
        ing.append("warn")

if ing:
    add("pipeline.ingest.overall", "pipeline", "ERP veri aktarimi (genel)", worst(ing), "",
        "En kotu besleme durumu. Kaynak: TABLOLARIN KENDISI (log degil).")

'''
s = s[:m.start(1)] + YENI + s[m.end(1):]
if "import datetime" not in s:
    s = s.replace("import os", "import os, datetime", 1)
p.write_text(s, encoding="utf-8")
print("  ✅ monitor tablolari okuyor (sc/sw'ye DOKUNULMADI)")
PY
python3 -c "import ast; ast.parse(open('ops_monitor.py').read())" \
  || { cp ops_monitor.py.bak_ucu ops_monitor.py; echo "❌ PY FAIL"; exit 1; }
echo "  ✅ python sozdizimi"

echo
echo "  -- ⚠ MONITORU CALISTIR: sahte alarm kalkti mi? --"
/opt/price_monitor/venv/bin/python3 ops_monitor.py >/dev/null 2>&1 || python3 ops_monitor.py >/dev/null 2>&1 || true
$PSQL -c "
SELECT check_key, status, value, left(detail,52) AS detay
  FROM ops_health
 WHERE checked_at = (SELECT max(checked_at) FROM ops_health)
   AND check_key LIKE 'pipeline.ingest%'
 ORDER BY check_key;"

echo
echo "############ 4) IMAJ + DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 10
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'python3 -c "
import sys; sys.path.insert(0,\"/app\")
import erp_ingest as E
print(\"  ✅ turet() yuklu:\", \"turet\" in dir(E))
"'

git add -A
git commit -q -m 'feat: UCU_V1 — uc eksik kapatildi. (1) YUKLEME SONUCU EKRANDA KALIYOR: onceki hali 1,2 sn de yenileyip SILIYORDU; kullanici kapilarin gectigini okuyamadi. Bir sonucu gosterip bir saniyede silmek, hic gostermemekle esdegerdir. (2) TURETILMIS TABLOLAR OTOMATIK YENILENIYOR: onceden yeni veri geliyordu ama bi_marj_fact, bi_maliyet_ay ve sinyaller ESKI kaliyordu — yukleme calisiyor ama EKRAN ESKI VERIYI gosteriyordu; "yuklendi" demenin en kotu turu, sessiz yalan. Artik BAGIMLILIK haritasi var (stok_hareket -> maliyet_ay + marj_fact · cari_bakiye -> sinyal_kredi vb) ve yukleme sonrasi ilgili tablolar yeniden kuruluyor. MUTABAKAT KAPISI: kup marji bagimsiz dogrulanmis %8,3 ten 3 puandan fazla saparsa YENI KUP KURULMAZ ve ESKISI KALIR — bozuk bir kup, eski bir kupten kotudur. (3) MONITOR LOGU DEGIL TABLOLARI okuyor: log = yukleyicinin soyledigi, tablo = gercekte olan; log da Haziran in emekli query_type lari duruyordu ve monitor HAKLI olarak "31,9 gundur beslenmiyor" diyordu -> 4 SAHTE crit. Her gun 4 sahte crit ureten alarm, insanlari alarma bakmamaya egitir; gercek yangin o zaman gorulmez. ⚠ Onceki yamam sc/sw degiskenlerini yutup monitoru kirmisti; bu sefer sadece ingest dongusu degistirildi.'
echo "  COMMITTED"
