# -*- coding: utf-8 -*-
# YETKI_FAZ2B (tenant-admin.js) — Yönetim'e "Bölümler" sekmesi: bölüm listesi + şablon editörü
#   (yetenek toggle'ları MODULES.saha.groups'tan) + veri kapsamı seçici (saklanır, Faz3 zorlar) +
#   üye yönet + "Kaydet & N üyeye uygula" (PATCH template → POST apply). Stiller taStyles()'a (gömme yok).
#   + Faz1 DEFAULTS heal (paralel oturum clobber'ı geri koy: rep+manager'a musterikart).
#   Taze CANLI tenant-admin.js üstüne. Açık tema (ta- paleti).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ2B" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# 0) Faz1 DEFAULTS heal — rep+manager'a musterikart (clobber sonrası idempotent geri koy)
if '"musteriler", "musterikart"' not in s:
    n = s.count('"plan", "musteriler", "teklif"')
    assert n == 2, "DEFAULTS heal anchor=%d" % n
    s = s.replace('"plan", "musteriler", "teklif"', '"plan", "musteriler", "musterikart", "teklif"')

def rep(old, new, why):
    global s
    n = s.count(old); assert n == 1, "anchor '%s' count=%d" % (why, n)
    s = s.replace(old, new, 1)

# 1) nav butonu (İzinler'den sonra)
NAV_OLD = '''        ${navBtn("permissions", "İzinler", '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/>')}'''
rep(NAV_OLD, NAV_OLD + '\n        ${navBtn("bolumler", "Bölümler", \'<path d="M12 2L2 7l10 5 10-5-10-5z"/><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/>\')}  <!-- YETKI_FAZ2B -->', "nav")

# 2) renderView map
MAP_OLD = 'permissions: ["İzinler", "Modül ve alt-araç erişim matrisi", renderPermissions],'
rep(MAP_OLD, MAP_OLD + '\n      bolumler: ["Bölümler", "Org bölümleri — yetki şablonu + toplu uygula", renderBolumler],  /* YETKI_FAZ2B */', "map")

# 3) renderBolumler fonksiyonu (renderMusteriAtama'dan önce)
FN_ANCHOR = "  async function renderMusteriAtama(content, actions) {"
assert s.count(FN_ANCHOR) == 1, "renderMusteriAtama anchor=%d" % s.count(FN_ANCHOR)
FN = r'''  // ── YETKI_FAZ2B — Bölümler (org bölüm/üyelik + şablon + toplu uygula) ──
  async function renderBolumler(content) {
    const { departments } = await apiFetch("/api/tenant/departments");
    const groups = (MODULES.saha && MODULES.saha.groups) || [];
    const SCOPES = [["kendi","Kendi","Yalnız kendine atanmış"],["bolge","Bölge","Atanmış il/bölge"],["bolum","Bölüm","Bölümüne ait"],["tumu","Tümü","Tüm tenant verisi"]];
    let sel = departments[0] ? departments[0].id : null;
    content.innerHTML = `<div class="tb-wrap"><div class="tb-side"><div class="tb-side-h"><span>Bölümler</span><button class="ta-btn ta-btn-xs" id="tb-new">＋ Yeni</button></div><div class="tb-list" id="tb-list"></div></div><div class="tb-main" id="tb-main"></div></div>`;
    const listEl = content.querySelector("#tb-list");
    const capCount = (d) => (d.template_json && Array.isArray(d.template_json.capabilities)) ? d.template_json.capabilities.length : 0;
    const scLevel = (d) => (d.template_json && d.template_json.scope && d.template_json.scope.level) || "kendi";
    const drawList = () => {
      listEl.innerHTML = departments.map(d => `<div class="tb-drow${d.id===sel?' on':''}" data-id="${d.id}"><span class="tb-dico">${esc(d.ikon||'🏷️')}</span><span class="tb-dinfo"><b>${esc(d.ad)}</b><small>${capCount(d)} yetenek · kapsam ${esc(scLevel(d))}</small></span><span class="tb-dcount">${d.uye||0}</span></div>`).join("") || `<div class="ta-empty">Bölüm yok — ＋ Yeni ile oluştur.</div>`;
      listEl.querySelectorAll("[data-id]").forEach(r=>r.addEventListener("click",()=>{ sel=r.dataset.id; drawList(); drawMain(); }));
    };
    const mainEl = content.querySelector("#tb-main");
    async function drawMain() {
      const d = departments.find(x=>x.id===sel);
      if (!d) { mainEl.innerHTML = `<div class="ta-empty">Soldan bölüm seç.</div>`; return; }
      const tpl = d.template_json || {capabilities:[],scope:{level:'kendi'}};
      const caps = new Set(Array.isArray(tpl.capabilities)?tpl.capabilities:[]);
      let curScope = (tpl.scope&&tpl.scope.level)||'kendi';
      const grpHtml = groups.map(g=>`<div class="tb-grp"><div class="tb-grp-h">${esc(g[0])}</div><div class="tb-grid">${g[1].map(t=>`<label class="tb-tog${caps.has(t[0])?' on':''}"><input type="checkbox" data-cap="${t[0]}"${caps.has(t[0])?' checked':''}><span>${esc(t[1])}</span></label>`).join("")}</div></div>`).join("");
      mainEl.innerHTML = `<div class="tb-head"><span class="tb-dico big">${esc(d.ikon||'🏷️')}</span><input class="tb-ad" id="tb-ad" value="${esc(d.ad)}"><span class="tb-uye" id="tb-uyec">${d.uye||0} üye</span><button class="ta-btn ta-btn-ghost ta-btn-xs" id="tb-members">Üyeler</button><button class="ta-btn ta-btn-ghost ta-btn-xs" id="tb-del">Sil</button></div>
        <div class="tb-scope"><span class="tb-lbl">🎯 Veri kapsamı</span><div class="tb-scopes">${SCOPES.map(sc=>`<button class="tb-scp${curScope===sc[0]?' on':''}" data-scope="${sc[0]}"><b>${sc[1]}</b><small>${sc[2]}</small></button>`).join("")}</div><small class="tb-note">Kapsam saklanır; satır-seviyesi zorlama Faz 3'te bağlanacak.</small></div>
        <div class="tb-lbl" style="margin:14px 0 6px">🧩 Yetenekler</div><div class="tb-caps">${grpHtml}</div>
        <div id="tb-memberbox"></div>
        <div class="tb-foot"><button class="ta-btn ta-btn-primary" id="tb-apply">Kaydet & ${d.uye||0} üyeye uygula</button><span class="tb-msg" id="tb-msg"></span></div>`;
      mainEl.querySelectorAll(".tb-tog input").forEach(cb=>cb.addEventListener("change",()=>cb.closest(".tb-tog").classList.toggle("on",cb.checked)));
      mainEl.querySelectorAll(".tb-scp").forEach(b=>b.addEventListener("click",()=>{ curScope=b.dataset.scope; mainEl.querySelectorAll(".tb-scp").forEach(x=>x.classList.toggle("on",x.dataset.scope===curScope)); }));
      document.getElementById("tb-del").addEventListener("click", async ()=>{ if(!(await taConfirm(`"${esc(d.ad)}" bölümü silinsin mi? (üyelikler kalkar, kişilerin izinleri kalır)`,"Sil",true)))return; try{ await apiFetch(`/api/tenant/departments/${d.id}`,{method:"DELETE"}); const i=departments.findIndex(x=>x.id===d.id); departments.splice(i,1); sel=departments[0]?departments[0].id:null; drawList(); drawMain(); toast("Bölüm silindi","ok"); }catch(e){ toast("Hata: "+e.message,"err"); } });
      document.getElementById("tb-members").addEventListener("click", ()=>drawMembers(d));
      document.getElementById("tb-apply").addEventListener("click", async ()=>{
        const msg=document.getElementById("tb-msg"), btn=document.getElementById("tb-apply"); btn.disabled=true; msg.textContent="…"; msg.className="tb-msg";
        const newCaps=[...mainEl.querySelectorAll(".tb-tog input:checked")].map(c=>c.dataset.cap);
        const tj={capabilities:newCaps, scope:{level:curScope, regions:(tpl.scope&&tpl.scope.regions)||[], segments:(tpl.scope&&tpl.scope.segments)||[]}};
        const ad=(document.getElementById("tb-ad").value||"").trim()||d.ad;
        try{
          await apiFetch(`/api/tenant/departments/${d.id}`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({ad,template_json:tj})});
          const r=await apiFetch(`/api/tenant/departments/${d.id}/apply`,{method:"POST",headers:{"Content-Type":"application/json"},body:"{}"});
          d.ad=ad; d.template_json=tj; msg.textContent=`✓ kaydedildi · ${r.uygulandi||0} üyeye uygulandı`; msg.className="tb-msg ok"; drawList();
        }catch(e){ msg.textContent="Hata: "+e.message; msg.className="tb-msg err"; }
        btn.disabled=false;
      });
    }
    async function drawMembers(d) {
      const box=document.getElementById("tb-memberbox"); if(box.innerHTML){ box.innerHTML=""; return; }
      const { users }=await apiFetch(`/api/tenant/departments/${d.id}/members`);
      box.innerHTML=`<div class="tb-members"><div class="tb-lbl">👥 Üyeler — işaretle, kaydet</div><div class="tb-mgrid">${users.map(u=>`<label class="tb-mrow"><input type="checkbox" data-uid="${u.id}"${u.uye?' checked':''}><span>${esc(u.ad)}</span></label>`).join("")}</div><div class="tb-foot2"><button class="ta-btn ta-btn-xs" id="tb-msave">Üyeliği kaydet</button><span class="tb-msg" id="tb-msg2"></span></div></div>`;
      const before=new Set(users.filter(u=>u.uye).map(u=>u.id));
      document.getElementById("tb-msave").addEventListener("click", async ()=>{
        const now=new Set([...box.querySelectorAll("input:checked")].map(c=>c.dataset.uid));
        const add=[...now].filter(x=>!before.has(x)), remove=[...before].filter(x=>!now.has(x));
        const m2=document.getElementById("tb-msg2"); m2.textContent="…"; m2.className="tb-msg";
        try{ await apiFetch(`/api/tenant/departments/${d.id}/members`,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({add,remove})}); d.uye=now.size; m2.textContent=`✓ ${now.size} üye`; m2.className="tb-msg ok"; drawList(); const uc=document.getElementById("tb-uyec"); if(uc)uc.textContent=now.size+" üye"; const ab=document.getElementById("tb-apply"); if(ab)ab.textContent=`Kaydet & ${now.size} üyeye uygula`; }catch(e){ m2.textContent="Hata: "+e.message; m2.className="tb-msg err"; }
      });
    }
    document.getElementById("tb-new").addEventListener("click", async ()=>{
      try{ const r=await apiFetch("/api/tenant/departments",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({ad:"Yeni Bölüm"})}); departments.push({id:r.id,key:r.key,ad:"Yeni Bölüm",ikon:"🏷️",template_json:{capabilities:[],scope:{level:"kendi",regions:[],segments:[]}},aktif:true,uye:0}); sel=r.id; drawList(); drawMain(); }catch(e){ toast("Hata: "+e.message,"err"); }
    });
    drawList(); drawMain();
  }

'''
s = s.replace(FN_ANCHOR, FN + FN_ANCHOR, 1)

# 4) taStyles CSS (kapanış backtick'inden önce)
CSS_ANCHOR = '''    .ta-atagec b{color:#12182a}
  `;'''
CSS = '''    .ta-atagec b{color:#12182a}
     /* YETKI_FAZ2B — Bölümler */
     .tb-wrap{display:grid;grid-template-columns:260px 1fr;gap:16px;align-items:start}
     .tb-side{background:#fff;border:1px solid #e6e9ef;border-radius:14px;overflow:hidden}
     .tb-side-h{display:flex;align-items:center;justify-content:space-between;padding:12px 14px;font-weight:700;font-size:12px;text-transform:uppercase;letter-spacing:.05em;color:#6b7280;border-bottom:1px solid #eef0f4}
     .tb-list{padding:6px}
     .tb-drow{display:flex;align-items:center;gap:10px;padding:9px 10px;border-radius:10px;cursor:pointer}
     .tb-drow.on{background:#eef4ff;border:1px solid #c7dbfe}
     .tb-drow:not(.on):hover{background:#f6f7f9}
     .tb-dico{font-size:18px;width:30px;height:30px;display:flex;align-items:center;justify-content:center;background:#f2f4f8;border-radius:8px;flex-shrink:0}
     .tb-dico.big{width:38px;height:38px;font-size:22px}
     .tb-dinfo{flex:1;min-width:0;display:flex;flex-direction:column}.tb-dinfo b{font-size:13.5px;color:#12182a}.tb-dinfo small{font-size:11px;color:#8a92a3}
     .tb-dcount{font-size:11px;font-weight:700;color:#5a6172;background:#eef0f4;border-radius:999px;padding:2px 9px}
     .tb-main{background:#fff;border:1px solid #e6e9ef;border-radius:14px;padding:16px 18px;min-height:200px}
     .tb-head{display:flex;align-items:center;gap:12px}
     .tb-ad{flex:1;font-size:16px;font-weight:700;color:#12182a;border:1px solid transparent;border-radius:8px;padding:6px 8px;background:transparent}
     .tb-ad:focus{border-color:#c7dbfe;background:#f8faff;outline:none}
     .tb-uye{font-size:12px;color:#8a92a3;font-weight:600}
     .tb-lbl{font-size:12px;font-weight:800;letter-spacing:.04em;text-transform:uppercase;color:#6b7280}
     .tb-scope{margin-top:14px;padding-top:14px;border-top:1px solid #eef0f4}
     .tb-scopes{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin:8px 0 6px}
     .tb-scp{border:1px solid #e6e9ef;border-radius:10px;padding:9px 10px;background:#fff;cursor:pointer;text-align:left}
     .tb-scp.on{border-color:#16a36a;background:#effaf3}
     .tb-scp b{display:block;font-size:12.5px;color:#12182a}.tb-scp small{font-size:10.5px;color:#8a92a3}
     .tb-note{font-size:11px;color:#8a92a3}
     .tb-caps{display:flex;flex-direction:column;gap:10px}
     .tb-grp{border:1px solid #eef0f4;border-radius:10px;padding:10px 12px;background:#fafbfc}
     .tb-grp-h{font-size:11px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:#8a92a3;margin-bottom:8px}
     .tb-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:6px}
     .tb-tog{display:flex;align-items:center;gap:8px;padding:6px 9px;border:1px solid #e6e9ef;border-radius:8px;font-size:12.5px;color:#4a5262;cursor:pointer;background:#fff}
     .tb-tog.on{border-color:#c7dbfe;background:#eef4ff;color:#12182a;font-weight:600}
     .tb-tog input{accent-color:#2f6fed}
     .tb-foot{display:flex;align-items:center;gap:12px;margin-top:16px;padding-top:14px;border-top:1px solid #eef0f4}
     .tb-foot2{display:flex;align-items:center;gap:10px;margin-top:10px}
     .tb-msg{font-size:12px;color:#8a92a3}.tb-msg.ok{color:#16a36a}.tb-msg.err{color:#d64550}
     .tb-members{margin-top:14px;padding-top:14px;border-top:1px solid #eef0f4}
     .tb-mgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:6px;margin:8px 0}
     .tb-mrow{display:flex;align-items:center;gap:8px;padding:6px 9px;border:1px solid #eef0f4;border-radius:8px;font-size:12.5px;color:#4a5262;cursor:pointer}
     .tb-mrow input{accent-color:#2f6fed}
  `;'''
rep(CSS_ANCHOR, CSS, "css")

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ2B (tenant-admin) — Bölümler sekmesi + DEFAULTS heal + stiller")
