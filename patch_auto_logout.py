import sys, io
path = sys.argv[1]
with io.open(path, encoding="utf-8") as f: src = f.read()
if "AUTO_LOGOUT_V1" in src:
    print("[patch_auto_logout] zaten uygulanmis, atlaniyor."); sys.exit(0)

BLOCK = r'''
// ═══ AUTO_LOGOUT_V1 — rol-bazli oto cikis (guvenlik) ══════════════════════════
//   Yonetici/mudur (web): 30 dk bosta -> uyari -> cikis. Herkes: mutlak sure
//   (yonetici/mudur 24s, saha temsilcisi 7g). Native app'te bosta-cikis YOK
//   (cihaz kilidi devrede); yalniz mutlak sure. Sabitler asagidan degistirilebilir.
//   Oturum yoksa (login ekrani) hicbir sey yapmaz.
(function(){
  if (typeof window === "undefined" || window.__autoLogoutV1) return;
  window.__autoLogoutV1 = true;

  var IDLE_MIN_STAFF  = 30;   // dk — yonetici/mudur bosta (yalniz web)
  var ABS_HOURS_STAFF = 24;   // saat — yonetici/mudur mutlak
  var ABS_HOURS_REP   = 168;  // saat — saha temsilcisi mutlak (7 gun)
  var WARN_SEC        = 60;   // bosta uyari geri sayimi (sn)

  var CAP = window.Capacitor;
  var isNative = !!(CAP && CAP.isNativePlatform && CAP.isNativePlatform());

  function me(){ try { return JSON.parse(localStorage.getItem("currentPlatformUser")||"null"); } catch(e){ return null; } }
  function policy(){
    var m = me(); if (!m) return null;
    var subs = m.subscriptions || [];
    var admin = m.tenantRole === "platform_owner" || subs.some(function(s){ return s.moduleRole==="admin"; });
    var manager = subs.some(function(s){ return s.moduleRole==="manager"; });
    var staff = admin || manager;
    return { idleMs: (!isNative && staff) ? IDLE_MIN_STAFF*60000 : 0,
             absMs: (staff ? ABS_HOURS_STAFF : ABS_HOURS_REP) * 3600000 };
  }

  var last = Date.now(), warnEl = null, warnType = null, busy = false;
  function bump(){ var n = Date.now(); if (n - last > 1500) last = n; if (warnEl && warnType === "idle") closeWarn(); }
  ["pointerdown","keydown","touchstart","scroll","mousemove"].forEach(function(ev){
    window.addEventListener(ev, bump, { passive: true });
  });

  function doLogout(){
    if (busy) return; busy = true;
    try { var tok = localStorage.getItem("platformSessionToken");
      fetch("/api/auth/logout", { method:"POST", credentials:"include", headers: tok ? { Authorization:"Bearer "+tok } : {} }); } catch(e){}
    ["krbCurrentUserEmail","krbSession","currentPlatformUser","platformSessionToken","krbLoginAt"].forEach(function(k){ try{ localStorage.removeItem(k); }catch(e){} });
    setTimeout(function(){ location.href = "/?app=1"; }, 300);
  }

  function closeWarn(){ if (warnEl){ if (warnEl._t) clearInterval(warnEl._t); if (warnEl._to) clearTimeout(warnEl._to); warnEl.remove(); warnEl = null; warnType = null; } }
  function shell(inner){
    var el = document.createElement("div");
    el.style.cssText = "position:fixed;inset:0;z-index:100001;background:rgba(0,0,0,.55);display:flex;align-items:center;justify-content:center;padding:24px";
    el.innerHTML = '<div style="background:#fff;border-radius:16px;max-width:340px;width:100%;padding:22px;box-shadow:0 20px 60px rgba(0,0,0,.45);text-align:center">'+inner+'</div>';
    document.body.appendChild(el); return el;
  }
  function idleWarn(){
    warnType = "idle";
    warnEl = shell('<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Oturum zaman asimi</div>'
      +'<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">Bir suredir islem yapmadiniz. Guvenlik icin <b><span id="alo-say">'+WARN_SEC+'</span> sn</b> icinde cikis yapilacak.</div>'
      +'<button id="alo-stay" style="width:100%;padding:12px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:14px;font-weight:700;font-family:inherit;cursor:pointer">Oturumu acik tut</button>');
    var s = WARN_SEC;
    warnEl._t = setInterval(function(){ s--; var e=document.getElementById("alo-say"); if(e) e.textContent=s; if(s<=0){ closeWarn(); doLogout(); } }, 1000);
    warnEl.querySelector("#alo-stay").addEventListener("click", function(){ last = Date.now(); closeWarn(); });
  }
  function absWarn(){
    warnType = "abs";
    warnEl = shell('<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Oturum suresi doldu</div>'
      +'<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">Guvenlik icin oturum suresi doldu. Yeniden giris yapmaniz gerekiyor.</div>'
      +'<button id="alo-ok" style="width:100%;padding:12px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:14px;font-weight:700;font-family:inherit;cursor:pointer">Yeniden giris</button>');
    warnEl._to = setTimeout(doLogout, 12000);
    warnEl.querySelector("#alo-ok").addEventListener("click", doLogout);
  }

  setInterval(function(){
    if (busy) return;
    var m = me();
    if (!m){ if (warnEl) closeWarn(); try{ localStorage.removeItem("krbLoginAt"); }catch(e){} return; }
    var p = policy(); if (!p) return;
    var loginAt = parseInt(localStorage.getItem("krbLoginAt")||"0", 10);
    if (!loginAt){ loginAt = Date.now(); try{ localStorage.setItem("krbLoginAt", String(loginAt)); }catch(e){} }
    var now = Date.now();
    if (p.absMs && (now - loginAt) >= p.absMs){ if (warnType !== "abs"){ closeWarn(); absWarn(); } return; }
    if (p.idleMs){ var idle = now - last; if (idle >= p.idleMs - WARN_SEC*1000){ if (!warnEl) idleWarn(); } }
  }, 5000);
})();
'''
if not src.endswith("\n"): src += "\n"
src += BLOCK + "\n"
with io.open(path, "w", encoding="utf-8") as f: f.write(src)
print("[patch_auto_logout] eklendi.")
