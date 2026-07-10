# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# RESET_LINK_FIX — a password-reset link (?reset=TOKEN) must always show the
# set-password form, never the (participant) app shell / Permission Denied,
# regardless of any existing saved session. Final override, runs last.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "app.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = '''} else if (!sessionRestored && shouldOpenAppShell) {
  showAuthPanel();
}'''
NEW = OLD + '''

// RESET_LINK_FIX — reset link always shows the set-password form, never the app shell.
if (activeResetToken) {
  document.querySelector(".app-shell")?.classList.add("hidden");
  document.querySelector("#auth-screen")?.classList.remove("hidden");
  const _rlLoad = document.querySelector("#app-loading"); if (_rlLoad) _rlLoad.style.display = "none";
  document.querySelector("#auth-form")?.classList.add("hidden");
  document.querySelector("#forgot-password-form")?.classList.add("hidden");
  document.querySelector("#forgot-password-button")?.classList.add("hidden");
  document.querySelector("#reset-password-form")?.classList.remove("hidden");
  const _rlT = document.querySelector("#auth-title"); if (_rlT) _rlT.textContent = "Reset password";
  const _rlS = document.querySelector("#auth-subtitle"); if (_rlS) _rlS.textContent = "Choose a new password for your assessment platform account.";
}'''

c = s.count(OLD)
assert c == 1, "ABORT: boot chain anchor found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: reset-link-override")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
