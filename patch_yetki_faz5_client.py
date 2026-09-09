# -*- coding: utf-8 -*-
# YETKI_FAZ5 (tenant-admin.js) — Denetim > "Yetki Denetimi" gorunumu: kisi sec -> her saha yetkisi NEREDEN
#   (bolum / kisisel-ekleme / kisisel-cikarma / admin). Salt-oku. Stiller taStyles() yd-* (gomme yok).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ5" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) nav butonu — Aktivite'den sonra
NAV = '''        ${navBtn("aktivite", "Aktivite", '<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>')}'''
assert s.count(NAV) == 1, "nav aktivite anchor=%d" % s.count(NAV)
NAV2 = NAV + '''
        ${navBtn("yetki-denetim", "Yetki Denetimi", '<path d="M12 2l7 4v6c0 5-3.5 8-7 10-3.5-2-7-5-7-10V6z"/><path d="M9 12l2 2 4-4"/>')}  <!-- YETKI_FAZ5 -->'''
s = s.replace(NAV, NAV2, 1)

# 2) renderView map
MAP = '      aktivite: ["Aktivite", "Saha temsilci aktivitesi", renderAktivite],'
assert s.count(MAP) == 1, "map aktivite anchor=%d" % s.count(MAP)
MAP2 = MAP + '\n      "yetki-denetim": ["Yetki Denetimi", "Etkin-yetki denetçisi — bir kişinin yetkisi nereden geliyor", renderYetkiDenetim],  /* YETKI_FAZ5 */'
s = s.replace(MAP, MAP2, 1)

# 3) renderYetkiDenetim fonksiyonu — renderMusteriAtama'dan once
FN_ANCH = '  async function renderMusteriAtama(content, actions) {'
assert s.count(FN_ANCH) == 1, "renderMusteriAtama anchor=%d" % s.count(FN_ANCH)
FN = r'''  async function renderYetkiDenetim(content) {  /* YETKI_FAZ5 */
    const usersD = await apiFetch("/api/tenant/users");
    const cfg = MODULES.saha, groups = cfg.groups;
    let sel = null, q = "";
    content.innerHTML = `<div class="tk-wrap"><div class="tk-side"><div class="tk-search"><input id="yd-q" placeholder="Kişi ara — ad, e-posta"></div><div class="tk-list" id="yd-list"></div></div><div class="tk-main" id="yd-main"></div></div>`;
    const listEl = content.querySelector("#yd-list"), mainEl = content.querySelector("#yd-main");
    const drawList = () => {
      const f = usersD.filter(u => !q || (`${u.full_name||''} ${u.email||''}`.toLowerCase().includes(q)));
      listEl.innerHTML = f.map(u => { const nm=u.full_name||u.email||'—'; const m=(u.module_access||[]).find(x=>x&&x.module_id==='saha'); const rl=(m&&m.module_role)||'—'; return `<div class="tk-urow${u.id===sel?' on':''}" data-id="${u.id}"><div class="tk-av">${esc(nm.trim().slice(0,2).toUpperCase())}</div><div class="tk-uinfo"><b>${esc(nm)}</b><small>${esc(u.email||'')}</small></div><span class="tk-ubadge">${esc(rl)}</span></div>`; }).join("") || `<div class="ta-empty">Kişi yok.</div>`;
      listEl.querySelectorAll("[data-id]").forEach(r=>r.addEventListener("click",()=>{ sel=r.dataset.id; drawList(); drawMain(); }));
    };
    document.getElementById("yd-q").addEventListener("input", e=>{ q=e.target.value.toLowerCase(); drawList(); });
    async function drawMain() {
      const u = usersD.find(x=>x.id===sel); if (!u) { mainEl.innerHTML = `<div class="ta-empty">Soldan bir kişi seç — yetkisinin nereden geldiğini gör.</div>`; return; }
      mainEl.innerHTML = `<div class="ta-loading"><div class="ta-spin"></div>Yükleniyor…</div>`;
      let d; try { d = await apiFetch(`/api/tenant/users/${u.id}/yetki-kaynak`); } catch(e){ mainEl.innerHTML = `<div class="ta-empty">Yüklenemedi: ${esc(e.message)}</div>`; return; }
      const nm = u.full_name||u.email||'—';
      const role = d.module_role || '—';
      const isAdmin = role === 'admin';
      const dU = new Set(); (d.bolumler||[]).forEach(b=>(b.caps||[]).forEach(c=>dU.add(c)));
      const grant = new Set(d.personal_grant||[]), deny = new Set(d.personal_deny||[]), eff = new Set(d.departments||[]);
      const capDepts = (cap) => (d.bolumler||[]).filter(b=>(b.caps||[]).includes(cap)).map(b=>b.ad);
      const src = (cap) => {
        if (isAdmin) return {c:"admin", t:"admin"};
        if (deny.has(cap)) return {c:"deny", t:"kişisel ✗"};
        if (eff.has(cap)) { const inD=dU.has(cap), inG=grant.has(cap); if (inD&&inG) return {c:"both", t:"bölüm+kişisel"}; if (inD) return {c:"dept", t:"bölüm"}; if (inG) return {c:"grant", t:"kişisel +"}; return {c:"eff", t:"var"}; }
        return {c:"none", t:"—"};
      };
      const scopeLbl = (d.scope && d.scope.level) ? d.scope.level : "tümü";
      const bolChips = (d.bolumler||[]).length ? d.bolumler.map(b=>`<span class="yd-bchip">${esc(b.ikon||'🏷️')} ${esc(b.ad)}</span>`).join("") : `<span class="yd-muted">bölüm yok</span>`;
      const grpHtml = groups.map(g=>{
        const caps = g[1].map(t=>{ const sc=src(t[0]); const deps=capDepts(t[0]);
          const title = (sc.c==='dept'||sc.c==='both') ? ("Bölüm: "+deps.join(", ")) : sc.c==='grant' ? "Kişiler'den eklendi" : sc.c==='deny' ? "Bölümde var ama Kişiler'den çıkarıldı" : sc.c==='admin' ? "Admin tüm yetkilere sahip" : "Yetki yok";
          return `<span class="yd-cap yd-src-${sc.c}" title="${esc(title)}">${esc(t[1])}<i>${esc(sc.t)}</i></span>`; }).join("");
        return `<div class="yd-grp"><div class="yd-grp-h">${esc(g[0])}</div><div class="yd-caps">${caps}</div></div>`;
      }).join("");
      mainEl.innerHTML = `
        <div class="yd-head"><div class="tk-av big">${esc(nm.trim().slice(0,2).toUpperCase())}</div><div class="tk-hinfo"><b>${esc(nm)}</b><small>${esc(u.email||'')}</small></div><span class="yd-role">${esc(role)}</span></div>
        ${isAdmin?`<div class="yd-warn">👑 Bu kişi <b>admin</b> — bölüm/kişisel ayarına bakılmaz, tüm yetkilere sahiptir. Kısıtlamak için rolü rep/müdür yapılmalı.</div>`:''}
        <div class="yd-meta"><span class="yd-mk">Veri kapsamı</span><span class="yd-mv">${esc(scopeLbl)}</span><span class="yd-mk">Bölümler</span><span class="yd-mv">${bolChips}</span><span class="yd-mk">Kişisel</span><span class="yd-mv">+${(d.personal_grant||[]).length} ekleme · −${(d.personal_deny||[]).length} çıkarma</span></div>
        <div class="yd-legend"><span class="yd-cap yd-src-dept">bölüm</span><span class="yd-cap yd-src-grant">kişisel +</span><span class="yd-cap yd-src-both">bölüm+kişisel</span><span class="yd-cap yd-src-deny">kişisel ✗</span><span class="yd-cap yd-src-none">yok</span></div>
        <div class="yd-groups">${grpHtml}</div>`;
    }
    drawList(); drawMain();
  }

'''
s = s.replace(FN_ANCH, FN + FN_ANCH, 1)

# 4) CSS -> taStyles() .tr-wrap'ten sonra
CSS_ANCH = '     .tr-wrap{display:flex;flex-direction:column;gap:16px}'
assert s.count(CSS_ANCH) == 1, "tr-wrap css anchor=%d" % s.count(CSS_ANCH)
CSS = CSS_ANCH + '''
     /* YETKI_FAZ5 — yetki denetci */
     .yd-head{display:flex;align-items:center;gap:12px;padding-bottom:12px;border-bottom:1px solid #e6e8ee}
     .yd-role{margin-left:auto;font-size:11px;font-weight:800;background:#eef2ff;color:#3730a3;padding:3px 10px;border-radius:999px;text-transform:uppercase;letter-spacing:.04em}
     .yd-warn{margin:12px 0;padding:10px 12px;background:#fffbeb;border:1px solid #fde68a;border-radius:10px;color:#92400e;font-size:13px}
     .yd-meta{display:grid;grid-template-columns:auto 1fr;gap:6px 12px;margin:14px 0;font-size:13px;align-items:center}
     .yd-mk{color:#6b7280;font-weight:700}
     .yd-mv{color:#111827}
     .yd-bchip{display:inline-block;background:#f1f5f9;border-radius:8px;padding:2px 8px;margin:0 4px 4px 0;font-size:12px}
     .yd-muted{color:#94a3b8}
     .yd-legend{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0 16px}
     .yd-groups{display:flex;flex-direction:column;gap:14px}
     .yd-grp-h{font-size:11px;font-weight:800;color:#374151;text-transform:uppercase;letter-spacing:.04em;margin-bottom:6px}
     .yd-caps{display:flex;flex-wrap:wrap;gap:6px}
     .yd-cap{display:inline-flex;align-items:center;gap:6px;font-size:12px;padding:4px 9px;border-radius:8px;border:1px solid transparent}
     .yd-cap i{font-style:normal;font-size:10px;opacity:.75}
     .yd-src-dept{background:#eff6ff;color:#1d4ed8;border-color:#bfdbfe}
     .yd-src-grant{background:#fffbeb;color:#b45309;border-color:#fde68a}
     .yd-src-both{background:#f5f3ff;color:#6d28d9;border-color:#ddd6fe}
     .yd-src-deny{background:#fef2f2;color:#b91c1c;border-color:#fecaca;text-decoration:line-through}
     .yd-src-admin{background:#ecfdf5;color:#047857;border-color:#a7f3d0}
     .yd-src-eff{background:#f0fdf4;color:#15803d;border-color:#bbf7d0}
     .yd-src-none{background:#f8fafc;color:#94a3b8;border-color:#eef2f6}'''
s = s.replace(CSS_ANCH, CSS, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ5 (tenant-admin.js) — Denetim > Yetki Denetimi gorunumu + yd-* stiller")
