# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# RESET_LINK_FIX2 — when ?reset= is present, don't restore session or applyRole
# (which triggers initPlatformSession's pre-hide -> dark screen). Just show the
# set-password form (handled by the existing override + wireEvents).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "app.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) restoreSession bails on a reset link
rep("  if (!email || activeSurveyToken) {\n    return false;\n  }",
    "  if (!email || activeSurveyToken || activeResetToken) {\n    return false;\n  }",
    "restore-bail")

# 2) don't applyRole (which fires initPlatformSession) when a reset link is present
rep('''if (!sessionRestored) {
  applyRole(activeContextToken || activeSurveyToken || activeRespondToken ? "participant" : resolveRoleForEmail(currentUserEmail));
}''',
    '''if (!sessionRestored && !activeResetToken) {
  applyRole(activeContextToken || activeSurveyToken || activeRespondToken ? "participant" : resolveRoleForEmail(currentUserEmail));
}''',
    "skip-applyrole")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
