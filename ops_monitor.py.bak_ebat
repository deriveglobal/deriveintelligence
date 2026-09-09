#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ops_monitor.py — DIAGNOSE-ONLY ops layer for the Derive / KRB platform.
# Runs on the host via cron. Gathers signals (Postgres via `docker exec psql`
# + host metrics), writes ops_health, reconciles ops_incident (open/resolve),
# then pings the app to email NEW critical incidents (Graph email lives in app).
# It NEVER remediates — observe & report only. Stdlib only (no pip deps).
import subprocess, uuid, re

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
ing = []
for qt, days in psql("SELECT query_type, ROUND(EXTRACT(EPOCH FROM now()-MAX(processed_at))/86400,1) "
                     "FROM bi_ingestion_log GROUP BY query_type"):
    d = float(days); st = "crit" if d > ic else ("warn" if d > iw else "ok"); ing.append(st)
    add("pipeline.ingest.%s" % qt, "pipeline", "ERP aktarim: %s" % qt, st,
        "%.1f gun" % d, "Son islenen veri %.1f gun once." % d, d)
if ing:
    add("pipeline.ingest.overall", "pipeline", "ERP veri aktarimi (genel)", worst(ing), "",
        "En kotu besleme durumu.")

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
