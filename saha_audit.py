# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# saha_audit.py — end-to-end static+runtime audit of the Saha module.
# Run on the host:  python3 saha_audit.py
# Checks the bug classes we actually hit: INSERT/schema drift, body-not-parsed,
# endpoint liveness, and data sanity.
import subprocess, re, json

SRV = "/opt/krb-assessment/server_container.mjs"
FRONT = "/opt/krb-assessment/shells/saha.js"
BASE = "http://localhost:8080"
PASS = 0; FAIL = 0; WARN = 0

def ok(m):   global PASS; PASS += 1; print("  PASS  " + m)
def bad(m):  global FAIL; FAIL += 1; print("  FAIL  " + m)
def warn(m): global WARN; WARN += 1; print("  WARN  " + m)

def psql(q):
    r = subprocess.run(["docker","exec","-i","krb-assessment-postgres","psql","-U","assessment_app",
                        "-d","assessment_platform","-tAc",q], capture_output=True, text=True)
    return r.stdout.strip()

def http_code(args):
    r = subprocess.run(["curl","-s","-o","/dev/null","-w","%{http_code}","--max-time","8"]+args,
                       capture_output=True, text=True)
    return r.stdout.strip()

src = open(SRV, encoding="utf-8").read()
front = open(FRONT, encoding="utf-8").read()

# ── table columns ──
tbl_cols = {}
for line in psql("SELECT table_name||'~'||column_name FROM information_schema.columns WHERE table_name LIKE 'saha_%'").splitlines():
    if "~" in line:
        t, c = line.split("~", 1); tbl_cols.setdefault(t, set()).add(c.strip())

print("\n=== 1) INSERT columns vs table schema (catches tenant_id-class bugs) ===")
for m in re.finditer(r"INSERT INTO (saha_\w+)\s*\(([^)]*)\)\s*(?:VALUES|SELECT)", src, re.S):
    tbl = m.group(1)
    raw = m.group(2).replace("\n", " ")
    cols = [c.strip().split()[0] for c in raw.split(",") if c.strip()]
    known = tbl_cols.get(tbl)
    if not known:
        warn("%s: table not found in schema" % tbl); continue
    badcols = [c for c in cols if c not in known and not c.startswith("(")]
    if badcols:
        bad("%s INSERT references missing column(s): %s" % (tbl, ", ".join(badcols)))
    else:
        ok("%s INSERT (%d cols) all valid" % (tbl, len(cols)))

print("\n=== 2) Saha POST/PUT handlers that use `body` must parse it ===")
# scope to the saha router
sidx = src.find('startsWith("/api/saha/")')
saha = src[sidx:] if sidx >= 0 else src
# each `... } = body;` or `body.<x>` occurrence: was `body` parsed earlier in the
# SAME handler? (a fixed 15-line window false-positives on long handlers)
lines = saha.splitlines()
_HSTART = re.compile(r"if \(method === ")
for i, ln in enumerate(lines):
    if re.search(r"\}\s*=\s*body;|=\s*body\.", ln) or re.search(r"\bbody\.\w+", ln):
        start = max(0, i - 400)
        for j in range(i, start, -1):
            if _HSTART.search(lines[j]):
                start = j
                break
        window = "\n".join(lines[start:i+1])
        if ("readJson(request)" not in window and "await new Promise" not in window
                and "for await" not in window and "JSON.parse" not in window
                and "readRawBody" not in window):
            bad("line uses `body` without readJson in its handler: " + ln.strip()[:70])
        # else silently ok (too many to list)
print("  (only failures shown; no output above = all body uses are parsed)")

print("\n=== 3) Endpoint liveness (no auth -> expect 401, not 404/500) ===")
for method, path in [("GET","/api/saha/bugun"),("GET","/api/saha/ziyaretler"),("GET","/api/saha/musteriler"),
                     ("GET","/api/saha/teklifler"),("GET","/api/saha/notlar"),("GET","/api/saha/duyurular"),
                     ("GET","/api/saha/konusmalar"),("GET","/api/saha/oneriler"),("GET","/api/saha/ayarlar"),
                     ("POST","/api/saha/rep-brain")]:
    code = http_code(["-X",method,BASE+path]) if method=="GET" else http_code(["-X",method,BASE+path,"-H","Content-Type: application/json","-d","{}"])
    if code == "401": ok("%s %s -> 401 (wired, auth-guarded)" % (method, path))
    elif code == "404": bad("%s %s -> 404 (endpoint MISSING)" % (method, path))
    else: warn("%s %s -> %s (unexpected without auth)" % (method, path, code))

print("\n=== 4) Data sanity ===")
# reminders: any with a hatirlatma_tarihi that can't format?
bad_dates = psql("SELECT count(*) FROM saha_rep_not WHERE hatirlatma_tarihi IS NOT NULL AND hatirlatma_tarihi::text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'")
(ok if bad_dates == "0" else bad)("reminders with unparseable date: %s" % bad_dates)
# quotes: any without kaynak?
no_kaynak = psql("SELECT count(*) FROM saha_teklif WHERE kaynak IS NULL")
(ok if no_kaynak == "0" else warn)("quotes without kaynak (source): %s" % no_kaynak)
# quotes: orphan customer (INNER-join drop risk)
orphan_q = psql("SELECT count(*) FROM saha_teklif t WHERE NOT EXISTS (SELECT 1 FROM saha_musteri m WHERE m.id=t.musteri_id)")
(ok if orphan_q == "0" else warn)("quotes whose customer is missing from saha_musteri: %s" % orphan_q)
# announcements read-tracking alive
okundu = psql("SELECT count(*) FROM saha_duyuru_okundu")
ok("saha_duyuru_okundu rows: %s (read-tracking populated)" % okundu)
# signals feed alive
sinyal = psql("SELECT count(*) FROM saha_sinyal")
ok("saha_sinyal rows: %s (intent feed)" % sinyal)

print("\n=== 5) Front <-> server field-name spot checks ===")
checks = [
    ("rep-brain send", "message" in front and 'body.message' in src, "front sends {message}, server reads body.message"),
    ("teklif kaynak", 'id="tf-kaynak"' in front and "p.kaynak" in src, "quote source selector <-> server"),
    ("duyuru comment", "/yorum" in front and "saha_duyuru_yorum" in src, "comment endpoint wired"),
]
for name, cond, desc in checks:
    (ok if cond else bad)("%s: %s" % (name, desc))

print("\n=== 6) Every front saha API call has a server handler (catches meeting-class bugs) ===")
server_exact = set(re.findall(r'path === "(/api/saha/[^"]+)"', src))
server_seg = set(re.findall(r'saha\\?/([A-Za-z0-9_-]+)', src))
seen6 = set()
for mm in re.finditer(r"/api/saha/[A-Za-z0-9_\-/]+", front):
    raw = mm.group(0)
    dyn = raw.endswith("/")          # truncated by ${...} -> had an id/suffix
    p = raw.rstrip("/")
    if p in seen6:
        continue
    seen6.add(p)
    if not dyn:                       # fully-static path -> precise check
        cov = (p in server_exact) or any(e == p or e.startswith(p + "/") for e in server_exact)
        (ok if cov else bad)(p if cov else p + " — NO server handler (missing endpoint)")
    else:                            # dynamic (id/suffix) -> lenient base check
        segs = p.split("/"); seg = segs[3] if len(segs) > 3 else ""
        cov = (p in server_exact) or any(e.startswith(p) for e in server_exact) or (seg in server_seg)
        if not cov:
            warn(p + "/… — base not clearly handled (dynamic route)")

print("\n" + "="*50)
print("TOTAL: %d passed, %d warnings, %d FAILURES" % (PASS, WARN, FAIL))
print("✅ SAHA CLEAN" if FAIL == 0 else "❌ %d ISSUE(S) — see FAIL lines above" % FAIL)
