#!/usr/bin/env bash
set -euo pipefail
cd /opt/krb-assessment
cp server_container.mjs server_container.mjs.bak_mod3
cp shells/saha.js shells/saha.js.bak_mod3
trap 'echo ">> HATA — geri aliniyor"; cp server_container.mjs.bak_mod3 server_container.mjs; cp shells/saha.js.bak_mod3 shells/saha.js' ERR
python3 - <<'PY'
def patch(path, marker, edits):
    s=open(path,encoding='utf-8').read()
    if marker in s:
        print("SKIP (zaten var):",path); return
    for old,new,desc in edits:
        if old not in s: raise SystemExit("ANCHOR YOK (%s): %s"%(path,desc))
        s=s.replace(old,new,1)
    open(path,'w',encoding='utf-8').write(s); print("PATCHLENDI:",path)

SA='    if (method === "POST" && path === "/api/saha/rep-brain") {'
SB='''      // NABIZ_SOR_V1 — Mod-3 asistan is-arkadasi sorusu (beyin secer)
      if (method === "GET" && path === "/api/saha/nabiz-sor") {
        const session = await requireSahaAccess(request);
        const t = session.tenantId, u = session.userId;
        const asked = await pool.query("SELECT count(*)::int n FROM bi_geri_bildirim WHERE tenant_id=$1 AND kullanici=$2 AND hedef_tur='nabiz_mod3' AND zaman > now()-interval '7 days'", [t,u]);
        if (asked.rows[0].n > 0) { sendJson(response,200,{sor:null}); return; }
        const rem = await pool.query("SELECT count(*) FILTER (WHERE NOT tamamlandi)::int acik, count(*) FILTER (WHERE tamamlandi AND updated_at > now()-interval '7 days')::int kapali7 FROM saha_rep_not WHERE tenant_id=$1 AND rep_id=$2", [t,u]);
        const err = await pool.query("SELECT count(*)::int n FROM saha_hata_log WHERE tenant_id=$1 AND user_id=$2 AND ts > now()-interval '7 days' AND tip='YAVAS_API'", [t,u]);
        const tek = await pool.query("SELECT count(*)::int n FROM saha_teklif WHERE tenant_id=$1 AND rep_id=$2 AND created_at > now()-interval '30 days'", [t,u]);
        let sor=null, capa=null, secenekler=null;
        if ((rem.rows[0].acik||0) >= 5 && (rem.rows[0].kapali7||0) === 0) {
          sor = "Bu arada — yeni Tamamla butonu hatirlatmalari kapatmani kolaylastirdi mi?";
          capa = "hatirlatma"; secenekler = ["Evet, artik kapatiyorum","Fark etmedim","Hala zor"];
        } else if ((err.rows[0].n||0) >= 10) {
          sor = "Bu hafta uygulama seni birkac yerde bekletti galiba — en cok nerede takildin?";
          capa = "hiz"; secenekler = ["Ziyaret listesi","Kaydederken","Fotograf","Beklemedi"];
        } else if ((tek.rows[0].n||0) === 0) {
          sor = "Teklif ekranini bu ara kullanmadin — gerek mi olmadi, yoksa bir yerde mi takildin?";
          capa = "teklif"; secenekler = ["Gerek olmadi","Takildim","Nasil oldugunu bilmiyorum"];
        } else {
          sor = "Kisa bir sey: bu hafta Derive'da en cok neyi duzeltmemizi istersin?";
          capa = "acik"; secenekler = ["Her sey yolunda","Bir sorun var"];
        }
        sendJson(response, 200, { sor, capa, secenekler });
        return;
      }
      // NABIZ_SOR_V1 — Mod-3 cevap (hedef_tur=nabiz_mod3)
      if (method === "POST" && path === "/api/saha/nabiz-sor-cevap") {
        const session = await requireSahaAccess(request);
        const body = await readJson(request);
        const capa = (body.capa || '').toString().slice(0,40);
        const cevap = (body.cevap || '').toString().slice(0,2000);
        const soru = (body.soru || '').toString().slice(0,400);
        if (!cevap) { sendJson(response,400,{error:'bos'}); return; }
        await pool.query("INSERT INTO bi_geri_bildirim (tenant_id, zaman, kullanici, hedef, hedef_tur, tur, metin, baglam, islendi) VALUES ($1, now(), $2, 'nabiz-asistan', 'nabiz_mod3', $3, $4, $5, false)",
          [session.tenantId, session.userId, (capa || 'mod3'), cevap, JSON.stringify({ mod:'mod3', kanal:'asistan', soru, capa })]);
        sendJson(response, 200, { ok:true });
        return;
      }
'''
patch('server_container.mjs','NABIZ_SOR_V1',[(SA, SB+SA, 'rep-brain POST anchor')])

CF='''async function nabizSorGoster(msgsEl){ /* NABIZ_SOR_V1 */
  let d; try{ d = await api('/api/saha/nabiz-sor'); }catch(e){ return; }
  if(!d || !d.sor || !msgsEl) return;
  const q = document.createElement('div');
  q.style.cssText = 'align-self:flex-start;max-width:85%;padding:10px 13px;border-radius:12px;font-size:13px;line-height:1.5;background:#eef2ff;color:#312e81;border:1px solid #c7d2fe;border-bottom-left-radius:3px';
  q.textContent = d.sor; msgsEl.appendChild(q);
  const wrap = document.createElement('div');
  wrap.style.cssText = 'align-self:flex-start;display:flex;flex-wrap:wrap;gap:6px';
  const secenekler = (d.secenekler && d.secenekler.length) ? d.secenekler : ['Evet','Kismen','Hayir'];
  secenekler.forEach(function(opt){
    const b=document.createElement('button'); b.textContent=opt;
    b.style.cssText='padding:6px 12px;border:1.5px solid #c7d2fe;border-radius:16px;background:#fff;font-size:12px;font-weight:600;color:#3730a3;cursor:pointer';
    b.onclick=async function(){
      wrap.remove(); rbRenderMsg(msgsEl,'user',opt);
      try{ await api('/api/saha/nabiz-sor-cevap',{method:'POST',body:JSON.stringify({capa:d.capa||'mod3',cevap:opt,soru:d.sor})}); }catch(e){}
      const t=document.createElement('div');
      t.style.cssText='align-self:flex-start;max-width:85%;padding:10px 13px;border-radius:12px;font-size:13px;line-height:1.5;background:#ecfdf5;color:#065f46;border-bottom-left-radius:3px';
      t.textContent='Tesekkurler, not aldim.'; msgsEl.appendChild(t); msgsEl.scrollTop=msgsEl.scrollHeight;
    };
    wrap.appendChild(b);
  });
  msgsEl.appendChild(wrap); msgsEl.scrollTop=msgsEl.scrollHeight;
}
'''
patch('shells/saha.js','NABIZ_SOR_V1',[
  ('function rbRenderMsg(msgsEl, role, text) {', CF+'\nfunction rbRenderMsg(msgsEl, role, text) {', 'rbRenderMsg anchor'),
  ('  m.querySelector("#rb-gonder")?.addEventListener("click", () => rbSend(msgsEl));',
   '  setTimeout(function(){ nabizSorGoster(msgsEl); }, 1200); /* NABIZ_SOR_V1 */\n  m.querySelector("#rb-gonder")?.addEventListener("click", () => rbSend(msgsEl));',
   'rb-gonder listener anchor'),
])
PY
echo ">> node --check"; node --check server_container.mjs; node --check shells/saha.js
echo ">> build + recreate"
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4
echo -n ">> server: "; docker exec krb-assessment grep -c NABIZ_SOR_V1 /app/server.mjs || true
echo -n ">> client: "; docker exec krb-assessment grep -c NABIZ_SOR_V1 /app/shells/saha.js || true
echo ">> cagri konumu:"; docker exec krb-assessment grep -n nabizSorGoster /app/shells/saha.js
trap - ERR
echo ">> BITTI"
