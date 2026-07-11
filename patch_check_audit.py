# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# CHECK_AUDIT — add the check that would have caught FOUR bugs found by humans today:
#   'rep-manager' -> saha_konusma.tip      (CHECK: BIREYSEL|YAYIM)     -> rep Mesajlar 500
#   'BEKLEMEDE'   -> saha_oneri.durum      (CHECK: YENI|INCELENIYOR..) -> feedback submit broken
#   'GENEL'       -> saha_oneri.kategori   (CHECK: HATA|OZELLIK|UI..)  -> feedback submit broken
#   'BINEK'       -> bi_fiyat_iskonto.arac_tipi (CHECK: PASSENGER|..)  -> price migration failed 418x
# All four were the identical mistake: code writing an enum string the column's CHECK
# constraint does not allow. node --check can't see it; the endpoint audit can't see it;
# it only surfaces when a specific user walks a specific path.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "saha_audit.py"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''print("\\n=== 3) Endpoint liveness (no auth -> expect 401, not 404/500) ===")''',
'''print("\\n=== 2b) Hardcoded enum strings vs the column's CHECK constraint ===")
# Build {table: {column: {allowed values}}} from the DB's real constraints.
_enum = {}
for _line in psql(
    "SELECT c.conrelid::regclass::text||'~'||a.attname||'~'||pg_get_constraintdef(c.oid) "
    "FROM pg_constraint c JOIN pg_attribute a "
    "  ON a.attrelid=c.conrelid AND a.attnum = ANY(c.conkey) "
    "WHERE c.contype='c' AND array_length(c.conkey,1)=1"
).splitlines():
    parts = _line.split("~", 2)
    if len(parts) != 3:
        continue
    _t, _c, _def = parts[0].strip(), parts[1].strip(), parts[2]
    _vals = set(re.findall(r"'([^']+)'::text", _def)) or set(re.findall(r"'([^']+)'", _def))
    if _vals:
        _enum.setdefault(_t, {})[_c] = _vals

def _split_top(txt):
    """split a VALUES(...) body on commas at paren-depth 0"""
    out, depth, cur = [], 0, ""
    for ch in txt:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip()); cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out

_hits = 0

# (a) INSERT INTO tbl (cols) VALUES (...) — map literals to columns POSITIONALLY
for m in re.finditer(r"INSERT INTO\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*VALUES\\s*\\(", src):
    tbl = m.group(1)
    if tbl not in _enum:
        continue
    cols = [c.strip().strip('"') for c in m.group(2).replace("\\n", " ").split(",")]
    # walk forward to the matching close paren of VALUES(
    i = m.end(); depth = 1; body = ""
    while i < len(src) and depth:
        ch = src[i]
        if ch == "(": depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0: break
        body += ch; i += 1
    vals = _split_top(body)
    if len(vals) != len(cols):
        continue
    for col, val in zip(cols, vals):
        allowed = _enum[tbl].get(col)
        if not allowed:
            continue
        lit = re.fullmatch(r"'([^']*)'", val.strip())
        if lit and lit.group(1) not in allowed:
            bad("%s.%s <- '%s' ihlal; izinli: %s" % (tbl, col, lit.group(1), "|".join(sorted(allowed))))
            _hits += 1

# (b) SET col = 'X'  /  WHERE col = 'X'  — catches UPDATE and SELECT literals
for tbl, cols in _enum.items():
    if tbl not in src:
        continue
    for col, allowed in cols.items():
        for m in re.finditer(r"\\b%s\\s*=\\s*'([^']*)'" % re.escape(col), src):
            v = m.group(1)
            if v and v not in allowed:
                bad("%s.%s = '%s' ihlal; izinli: %s" % (tbl, col, v, "|".join(sorted(allowed))))
                _hits += 1

if _hits == 0:
    ok("tum sabit enum degerleri CHECK kisitlariyla uyumlu (%d tablo tarandi)" % len(_enum))

print("\\n=== 3) Endpoint liveness (no auth -> expect 401, not 404/500) ===")''',
    "check-constraint-audit")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
