# -*- coding: utf-8 -*-
# YETKI_FAZ5B (tenant-admin.js) — Denetim > "Yetki Gunlugu" gorunumu (kim/kime/ne zaman ne verdi-aldi) +
#   eski "Izinler" grid'ini nav'dan KALDIR (renderPermissions kod olarak durur). Stiller taStyles() yl-* (gomme yok).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ5B" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "YETKI_FAZ5" in s, "once YETKI_FAZ5 (renderYetkiDenetim) olmali"

# 1) nav — Yetki Denetimi'nden sonra Yetki Gunlugu
NAV = '''        ${navBtn("yetki-denetim", "Yetki Denetimi", '<path d="M12 2l7 4v6c0 5-3.5 8-7 10-3.5-2-7-5-7-10V6z"/><path d="M9 12l2 2 4-4"/>')}  <!-- YETKI_FAZ5 -->'''
assert s.count(NAV) == 1, "nav yetki-denetim anchor=%d" % s.count(NAV)
s = s.replace(NAV, NAV + '''
        ${navBtn("yetki-log", "Yetki Günlüğü", '<path d="M12 8v4l3 3"/><circle cx="12" cy="12" r="9"/>')}  <!-- YETKI_FAZ5B -->''', 1)

# 2) renderView map
MAP = '      "yetki-denetim": ["Yetki Denetimi", "Etkin-yetki denetçisi — bir kişinin yetkisi nereden geliyor", renderYetkiDenetim],  /* YETKI_FAZ5 */'
assert s.count(MAP) == 1, "map yetki-denetim anchor=%d" % s.count(MAP)
s = s.replace(MAP, MAP + '\n      "yetki-log": ["Yetki Günlüğü", "Yetki değişiklik günlüğü — kim, kime, ne zaman, ne", renderYetkiLog],  /* YETKI_FAZ5B */', 1)

# 3) eski Izinler nav butonu -> kaldir
IZNAV = '''        ${navBtn("permissions", "İzinler", '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/>')}'''
assert s.count(IZNAV) == 1, "izinler nav anchor=%d" % s.count(IZNAV)
s = s.replace(IZNAV, '''        <!-- YETKI_FAZ5B: eski "İzinler" grid nav'dan kaldırıldı (Bölümler/Kişiler/Roller/Denetim yerini aldı; renderPermissions kod olarak durur) -->''', 1)

# 4) eski Izinler view map -> kaldir
IZMAP = '      permissions: ["İzinler", "Modül ve alt-araç erişim matrisi", renderPermissions],'
assert s.count(IZMAP) == 1, "izinler map anchor=%d" % s.count(IZMAP)
s = s.replace(IZMAP, '      /* YETKI_FAZ5B: "permissions" (eski İzinler grid) nav\'dan kaldırıldı; renderPermissions kod olarak durur */', 1)

# 5) renderYetkiLog — renderMusteriAtama'dan once
FN_ANCH = '  async function renderMusteriAtama(content, actions) {'
assert s.count(FN_ANCH) == 1, "renderMusteriAtama anchor=%d" % s.count(FN_ANCH)
FN = r'''  async function renderYetkiLog(content) {  /* YETKI_FAZ5B */
    content.innerHTML = `<div class="ta-loading"><div class="ta-spin"></div>Yükleniyor…</div>`;
    let d; try { d = await apiFetch("/api/tenant/yetki-log?limit=100"); } catch(e){ content.innerHTML = `<div class="ta-empty">Yüklenemedi: ${esc(e.message)}</div>`; return; }
    const log = d.log || [];
    const eL = { kisi_yetki:"Kişi yetkisi", bolum_uygula:"Bölüm uygula", uyelik:"Üyelik", rol:"Rol" };
    const rel = (ts)=>{ const t=new Date(ts); if(isNaN(t))return"—"; const s2=Math.floor((Date.now()-t.getTime())/1000); if(s2<60)return"az önce"; if(s2<3600)return Math.floor(s2/60)+" dk önce"; if(s2<86400)return Math.floor(s2/3600)+" sa önce"; if(s2<2592000)return Math.floor(s2/86400)+" gün önce"; return t.toLocaleDateString("tr-TR"); };
    const det = (l)=>{ const x=l.detay||{}; if(l.eylem==="kisi_yetki")return `${x.dep??"?"} yetki · +${x.grant??0}/−${x.deny??0}${x.role?" · "+esc(String(x.role)):""}`; if(l.eylem==="bolum_uygula")return `${x.uygulandi??0} üyeye uygulandı`; if(l.eylem==="uyelik")return `+${x.eklendi??0} / −${x.cikarildi??0} üye`; return esc(JSON.stringify(x)); };
    const rows = log.map(l=>{ const actor=l.actor_ad||l.actor_email||"—"; const hedef=l.target_ad||l.target_email||(l.dept_ad?((l.dept_ikon||"🏷️")+" "+l.dept_ad):"—"); return `<tr><td class="yl-t">${esc(rel(l.ts))}</td><td>${esc(actor)}</td><td><span class="yl-ey yl-ey-${esc(l.eylem)}">${esc(eL[l.eylem]||l.eylem)}</span></td><td>${esc(hedef)}</td><td class="yl-d">${det(l)}</td></tr>`; }).join("");
    content.innerHTML = `<div class="yl-wrap"><table class="yl-tbl"><thead><tr><th>Ne zaman</th><th>Kim</th><th>Eylem</th><th>Kime / Nereye</th><th>Detay</th></tr></thead><tbody>${rows||`<tr><td colspan="5" class="ta-empty" style="padding:20px">Henüz yetki değişikliği kaydı yok — bir bölüm uygula ya da Kişiler'den kaydet, burada görünür.</td></tr>`}</tbody></table></div>`;
  }

'''
s = s.replace(FN_ANCH, FN + FN_ANCH, 1)

# 6) yl-* CSS — yd bloğunun sonuna
CSS_ANCH = '     .yd-src-none{background:#f8fafc;color:#94a3b8;border-color:#eef2f6}'
assert s.count(CSS_ANCH) == 1, "yd-src-none css anchor=%d" % s.count(CSS_ANCH)
CSS = CSS_ANCH + '''
     /* YETKI_FAZ5B — yetki gunlugu */
     .yl-wrap{overflow-x:auto}
     .yl-tbl{width:100%;border-collapse:collapse;font-size:13px}
     .yl-tbl th{text-align:left;padding:8px 10px;color:#6b7280;font-weight:800;border-bottom:1px solid #e6e8ee;font-size:11px;text-transform:uppercase;letter-spacing:.03em;white-space:nowrap}
     .yl-tbl td{padding:9px 10px;border-bottom:1px solid #f1f5f9;color:#111827;vertical-align:top}
     .yl-t{color:#6b7280;white-space:nowrap}
     .yl-d{color:#475569}
     .yl-ey{display:inline-block;font-size:11px;font-weight:700;padding:2px 9px;border-radius:999px;background:#f1f5f9;color:#334155;white-space:nowrap}
     .yl-ey-kisi_yetki{background:#eff6ff;color:#1d4ed8}
     .yl-ey-bolum_uygula{background:#f5f3ff;color:#6d28d9}
     .yl-ey-uyelik{background:#ecfdf5;color:#047857}'''
s = s.replace(CSS_ANCH, CSS, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ5B (tenant-admin.js) — Yetki Gunlugu gorunumu + Izinler nav kaldirma + yl-* stiller")
