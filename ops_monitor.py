#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ops_monitor.py — DIAGNOSE-ONLY ops layer for the Derive / KRB platform.
# Runs on the host via cron. Gathers signals (Postgres via `docker exec psql`
# + host metrics), writes ops_health, reconciles ops_incident (open/resolve),
# then pings the app to email NEW critical incidents (Graph email lives in app).
# It NEVER remediates — observe & report only. Stdlib only (no pip deps).
import subprocess, uuid, re
import datetime as _dt   # MONITOR_TABLO

PGBASE = ["docker", "exec", "-i", "krb-assessment-postgres", "psql",
          "-U", "assessment_app", "-d", "assessment_platform", "-tA", "-F", "|", "-c"]

def psql(sql):
    r = subprocess.run(PGBASE + [sql], capture_output=True, text=True)
    if r.returncode != 0:
        return []
    out = r.stdout.strip()
    return [ln.split("|") for ln in out.splitlines()] if out else []

def psql_exec(sql):
    subprocess.run(PGBASE + [sql], capture_output=True, text=True)

def esc(s):
    return str(s).replace("'", "''")

def ayar(key, default):
    r = psql("SELECT value FROM ops_ayar WHERE key='%s'" % esc(key))
    return r[0][0] if r and r[0] and r[0][0] != "" else default

def worst(sts):
    order = {"ok": 0, "warn": 1, "crit": 2}
    return max(sts, key=lambda s: order.get(s, 0)) if sts else "ok"

RUN = str(uuid.uuid4())
results = []
def add(k, c, t, s, v="", d="", m=None):
    results.append({"k": k, "c": c, "t": t, "s": s, "v": v, "d": d, "m": m})

# thresholds
iw = float(ayar("ingest_warn_days", "2")); ic = float(ayar("ingest_crit_days", "5"))
sw = float(ayar("scrape_warn_hours", "36")); sc = float(ayar("scrape_crit_hours", "72"))
dw = float(ayar("disk_warn_pct", "80"));  dc = float(ayar("disk_crit_pct", "90"))

# ─── A) PIPELINE ────────────────────────────────────────────────────────────
# ─── MONITOR_TABLO ───────────────────────────────────────────────────────────
# ⚠ LOGU DEGIL, TABLOLARIN KENDISINI oku.
#   Log = yukleyicinin SOYLEDIGI · tablo = GERCEKTE OLAN.
#   bi_ingestion_log'da Haziran'in EMEKLI query_type'lari duruyordu
#   (stok_durumu, musteri_bakiye, odeme_gecmisi, stok_hareketleri) ->
#   monitor HAKLI olarak "31,9 gundur beslenmiyor" diyordu -> 4 SAHTE crit.
#   Her gun 4 sahte crit ureten alarm, insanlari alarma BAKMAMAYA egitir;
#   gercek yangin o zaman gorulmez.
# ⚠ Yeni besleme eklenince BU LISTEYE eklenir — tek dogruluk kaynagi.
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
            _son = _dt.datetime.strptime(_son[:10], "%Y-%m-%d").date()
        _d = (_dt.date.today() - _son).days
        _st = "crit" if _d > ic else ("warn" if _d > iw else "ok")
        add("pipeline.ingest.%s" % _ad, "pipeline", "ERP aktarim: %s" % _ad, _st,
            "%d gun" % _d,
            "Son veri %s (%d gun once) - %d satir - kaynak: %s" % (_son, _d, _n, _tab), _d)
        ing.append(_st)
    except Exception as _e:
        add("pipeline.ingest.%s" % _ad, "pipeline", "ERP aktarim: %s" % _ad, "warn",
            "okunamadi", "Kontrol hatasi: %s" % _e, None)
        ing.append("warn")

if ing:
    add("pipeline.ingest.overall", "pipeline", "ERP veri aktarimi (genel)", worst(ing), "",
        "En kotu besleme durumu. Kaynak: TABLOLARIN KENDISI (log degil).")

for kaynak, hrs in psql("SELECT kaynak, ROUND(EXTRACT(EPOCH FROM now()-MAX(scraped_at))/3600,1) "
                        "FROM bi_rakip_fiyat_son GROUP BY kaynak"):
    h = float(hrs); st = "crit" if h > sc else ("warn" if h > sw else "ok")
    add("pipeline.scrape.%s" % kaynak, "pipeline", "Scraper: %s" % kaynak, st,
        "%.0f saat" % h, "Son cekim %.0f saat once." % h, h)

r = psql("SELECT count(*) FROM bi_ingestion_log WHERE status='error' AND received_at>now()-interval '2 days'")
n = int(r[0][0]) if r else 0
add("pipeline.ingest.errors", "pipeline", "ERP aktarim hatalari (2g)", "warn" if n > 0 else "ok",
    "%d" % n, "Son 2 gunde hatali aktarim.", n)

# ─── B) SYSTEM ──────────────────────────────────────────────────────────────
try:
    df = subprocess.run(["df", "-P", "/"], capture_output=True, text=True).stdout.splitlines()[1].split()
    up = float(df[4].strip("%")); st = "crit" if up > dc else ("warn" if up > dw else "ok")
    add("system.disk", "system", "Disk kullanimi", st, "%.0f%%" % up, "Kok disk doluluk.", up)
except Exception as e:
    add("system.disk", "system", "Disk kullanimi", "warn", "", "df okunamadi: %s" % e)

r = psql("SELECT pg_database_size('assessment_platform')")
if r:
    gb = int(r[0][0]) / 1e9
    add("system.db_size", "system", "Veritabani boyutu", "ok", "%.2f GB" % gb, "", gb)

r = psql("SELECT count(*), (SELECT setting::int FROM pg_settings WHERE name='max_connections') FROM pg_stat_activity")
if r and r[0] and r[0][0]:
    used = int(r[0][0]); mx = int(r[0][1]); pct = 100.0 * used / mx if mx else 0
    st = "crit" if pct > 85 else ("warn" if pct > 70 else "ok")
    add("system.db_connections", "system", "DB baglantilari", st, "%d/%d" % (used, mx), "", pct)

for cn in ["krb-assessment", "krb-assessment-postgres"]:
    ins = subprocess.run(["docker", "inspect", "-f", "{{.State.Running}}|{{.RestartCount}}", cn],
                         capture_output=True, text=True).stdout.strip()
    running, _, rc = ins.partition("|")
    add("system.container.%s" % cn, "system", "Servis: %s" % cn,
        "ok" if running == "true" else "crit",
        "calisiyor" if running == "true" else "DURDU", "RestartCount=%s" % rc, float(rc or 0))

# ─── C) DATA QUALITY ────────────────────────────────────────────────────────
r = psql("SELECT count(*) FROM bi_ingestion_log WHERE export_date > current_date + 1")
n = int(r[0][0]) if r else 0
add("dq.future_export_date", "data_quality", "Gelecek tarihli veri (hatali)", "warn" if n > 0 else "ok",
    "%d" % n, "export_date bugunden ileri olan kayit.", n)

r = psql("SELECT count(*) FROM system_error_logs WHERE severity='ERROR' "
         "AND message ILIKE '%chk_iskonto_arac_tipi%' AND timestamp>now()-interval '24 hours'")
n = int(r[0][0]) if r else 0
# ─── SAHA HATA LOGU (HATA_MONITOR_V1) ───────────────────────────────────────
# Temsilcinin ekraninda patlayan her sey. Bildirmesini BEKLEME.
hw = float(ayar("saha_hata_warn", "1")); hc = float(ayar("saha_hata_crit", "5"))

# 1) 404 — arayuzde olan ama sunucuda OLMAYAN ozellik. Temsilci tiklar, hicbir sey olmaz.
r = psql("SELECT COALESCE(endpoint,'?'), count(*) FROM saha_hata_log "
         "WHERE http_status = 404 AND ts > now() - interval '48 hours' "
         "GROUP BY 1 ORDER BY count(*) DESC LIMIT 1")
n404 = psql("SELECT count(*) FROM saha_hata_log WHERE http_status=404 AND ts > now() - interval '48 hours'")
c404 = int(n404[0][0]) if n404 and n404[0] else 0
ornek404 = (r[0][0] if r and r[0] else "-")
st = "crit" if c404 >= hc else ("warn" if c404 >= hw else "ok")
add("app.saha_404", "app", "Eksik endpoint (temsilci tikladi, karsilik yok)", st,
    "%d" % c404,
    "Arayuzde VAR ama sunucuda YOK olan ozellikler. Temsilci fark etmez, sessizce vazgecer. "
    "En cok: %s" % ornek404, c404)

# 2) 500 — sunucu cokmesi. Ornek: Huseyin'in 'bildir' butonu (request.json is not a function).
n500 = psql("SELECT count(*) FROM saha_hata_log WHERE http_status >= 500 AND ts > now() - interval '48 hours'")
c500 = int(n500[0][0]) if n500 and n500[0] else 0
r5 = psql("SELECT COALESCE(endpoint,'?') || ' :: ' || COALESCE(hata_mesaji,'') FROM saha_hata_log "
          "WHERE http_status >= 500 AND ts > now() - interval '48 hours' ORDER BY ts DESC LIMIT 1")
add("app.saha_500", "app", "Sunucu hatasi (temsilci ekraninda)", "crit" if c500 > 0 else "ok",
    "%d" % c500,
    "500 = islem HIC gerceklesmedi. Son: %s" % ((r5[0][0] if r5 and r5[0] else "-")), c500)

# 3) JS hatasi — ekran kirildi, temsilci bos sayfa gordu.
njs = psql("SELECT count(*) FROM saha_hata_log WHERE tip='JS_HATA' AND ts > now() - interval '48 hours'")
cjs = int(njs[0][0]) if njs and njs[0] else 0
rjs = psql("SELECT COALESCE(view_adi,'?') || ' :: ' || COALESCE(hata_mesaji,'') FROM saha_hata_log "
           "WHERE tip='JS_HATA' AND ts > now() - interval '48 hours' ORDER BY ts DESC LIMIT 1")
add("app.saha_js", "app", "Arayuz (JS) hatasi", "crit" if cjs >= hc else ("warn" if cjs >= hw else "ok"),
    "%d" % cjs, "Son: %s" % ((rjs[0][0] if rjs and rjs[0] else "-")), cjs)

# 4) EN KRITIGI — YASANAN ama BILDIRILMEYEN hata.
#    Temsilci hatayi yasadi; ayni gun HIC geri bildirim acmadi.
#    Bu, "sorun yok" DEGIL; "sorunu bize soyleyemedi/soylemedi" demektir.
sessiz = psql("""
  SELECT COALESCE(u.full_name,'?'), count(*)
    FROM saha_hata_log h
    LEFT JOIN users u ON u.id = h.user_id
   WHERE h.ts > now() - interval '7 days'
     AND h.user_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM saha_oneri o
        WHERE o.user_id = h.user_id
          AND o.ts::date = h.ts::date)
   GROUP BY 1 ORDER BY count(*) DESC LIMIT 3""")
tsz = sum(int(x[1]) for x in sessiz) if sessiz else 0
kimler = ", ".join("%s(%s)" % (x[0], x[1]) for x in sessiz) if sessiz else "-"
add("app.sessiz_hata", "app", "Yasanan ama BILDIRILMEYEN hata (7g)",
    "crit" if tsz >= 10 else ("warn" if tsz > 0 else "ok"),
    "%d" % tsz,
    "Temsilci hatayi yasadi ama o gun geri bildirim acmadi. Sessizlik = 'sorun yok' DEGIL. "
    "Huseyin'in bildir butonu 06.07'de 500 veriyordu; hic bildiremedi. Kimler: %s" % kimler, tsz)

# EBAT_MONITOR_V1 — parser'in okuyamadigi ebat formati belirirse HABER VER.
#   Ebatsiz ilan = Smart Matched'e, trend'e, DOT'a, master'a GIREMEZ. Sessizce kaybolur.
ew = float(ayar("ebat_warn_pct", "2")); ec = float(ayar("ebat_crit_pct", "5"))
r = psql("SELECT count(*) FILTER (WHERE genislik IS NULL), count(*), "
         "COALESCE((array_agg(left(model,44) ORDER BY scraped_at DESC) "
         "  FILTER (WHERE genislik IS NULL))[1],'-') "
         "FROM bi_rakip_fiyat WHERE lastik_mi IS NOT FALSE "
         "  AND scraped_at > now() - interval '7 days'")
if r and r[0]:
    eb = int(r[0][0] or 0); tp = int(r[0][1] or 0); ornek = r[0][2] or "-"
    oran = (100.0 * eb / tp) if tp else 0.0
    st = "crit" if oran > ec else ("warn" if oran > ew else "ok")
    add("dq.ebat_parse", "data_quality", "Ebat okunamayan ilanlar (7g)", st,
        "%.1f%% (%d/%d)" % (oran, eb, tp),
        "Parser'in bilmedigi bir ebat formati ciktiysa bu oran YUKSELIR. "
        "Ebatsiz ilan urun eslesmesine giremez — segment sessizce kaybolur. Ornek: %s" % ornek,
        oran)

add("dq.iskonto_reject", "data_quality", "Fiyat listesi iskonto reddi (24s)", "warn" if n > 0 else "ok",
    "%d" % n, "chk_iskonto_arac_tipi ihlali; iskonto satirlari reddediliyor.", n)

# ─── D) APP ─────────────────────────────────────────────────────────────────
r = psql("SELECT count(*) FILTER (WHERE timestamp>now()-interval '1 hour'), "
         "count(*) FILTER (WHERE timestamp>now()-interval '24 hours') "
         "FROM system_error_logs WHERE severity='ERROR'")
if r and r[0]:
    h1 = int(r[0][0] or 0); h24 = int(r[0][1] or 0)
    st = "crit" if h1 > 20 else ("warn" if h1 > 5 else "ok")
    add("app.errors", "app", "Uygulama hatalari", st, "%d/saat" % h1, "Son 24s: %d hata." % h24, h1)

r = psql("SELECT count(*) FROM saha_hata_log WHERE http_status>=500 AND ts>now()-interval '24 hours'")
n = int(r[0][0]) if r else 0
add("app.saha_5xx", "app", "Saha 5xx hatalari (24s)", "warn" if n > 0 else "ok", "%d" % n,
    "Sunucu tarafi hata.", n)

try:
    au = subprocess.run(["python3", "/opt/krb-assessment/saha_audit.py"],
                        capture_output=True, text=True, timeout=150).stdout
    mm = re.search(r"TOTAL:\s*\d+ passed,\s*\d+ warnings,\s*(\d+) FAILURES", au)
    fails = int(mm.group(1)) if mm else -1
    st = "ok" if fails == 0 else ("crit" if fails > 0 else "warn")
    # Name the actual failures. An alert you cannot act on is only half an alert.
    _fl = [re.sub(r"\s+", " ", l.strip()[4:].strip(" :")) for l in au.splitlines()
           if l.strip().startswith("FAIL")]
    _fl = [x.replace("'", "\"") for x in _fl if x]
    if _fl:
        _d = " | ".join(_fl[:5])[:400]
        if len(_fl) > 5:
            _d += " | (+%d daha)" % (len(_fl) - 5)
    else:
        _d = "Saha denetimi temiz (uc nokta + kod)."
    add("app.endpoint_coverage", "app", "Saha denetimi (uc nokta + kod)", st,
        ("%d hata" % fails) if fails >= 0 else "?", _d, fails)
except Exception as e:
    add("app.endpoint_coverage", "app", "Uc nokta kapsamasi (saha)", "warn", "", "denetim calismadi: %s" % e)

# ─── WRITE ops_health ───────────────────────────────────────────────────────
vals = []
for x in results:
    m = "NULL" if x["m"] is None else str(x["m"])
    vals.append("('%s','%s','%s','%s','%s','%s','%s',%s)" %
                (RUN, esc(x["k"]), esc(x["c"]), esc(x["t"]), x["s"], esc(x["v"]), esc(x["d"]), m))
if vals:
    psql_exec("INSERT INTO ops_health (run_id,check_key,category,title,status,value,detail,metric) VALUES "
              + ",".join(vals))

# ─── RECONCILE ops_incident (open / resolve) ────────────────────────────────
for x in results:
    if x["s"] in ("warn", "crit"):
        psql_exec(
            "INSERT INTO ops_incident (check_key,category,title,severity,detail) "
            "VALUES ('%s','%s','%s','%s','%s') "
            "ON CONFLICT (check_key) WHERE status='open' DO UPDATE SET "
            "last_seen=now(), occurrences=ops_incident.occurrences+1, "
            "title=EXCLUDED.title, detail=EXCLUDED.detail, "
            "email_sent=CASE WHEN EXCLUDED.severity='crit' AND ops_incident.severity<>'crit' "
            "THEN false ELSE ops_incident.email_sent END, "
            "severity=EXCLUDED.severity"
            % (esc(x["k"]), esc(x["c"]), esc(x["t"]), x["s"], esc(x["d"])))
    else:
        psql_exec("UPDATE ops_incident SET status='resolved', resolved_at=now() "
                  "WHERE check_key='%s' AND status='open'" % esc(x["k"]))

# ─── summary + trigger email for NEW criticals (app sends via Graph) ─────────
summ = psql("SELECT status, count(*) FROM ops_health WHERE run_id='%s' GROUP BY status" % RUN)
print("[ops_monitor] run=%s :: %s" % (RUN, ", ".join("%s=%s" % (s, n) for s, n in summ)))

sec = psql("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'")
secret = sec[0][0] if sec and sec[0] else ""
if secret:
    subprocess.run(["docker", "exec", "krb-assessment", "wget", "-qO-",
                    "http://localhost:3000/api/ops/notify?key=%s" % secret],
                   capture_output=True, text=True)
