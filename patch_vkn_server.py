# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# VKN_EDIT_SERVER — let a rep add/update a customer's tax number later via the
# existing PUT /api/saha/musteriler/:id. Adds vergi_no + tc_no to the update
# allowlist, digits-only. Ownership check already enforced above (rep can only
# edit own customers). This is what makes the future ERP-promotion-by-tax-no work.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
    '      // aktif (soft-delete) sadece müdür/admin yetkisi gerektirir',
    r'''      // vergi_no / tc_no — digits-only, addable later (enables ERP promotion by tax no)
      for (const f of ["vergi_no", "tc_no"]) {
        if (Object.prototype.hasOwnProperty.call(p, f)) {
          const dv = p[f] ? String(p[f]).replace(/\D/g, "") : null;
          params.push(dv || null); sets.push(`${f} = $${params.length}`);
        }
      }
      // aktif (soft-delete) sadece müdür/admin yetkisi gerektirir''',
    "vkn-put-allowlist")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
