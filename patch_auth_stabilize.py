# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# AUTH_STABILIZE_V1 — make platform-session (subscriptions) the router:
#  - show the loading spinner during the platform/me gap instead of a dark screen
#  - hide it once surfaces load
#  - never render the participant/assessment fallback while platform session routes
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "app.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) pre-hide: show loading spinner instead of a blank/dark screen
rep('''    window.__platformSessionPending = true;
    ['.sidebar', '.topbar', '#workspace-shell-panel', '.main', '.app-shell'].forEach(function(sel) {
      const el = document.querySelector(sel);
      if (el) el.style.display = 'none';
    });
  }''',
    '''    window.__platformSessionPending = true;
    ['.sidebar', '.topbar', '#workspace-shell-panel', '.main', '.app-shell'].forEach(function(sel) {
      const el = document.querySelector(sel);
      if (el) el.style.display = 'none';
    });
    const _plLoad = document.querySelector('#app-loading'); if (_plLoad) _plLoad.style.display = 'flex';
  }''',
    "loading-on")

# 2) success: hide the loading spinner once surfaces are up
rep('    return true; // handled — caller should not route to regular shells',
    '    const _plDone = document.querySelector("#app-loading"); if (_plDone) _plDone.style.display = "none";\n    return true; // handled — caller should not route to regular shells',
    "loading-off")

# 3) don't render the participant/assessment fallback while platform session routes
rep('''  setActiveView(defaultView);
}

function badgeClass(value) {''',
    '''  if (window.__platformSessionPending) return;
  setActiveView(defaultView);
}

function badgeClass(value) {''',
    "guard-fallback")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
