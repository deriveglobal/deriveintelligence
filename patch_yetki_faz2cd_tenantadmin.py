# -*- coding: utf-8 -*-
# YETKI_FAZ2CD (tenant-admin.js) — Kişiler editörü (2c) + Roller referansı (2d) + tümünü-seç.
#   Kişiler: kişi ara → seç → modül sekmesi + rol şablonu baz + katlanır gruplar (toggle) + şablon/özel
#     etiketi + grup master + tümünü seç/temizle → Kaydet (saveRow ile aynı PATCH /api/tenant/users/:id/modules).
#   Roller: her rolün varsayılan yetenek seti (salt-okunur referans). Eski "İzinler" ızgarası KALIR (bir arada).
#   Stiller taStyles() tk-*/tr-* (gömme yok). Açık tema. Taze 2b'li CANLI üstüne.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ2CD" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

def rep(old, new, why):
    global s
    n = s.count(old); assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# 1) nav (Bölümler'den sonra Kişiler + Roller)
NAV_OLD = '''        ${navBtn("bolumler", "Bölümler", '<path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>')}  <!-- YETKI_FAZ2B -->'''
NAV_NEW = NAV_OLD + '''
        ${navBtn("kisiler", "Kişiler", '<path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/>')}  <!-- YETKI_FAZ2CD -->
        ${navBtn("roller", "Roller", '<path d="M12 2l3 7h7l-5.5 4 2 7L12 16l-6.5 4 2-7L2 9h7z"/>')}  <!-- YETKI_FAZ2CD -->'''
rep(NAV_OLD, NAV_NEW, "nav")

# 2) renderView map
MAP_OLD = 'bolumler: ["Bölümler", "Org bölümleri — yetki şablonu + toplu uygula", renderBolumler],  /* YETKI_FAZ2B */'
MAP_NEW = MAP_OLD + '''
      kisiler: ["Kişiler", "Kişi bazlı yetki editörü (rol/bölüm baz + özel)", renderKisiler],  /* YETKI_FAZ2CD */
      roller: ["Roller", "Rol şablonları — varsayılan yetenek setleri", renderRoller],  /* YETKI_FAZ2CD */'''
rep(MAP_OLD, MAP_NEW, "map")

# 3) fonksiyonlar (renderMusteriAtama'dan önce)
FN_ANCHOR = "  async function renderMusteriAtama(content, actions) {"
assert s.count(FN_ANCHOR) == 1
FN = r'''  // ── YETKI_FAZ2CD — Kişiler editörü + Roller referansı ──
  async function renderKisiler(content) {
    usersData = await apiFetch("/api/tenant/users");
    const mods = subModules(); if (!mods.length) { content.innerHTML = `<div class="ta-empty">Aktif modül aboneliği yok.</div>`; return; }
    let kMod = mods[0], sel = usersData[0] ? usersData[0].id : null, q = "";
    const mine = myId();
    const isGuard = (u) => u.tenant_role === "tenant_admin" || u.tenant_role === "platform_owner" || u.id === mine;
    content.innerHTML = `<div class="tk-wrap"><div class="tk-side"><div class="tk-search"><input id="tk-q" placeholder="Kişi ara — ad, e-posta"></div><div class="tk-list" id="tk-list"></div></div><div class="tk-main" id="tk-main"></div></div>`;
    const listEl = content.querySelector("#tk-list"), mainEl = content.querySelector("#tk-main");
    const drawList = () => {
      const f = usersData.filter(u => !q || (`${u.full_name||''} ${u.email||''}`.toLowerCase().includes(q)));
      listEl.innerHTML = f.map(u => { const nm=u.full_name||u.email||'—'; const m=(u.module_access||[]).find(x=>x&&x.module_id===kMod); const rl=(m&&m.module_role)||'—'; return `<div class="tk-urow${u.id===sel?' on':''}" data-id="${u.id}"><div class="tk-av">${esc(nm.trim().slice(0,2).toUpperCase())}</div><div class="tk-uinfo"><b>${esc(nm)}${isGuard(u)?' 👑':''}</b><small>${esc(u.email||'')}</small></div><span class="tk-ubadge">${esc(rl)}</span></div>`; }).join("") || `<div class="ta-empty">Kişi yok.</div>`;
      listEl.querySelectorAll("[data-id]").forEach(r=>r.addEventListener("click",()=>{ sel=r.dataset.id; drawList(); drawMain(); }));
    };
    document.getElementById("tk-q").addEventListener("input", e=>{ q=e.target.value.toLowerCase(); drawList(); });
    function drawMain() {
      const u = usersData.find(x=>x.id===sel); if (!u) { mainEl.innerHTML = `<div class="ta-empty">Soldan kişi seç.</div>`; return; }
      const guard = isGuard(u), cfg = MODULES[kMod];
      const m = (u.module_access||[]).find(x=>x&&x.module_id===kMod), perms=(m&&m.permissions)||{};
      const has = new Set(Array.isArray(perms.departments)?perms.departments:[]);
      let role = (m&&m.module_role)||cfg.roles[0][0];
      const nm = u.full_name||u.email||'—';
      const modTabs = mods.map(id=>`<button class="tk-modtab${id===kMod?' on':''}" data-mod="${id}">${esc(moduleLabel(id))}</button>`).join("");
      const roleOpts = cfg.roles.map(r=>`<option value="${r[0]}"${(role===r[0]||(guard&&r[0]===cfg.gmRole))?' selected':''}>${esc(r[1])}</option>`).join("");
      const roleDef = new Set((DEFAULTS[kMod]&&DEFAULTS[kMod][role])||[]);
      const grpHtml = cfg.groups.map(g=>{ const items=g[1]; const on=items.filter(t=>has.has(t[0])||guard).length;
        return `<div class="tk-grp"><div class="tk-grp-h"><span class="tk-gn">${esc(g[0])}</span><span class="tk-gc">${on}/${items.length}</span><label class="tk-master"><input type="checkbox" data-gmaster="${esc(g[0])}"${on===items.length?' checked':''}${guard?' disabled':''}> tümü</label></div><div class="tk-grid">${items.map(t=>{ const lock=guard&&cfg.lock.includes(t[0]); const chk=has.has(t[0])||guard||lock; const tag=(chk&&!guard)?(roleDef.has(t[0])?'<span class="tk-tag def">şablon</span>':'<span class="tk-tag ovr">özel</span>'):''; return `<label class="tk-tog${chk?' on':''}" data-grp="${esc(g[0])}"><input type="checkbox" class="tk-cap" data-cap="${t[0]}"${chk?' checked':''}${(guard||lock)?' disabled':''}><span>${esc(t[1])}${tag}</span></label>`; }).join("")}</div></div>`; }).join("");
      mainEl.innerHTML = `<div class="tk-head"><div class="tk-av big">${esc(nm.trim().slice(0,2).toUpperCase())}</div><div class="tk-hinfo"><b>${esc(nm)}${guard?' 👑':''}</b><small>${esc(u.email||'')}</small></div><div class="tk-modtabs">${modTabs}</div></div>
        <div class="tk-rolebar"><label class="tk-lbl2">Rol şablonu</label><select class="tk-role" id="tk-role"${guard?' disabled':''}>${roleOpts}</select>${cfg.segment?`<label class="tk-lbl2" style="margin-left:12px">Segment</label><select class="tk-seg" id="tk-seg"><option value=""${!perms.saha_tip?' selected':''}>Oto</option><option value="TUKETICI"${perms.saha_tip==='TUKETICI'?' selected':''}>Tüketici</option><option value="TICARI"${perms.saha_tip==='TICARI'?' selected':''}>Ticari</option><option value="KARMA"${perms.saha_tip==='KARMA'?' selected':''}>Karma</option></select>`:''}<span class="tk-rhint">${guard?'👑 yönetici — kilitli':'Rol seçince şablon dolar; tek tek özelleştir'}</span></div>
        <div class="tk-actionsbar"><button class="ta-btn ta-btn-xs ta-btn-ghost" id="tk-all"${guard?' disabled':''}>Tümünü seç</button><button class="ta-btn ta-btn-xs ta-btn-ghost" id="tk-none"${guard?' disabled':''}>Tümünü temizle</button></div>
        <div class="tk-caps">${grpHtml}</div>
        <div class="tk-foot"><button class="ta-btn ta-btn-primary" id="tk-save"${guard?' disabled':''}>Kaydet</button><span class="tk-msg" id="tk-msg"></span></div>`;
      mainEl.querySelectorAll(".tk-modtab").forEach(b=>b.addEventListener("click",()=>{ kMod=b.dataset.mod; drawList(); drawMain(); }));
      if (guard) return;
      const recount=()=>{ mainEl.querySelectorAll(".tk-grp").forEach(gp=>{ const cbs=[...gp.querySelectorAll(".tk-cap")]; const on=cbs.filter(c=>c.checked).length; gp.querySelector(".tk-gc").textContent=on+"/"+cbs.length; const gm=gp.querySelector("[data-gmaster]"); if(gm)gm.checked=on===cbs.length; cbs.forEach(c=>c.closest(".tk-tog").classList.toggle("on",c.checked)); }); };
      mainEl.querySelectorAll(".tk-cap").forEach(cb=>cb.addEventListener("change",recount));
      mainEl.querySelectorAll("[data-gmaster]").forEach(gm=>gm.addEventListener("change",()=>{ const g=gm.dataset.gmaster; mainEl.querySelectorAll('.tk-tog[data-grp="'+g+'"] .tk-cap').forEach(c=>{ if(!c.disabled)c.checked=gm.checked; }); recount(); }));
      document.getElementById("tk-all").addEventListener("click",()=>{ mainEl.querySelectorAll(".tk-cap").forEach(c=>{ if(!c.disabled)c.checked=true; }); recount(); });
      document.getElementById("tk-none").addEventListener("click",()=>{ mainEl.querySelectorAll(".tk-cap").forEach(c=>{ if(!c.disabled)c.checked=false; }); recount(); });
      document.getElementById("tk-role").addEventListener("change", e=>{ const def=new Set((DEFAULTS[kMod]&&DEFAULTS[kMod][e.target.value])||[]); mainEl.querySelectorAll(".tk-cap").forEach(c=>{ if(!c.disabled)c.checked=def.has(c.dataset.cap); }); recount(); });
      document.getElementById("tk-save").addEventListener("click", async ()=>{
        const msg=document.getElementById("tk-msg"), btn=document.getElementById("tk-save"); btn.disabled=true; msg.textContent="…"; msg.className="tk-msg";
        const checked=[...mainEl.querySelectorAll(".tk-cap:checked")].map(c=>c.dataset.cap);
        const known=new Set(modTools(kMod)); const preserved=(Array.isArray(perms.departments)?perms.departments:[]).filter(d=>!known.has(d));
        const departments=[...new Set([...preserved,...checked])]; const np={...perms,departments};
        const segEl=document.getElementById("tk-seg"); if(cfg.segment){ const sv=segEl?segEl.value:''; if(sv)np.saha_tip=sv; else delete np.saha_tip; }
        const role2=document.getElementById("tk-role").value||cfg.roles[0][0];
        try{
          await apiFetch(`/api/tenant/users/${u.id}/modules`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({module_id:kMod,module_role:role2,permissions_json:np,active:(m?m.active!==false:true)})});
          let e=(u.module_access||[]).find(x=>x&&x.module_id===kMod); if(!e){ e={module_id:kMod}; (u.module_access=u.module_access||[]).push(e); } e.module_role=role2; e.permissions=np;
          msg.textContent="✓ kaydedildi"; msg.className="tk-msg ok"; drawList();
          toast(`${nm} · ${moduleLabel(kMod)} izinleri güncellendi`,"ok");
        }catch(err){ msg.textContent="Hata: "+err.message; msg.className="tk-msg err"; }
        btn.disabled=false;
      });
    }
    drawList(); drawMain();
  }

  async function renderRoller(content) {
    const mods = subModules(); if (!mods.length) { content.innerHTML = `<div class="ta-empty">Aktif modül aboneliği yok.</div>`; return; }
    content.innerHTML = `<div class="tr-wrap">${mods.map(mod=>{ const cfg=MODULES[mod]; const tools=modTools(mod); return `<div class="tr-mod"><div class="tr-modh">${esc(moduleLabel(mod))}</div>${cfg.roles.map(r=>{ const def=new Set((DEFAULTS[mod]&&DEFAULTS[mod][r[0]])||[]); return `<div class="tr-role"><div class="tr-rname">${esc(r[1])}<small>${def.size>=tools.length?'tüm araçlar':def.size+' araç'}</small></div><div class="tr-caps">${cfg.groups.flatMap(g=>g[1]).map(t=>`<span class="tr-cap${def.has(t[0])?' on':''}">${esc(t[1])}</span>`).join("")}</div></div>`; }).join("")}</div>`; }).join("")}</div><div class="ta-izin-hint" style="margin-top:14px">Roller = rol seçince gelen <b>varsayılan set</b> (Kişiler'de tek tek özelleştirilebilir). Şu an kod düzeyinde tanımlı; düzenlenebilir rol şablonları ileride.</div>`;
  }

'''
s = s.replace(FN_ANCHOR, FN + FN_ANCHOR, 1)

# 4) CSS (2b bloğundan sonra, kapanış backtick'inden önce)
CSS_ANCHOR = '''     .tb-mrow input{accent-color:#2f6fed}
  `;'''
CSS = '''     .tb-mrow input{accent-color:#2f6fed}
     /* YETKI_FAZ2CD — Kişiler + Roller */
     .tk-wrap{display:grid;grid-template-columns:280px 1fr;gap:16px;align-items:start}
     .tk-side{background:#fff;border:1px solid #e6e9ef;border-radius:14px;overflow:hidden}
     .tk-search{padding:10px}.tk-search input{width:100%;border:1px solid #dfe3ea;border-radius:9px;padding:9px 11px;font-size:13px}
     .tk-list{padding:4px 8px 8px;max-height:70vh;overflow:auto}
     .tk-urow{display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:10px;cursor:pointer}
     .tk-urow.on{background:#eef4ff;border:1px solid #c7dbfe}.tk-urow:not(.on):hover{background:#f6f7f9}
     .tk-av{width:32px;height:32px;border-radius:9px;background:linear-gradient(135deg,#2f6fed,#5b8def);color:#fff;font-weight:700;font-size:12px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
     .tk-av.big{width:40px;height:40px;font-size:14px}
     .tk-uinfo{flex:1;min-width:0;display:flex;flex-direction:column}.tk-uinfo b{font-size:13px;color:#12182a}.tk-uinfo small{font-size:11px;color:#8a92a3;text-overflow:ellipsis;overflow:hidden;white-space:nowrap}
     .tk-ubadge{font-size:10.5px;font-weight:700;color:#5a6172;background:#eef0f4;border-radius:999px;padding:2px 8px}
     .tk-main{background:#fff;border:1px solid #e6e9ef;border-radius:14px;padding:16px 18px;min-height:220px}
     .tk-head{display:flex;align-items:center;gap:12px;border-bottom:1px solid #eef0f4;padding-bottom:12px}
     .tk-hinfo{flex:1;display:flex;flex-direction:column}.tk-hinfo b{font-size:15px;color:#12182a}.tk-hinfo small{font-size:12px;color:#8a92a3}
     .tk-modtabs{display:flex;gap:2px;background:#f2f4f8;border-radius:9px;padding:3px}
     .tk-modtab{border:0;background:transparent;color:#6b7280;font-weight:700;font-size:12px;padding:6px 12px;border-radius:7px;cursor:pointer}.tk-modtab.on{background:#fff;color:#12182a;box-shadow:0 1px 3px rgba(0,0,0,.08)}
     .tk-rolebar{display:flex;align-items:center;gap:8px;margin-top:12px;flex-wrap:wrap}
     .tk-lbl2{font-size:12px;color:#6b7280;font-weight:600}
     .tk-role,.tk-seg{border:1px solid #d7dbe4;border-radius:8px;padding:6px 10px;font-size:13px;font-weight:600;color:#12182a;background:#fff}
     .tk-rhint{font-size:11.5px;color:#8a92a3;margin-left:auto}
     .tk-actionsbar{display:flex;gap:8px;margin:12px 0 6px}
     .tk-caps{display:flex;flex-direction:column;gap:10px}
     .tk-grp{border:1px solid #eef0f4;border-radius:10px;padding:10px 12px;background:#fafbfc}
     .tk-grp-h{display:flex;align-items:center;gap:10px;margin-bottom:8px}
     .tk-gn{font-size:11px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:#8a92a3}
     .tk-gc{font-size:11px;color:#8a92a3}.tk-master{margin-left:auto;font-size:11px;color:#8a92a3;display:flex;align-items:center;gap:5px;cursor:pointer}
     .tk-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:6px}
     .tk-tog{display:flex;align-items:center;gap:8px;padding:6px 9px;border:1px solid #e6e9ef;border-radius:8px;font-size:12.5px;color:#4a5262;cursor:pointer;background:#fff}
     .tk-tog.on{border-color:#c7dbfe;background:#eef4ff;color:#12182a;font-weight:600}
     .tk-tog input{accent-color:#2f6fed}
     .tk-tag{font-size:9px;font-weight:700;padding:1px 5px;border-radius:5px;margin-left:6px}
     .tk-tag.def{background:#eef0f4;color:#8a92a3}.tk-tag.ovr{background:#fff3e0;color:#b26a00}
     .tk-foot{display:flex;align-items:center;gap:12px;margin-top:16px;padding-top:14px;border-top:1px solid #eef0f4}
     .tk-msg{font-size:12px;color:#8a92a3}.tk-msg.ok{color:#16a36a}.tk-msg.err{color:#d64550}
     .tr-wrap{display:flex;flex-direction:column;gap:16px}
     .tr-mod{background:#fff;border:1px solid #e6e9ef;border-radius:14px;padding:14px 16px}
     .tr-modh{font-size:13px;font-weight:800;color:#12182a;margin-bottom:10px}
     .tr-role{padding:10px 0;border-top:1px solid #eef0f4}
     .tr-rname{font-size:13px;font-weight:700;color:#12182a;margin-bottom:6px}.tr-rname small{font-weight:500;color:#8a92a3;margin-left:8px}
     .tr-caps{display:flex;flex-wrap:wrap;gap:5px}
     .tr-cap{font-size:11.5px;padding:3px 9px;border-radius:999px;background:#f2f4f8;color:#a7adba;border:1px solid #eef0f4}
     .tr-cap.on{background:#eef4ff;color:#2f6fed;border-color:#c7dbfe;font-weight:600}
  `;'''
rep(CSS_ANCHOR, CSS, "css")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ2CD (tenant-admin) — Kişiler + Roller + tümünü-seç")
