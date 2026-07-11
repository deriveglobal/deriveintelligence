# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OWNER_GATE_FRONT — the Sistem tab is platform-IT telemetry (API/JS errors,
# endpoints, latency). It is NOT tenant business. Both platform_owner and tenant
# admin collapse to role 'admin', so keep the real distinction (S.isOwner) and
# gate Sistem on it. "Temsilci" stays with tenant manager/admin. The feedback
# SUBMIT path (Bugün tab) is untouched — reps must still be able to report issues.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) keep the platform-owner distinction on state
rep(
'''  const role = (me.tenantRole === "platform_owner" || sub.moduleRole === "admin") ? "admin"
    : (sub.moduleRole === "manager" ? "manager" : "rep");
  S = {
    container, me, role, headers,''',
'''  const role = (me.tenantRole === "platform_owner" || sub.moduleRole === "admin") ? "admin"
    : (sub.moduleRole === "manager" ? "manager" : "rep");
  // platform_owner (Derive) and tenant admin both map to role 'admin'. Keep the real
  // distinction: platform telemetry must never be shown to a tenant.
  const isOwner = me.tenantRole === "platform_owner";
  S = {
    container, me, role, isOwner, headers,''',
    "s-isowner")

# 2) Sistem tab -> platform owner only; Temsilci stays tenant manager/admin
rep(
'''    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"], ["sistem", "🔧", "Sistem"]] : [])''',
'''    ...(["manager","admin"].includes(S.role) ? [["temsilciler", "👥", "Temsilci"]] : []),
    ...(S.isOwner ? [["sistem", "🔧", "Sistem"]] : [])''',
    "sistem-tab-gate")

# 3) harden the view's own guard (defence in depth: deep-link can't reach it either)
rep(
'''async function vSistem() {
  if (!["manager","admin"].includes(S.role)) {''',
'''async function vSistem() {
  if (!S.isOwner) {''',
    "vsistem-guard")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
