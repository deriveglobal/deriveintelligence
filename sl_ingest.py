#!/usr/bin/env python3
"""SL_INGEST — Service Layer (CO1 JSON) → DB yükleme, erp_ingest motorunu YENİDEN KULLANIR.

⚠ NEDEN AYRI MODÜL: erp_ingest.py Excel-yerlidir; içindeki onarımlar (tarih_onar gün/ay TAKAS,
   sayi_onar int/10^basamak, basamak_bul, olcek_coz) SAP'in Türkçe-locale Excel export'unun
   BOZULMALARINI düzeltmek için var. CO1 servisi TEMİZ JSON döner → o onarımlar YANLIŞ ateşler
   (temiz ISO tarihi takas eder, temiz tam sayıyı böler). Bu yüzden JSON için AYRI, onarımsız
   bir okuma yolu; ama AYNI KAYIT registry + grupla (FIFO/tahsilat) + kapılar + dedup/VADESI_CAP +
   MERGE_KORU + yukle + turet KULLANILIR. erp_ingest.py'ye DOKUNULMAZ.

Kullanım (connector çağırır):
   import sl_ingest
   sl_ingest.kuru_json(records, "tahsilat")            # DRY: sadece oku+kapı, DB'ye dokunmaz
   sl_ingest.yukle_json(records, "tahsilat", tenant)   # GERÇEK: dedup + DELETE/INSERT + log + turet
"""
import datetime, json
import erp_ingest as E   # motoru yeniden kullan (KAYIT, kapilari_kos, mukerrer_bul, turet, _baglan)
import psycopg2.extras

BUGUN = datetime.date.today()


# ─────────────────────────────────────────────────────────────────────────
#  TEMİZ JSON DÖNÜŞTÜRÜCÜLER — Excel onarımı YOK
# ─────────────────────────────────────────────────────────────────────────
def _c_metin(v, uzunluk=None):
    if v is None:
        return ""
    s = str(v).strip()
    return s[:uzunluk] if uzunluk else s


def _c_sayi(v):
    """Temiz JSON sayısı: doğrudan float. ÷10^basamak YOK. Metin gelirse tolere et."""
    if v is None or v == "":
        return 0.0
    if isinstance(v, bool):
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip().replace("\xa0", "")
    if not s:
        return 0.0
    try:
        return float(s)                      # "1234.56"
    except ValueError:
        pass
    neg = s.startswith("-")                   # Türkçe metin yedeği: "1.234,56"
    s = s.lstrip("-").replace(".", "").replace(",", ".")
    try:
        return -float(s) if neg else float(s)
    except ValueError:
        return 0.0


def _c_gun(v):
    """Vadesi Geçen Gün / Tahsilat Süresi: tam sayı. TAKAS/1900-epoch YOK."""
    if v is None or v == "":
        return None
    if isinstance(v, bool):
        return None
    if isinstance(v, (int, float)):
        return int(round(v))
    s = str(v).strip()
    if not s or s in ("·", "-"):
        return None
    try:
        return int(round(float(s.replace(".", "").replace(",", "."))))
    except ValueError:
        return None


def _c_tarih(v):
    """Temiz ISO/standart tarih → date. GÜN/AY TAKASI YOK."""
    if v is None or v == "":
        return None
    if isinstance(v, datetime.datetime):
        return v.date()
    if isinstance(v, datetime.date):
        return v
    s = str(v).strip()
    if not s:
        return None
    s = s.replace("T", " ")
    for f in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d",
              "%d/%m/%Y", "%d.%m.%Y", "%d/%m/%y"):
        try:
            return datetime.datetime.strptime(s[:len(f) + 2] if "%H" in f else s, f).date()
        except ValueError:
            continue
    # son çare: ilk 10 karakter YYYY-MM-DD
    try:
        return datetime.datetime.strptime(str(v)[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def _don(tur, v):
    if tur == "tarih":
        return _c_tarih(v)
    if tur == "gun":
        return _c_gun(v)
    if tur.startswith("sayi"):
        return _c_sayi(v)
    if tur == "metin200":
        return _c_metin(v, 200)
    return _c_metin(v)


# ─────────────────────────────────────────────────────────────────────────
#  JSON OKUMA — erp_ingest.oku()'nun JSON ikizi (onarımsız)
# ─────────────────────────────────────────────────────────────────────────
def alan_kontrol(records, tip, alan_map=None):
    """CO1 JSON alan adları (alan_map ile çözülmüş) motorun kolonlarını karşılıyor mu?
       Eksik = bilgi; KRİTİK eksik (dogal_anahtar alanının JSON karşılığı yok) = yükleme durur."""
    alan_map = alan_map or {}
    if not records:
        return {"ok": False, "kritik_eksik": [{"sebep": "boş kayıt listesi"}], "eksik": [], "gelen_alanlar": []}
    keys = set()
    for r in records[:50]:
        if isinstance(r, dict):
            keys |= set(r.keys())
    k = E.KAYIT[tip]
    eksik = []
    for alan, (_, excel, tur) in k["kolonlar"].items():
        jkey = alan_map.get(alan, excel)
        if jkey not in keys:
            eksik.append({"alan": alan, "beklenen_key": jkey})
    da = k.get("dogal_anahtar") or []
    kritik = [e for e in eksik if e.get("alan") in da]
    return {"ok": not kritik, "kritik_eksik": kritik, "eksik": eksik, "gelen_alanlar": sorted(keys)}


def oku_json(records, tip, alan_map=None):
    """CO1 JSON kayıtları → motor satırları (onarımsız). erp_ingest.oku() ile AYNI çıktı yapısı.

    alan_map: {engine_field: json_key} — CO1 JSON anahtarı motorun beklediği Excel başlığından
              FARKLIYSA burada override et. Verilmezse JSON anahtarı = Excel başlığı (spec[1]) varsayılır.
    """
    k = E.KAYIT[tip]
    alan_map = alan_map or {}
    satir = []
    atlanan = 0
    for rec in records:
        d = {}
        atla = False
        for alan, (_, excel_baslik, tur) in k["kolonlar"].items():
            jkey = alan_map.get(alan, excel_baslik)     # CO1 anahtarı
            v = rec.get(jkey)
            val = _don(tur, v)
            if tur == "tarih" and val is None and (jkey in rec):
                # motor davranışı: zorunlu tarih boşsa satırı atla — ama alan JSON'da hiç
                # yoksa (opsiyonel kolon) atlamayı tetikleme
                pass
            d[alan] = val
        # motor oku() kuralı: 'tarih' tipli alan None ise satır atlanır (yalnız alan MEVCUTSA)
        for alan, (_, excel_baslik, tur) in k["kolonlar"].items():
            if tur == "tarih":
                jkey = alan_map.get(alan, excel_baslik)
                if jkey in (records[0].keys() if records else []) and d.get(alan) is None:
                    atla = True
                    break
        if atla:
            atlanan += 1
            continue
        for alan, fn in (k.get("turet") or {}).items():
            d[alan] = fn(d)
        satir.append(d)

    istat = {"kaynak": "json", "ham_kayit": len(records), "atlanan_tarih": atlanan}

    if k.get("grupla"):
        _grp = {}
        for _r in satir:
            _gk = tuple(str(_r.get(_a, "")) for _a in k["dogal_anahtar"])
            _grp.setdefault(_gk, []).append(_r)
        satir = [k["grupla"](_rows) for _rows in _grp.values()]
    return tip, satir, istat


# ─────────────────────────────────────────────────────────────────────────
#  DRY-RUN — DB'ye dokunmaz (motorun --kuru mantığının JSON ikizi)
# ─────────────────────────────────────────────────────────────────────────
def kuru_json(records, tip, alan_map=None):
    im = alan_kontrol(records, tip, alan_map)
    tip2, satir, istat = oku_json(records, tip, alan_map)
    if not satir:
        return {"ok": False, "tip": tip, "hata": "satır yok", "alan": im, "istat": istat}
    muk, ornek = E.mukerrer_bul(tip, satir)
    kapilar = E.kapilari_kos(tip, satir)
    k = E.KAYIT[tip]
    ta = k.get("tarih_alani")
    t = [r[ta] for r in satir if ta and r.get(ta)] if ta else []
    return {
        "ok": im["ok"] and all(g["gecti"] for g in kapilar),
        "tip": tip, "ad": k["ad"], "mod": k.get("yukleme_modu"),
        "satir": len(satir), "kritik_eksik": im["kritik_eksik"], "alan_eksik": im["eksik"],
        "aralik": [str(min(t)), str(max(t))] if t else None,
        "dosya_ici_mukerrer": muk, "kapilar": kapilar, "istat": istat,
    }


# ─────────────────────────────────────────────────────────────────────────
#  GERÇEK YÜKLEME — erp_ingest.yukle()'nin tail'i, JSON satırlarından
#  (dedup + VADESI_CAP + MERGE_KORU + DELETE/INSERT + bi_ingestion_log + turet)
#  ⚠ Bu blok erp_ingest.yukle()'den BİREBİR kopyalandı; DB mantığı motorla ÖZDEŞ.
# ─────────────────────────────────────────────────────────────────────────
def yukle_json(records, tip, tenant_id, alan_map=None):
    im = alan_kontrol(records, tip, alan_map)
    if not im["ok"]:
        return {"ok": False, "tip": tip, "hata": "kritik alan eksik — dogal_anahtar JSON'da yok",
                "kritik_eksik": im["kritik_eksik"], "gelen_alanlar": im["gelen_alanlar"]}
    _t, satir, istat = oku_json(records, tip, alan_map)
    if not satir:
        return {"ok": False, "tip": tip, "hata": "satır yok", "istat": istat}

    k = E.KAYIT[tip]
    mod = k.get("yukleme_modu", "tam_degistir")
    muk_adet, muk_ornek = E.mukerrer_bul(tip, satir)

    kapilar = E.kapilari_kos(tip, satir)
    dusenler = [g for g in kapilar if not g["gecti"]]
    if dusenler:
        return {"ok": False, "tip": tip, "ad": k["ad"], "satir": len(satir),
                "hata": "Kapı düştü — veri YÜKLENMEDİ, eski veri yerinde",
                "kapilar": kapilar, "dusenler": dusenler, "mukerrer": muk_adet}

    # DEDUP_V2 + VADESI_CAP_V1
    dedup_dusen = 0
    if mod == "tam_degistir" and k.get("dogal_anahtar"):
        _da = k["dogal_anahtar"]; _mx = k.get("dedup_max") or []
        _u = {}
        for _r in satir:
            _key = tuple(str(_r.get(_a, "")) for _a in _da)
            if _key not in _u:
                _b = dict(_r)
                for _f in _mx:
                    _b[_f] = 0.0
                _u[_key] = _b
            _b = _u[_key]
            for _f in _mx:
                try:
                    _cand = float(_r.get(_f) or 0)
                except Exception:
                    continue
                if _f == "vadesi_gecmis":
                    try:
                        _tr = float(_b.get("toplam_risk") or 0)
                    except Exception:
                        _tr = 0.0
                    if _tr > 0 and _cand > _tr:
                        continue
                if _cand > float(_b.get(_f) or 0):
                    _b[_f] = _r.get(_f)
        dedup_dusen = len(satir) - len(_u)
        satir = list(_u.values())

    alanlar = list(k["cikti_alanlar"]) if k.get("cikti_alanlar") else (
        list(k["kolonlar"].keys()) + list((k.get("turet") or {}).keys()))
    cast = "::uuid" if k["tenant_tip"] == "uuid" else ""

    tarih_alani = k.get("tarih_alani")
    aralik = None
    if mod == "tarih_araligi" and tarih_alani:
        t = [r[tarih_alani] for r in satir if r.get(tarih_alani)]
        aralik = (min(t), max(t)) if t else None

    cn = E._baglan()
    silinen = 0
    try:
        with cn, cn.cursor() as cur:
            if k.get("koru_carileri"):
                _incoming = {str(r.get("muhatap_kodu", "")) for r in satir}
                cur.execute(
                    f"SELECT muhatap_kodu, muhatap_adi, grup, satis_calisani "
                    f"FROM {k['tablo']} WHERE tenant_id=%s{cast}", (tenant_id,))
                _seen = set()
                for _kod, _ad, _grup, _sc in cur.fetchall():
                    _kk = str(_kod or "")
                    if _kk in _incoming or _kk in _seen:
                        continue
                    _seen.add(_kk)
                    _G = (_grup or "").upper()
                    satir.append({
                        "muhatap_kodu": _kod, "muhatap_adi": _ad or "", "grup": _grup or "",
                        "satis_calisani": _sc or "", "hesap_bakiyesi": 0.0, "kredi_limiti": 0.0,
                        "toplam_risk": 0.0, "vadesi_gecmis": 0.0, "bekleyen_siparis": 0.0,
                        "limit_asimi": 0.0,
                        "musteri_mi": ("TEDAR" not in _G) and ("PERSONEL" not in _G),
                    })
            if mod == "tarih_araligi" and aralik:
                cur.execute(
                    f"DELETE FROM {k['tablo']} WHERE tenant_id=%s{cast} "
                    f"AND {tarih_alani} BETWEEN %s AND %s", (tenant_id, aralik[0], aralik[1]))
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

            if mod == "tarih_araligi" and k.get("dogal_anahtar"):
                da = ", ".join(k["dogal_anahtar"])
                cur.execute(
                    f"SELECT count(*) FROM (SELECT {da} FROM {k['tablo']} "
                    f"WHERE tenant_id=%s{cast} GROUP BY {da} HAVING count(*)>1) x", (tenant_id,))
                kalan = cur.fetchone()[0]
            else:
                kalan = 0

            cur.execute("""
              INSERT INTO bi_ingestion_log
                (tenant_id, query_type, export_date, received_at, processed_at,
                 row_count_raw, row_count_kept, status, ingest_version)
              VALUES (%s::uuid, %s, CURRENT_DATE, now(), now(), %s, %s, 'ok', 'sl_ingest_v1')
            """, (tenant_id, tip, len(satir) + muk_adet, len(satir)))
    finally:
        cn.close()

    try:
        t = E.turet(tenant_id, tip)
    except Exception as e:
        t = {"turetilen": [], "uyari": [f"⚠ türetme hatası: {str(e)[:160]}"]}

    return {"ok": True, "tip": tip, "ad": k["ad"], "satir": len(satir),
            "kaynak": "service_layer_json", "tekillestirilen": dedup_dusen, "turetme": t,
            "mod": mod, "aralik": [str(aralik[0]), str(aralik[1])] if aralik else None,
            "silinen": silinen, "cok_satirli_belge": muk_adet,
            "yukleme_sonrasi_mukerrer": kalan, "kapilar": kapilar}
