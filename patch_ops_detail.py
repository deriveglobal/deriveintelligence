# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OPS_DETAIL — the check scraped only the FAILURE *count* from saha_audit and wrote
# a hardcoded detail string, so the alert email said "1 kritik durum" and named
# nothing. Put the real FAIL lines into detail. Also retitle: the check covers the
# whole saha audit (endpoints + code), not just endpoint coverage.
# check_key stays 'app.endpoint_coverage' so the existing open incident reconciles.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "ops_monitor.py"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''    mm = re.search(r"TOTAL:\\s*\\d+ passed,\\s*\\d+ warnings,\\s*(\\d+) FAILURES", au)
    fails = int(mm.group(1)) if mm else -1
    st = "ok" if fails == 0 else ("crit" if fails > 0 else "warn")
    add("app.endpoint_coverage", "app", "Uc nokta kapsamasi (saha)", st,
        ("%d hata" % fails) if fails >= 0 else "?", "Front<->server uc nokta denetimi.", fails)''',
'''    mm = re.search(r"TOTAL:\\s*\\d+ passed,\\s*\\d+ warnings,\\s*(\\d+) FAILURES", au)
    fails = int(mm.group(1)) if mm else -1
    st = "ok" if fails == 0 else ("crit" if fails > 0 else "warn")
    # Name the actual failures. An alert you cannot act on is only half an alert.
    _fl = [re.sub(r"\\s+", " ", l.strip()[4:].strip(" :")) for l in au.splitlines()
           if l.strip().startswith("FAIL")]
    _fl = [x.replace("'", "\\"") for x in _fl if x]
    if _fl:
        _d = " | ".join(_fl[:5])[:400]
        if len(_fl) > 5:
            _d += " | (+%d daha)" % (len(_fl) - 5)
    else:
        _d = "Saha denetimi temiz (uc nokta + kod)."
    add("app.endpoint_coverage", "app", "Saha denetimi (uc nokta + kod)", st,
        ("%d hata" % fails) if fails >= 0 else "?", _d, fails)''',
    "ops-detail-names-failures")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
