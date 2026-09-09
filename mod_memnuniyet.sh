#!/usr/bin/env bash
set -euo pipefail
cd /opt/krb-assessment
cp server_container.mjs server_container.mjs.bak_memn
cp shells/tenant-admin.js shells/tenant-admin.js.bak_memn
trap 'echo ">> HATA — geri aliniyor"; cp server_container.mjs.bak_memn server_container.mjs; cp shells/tenant-admin.js.bak_memn shells/tenant-admin.js' ERR

python3 - <<'PY'
def patch(path, marker, edits):
    s=open(path,encoding='utf-8').read()
    if marker in s: print("SKIP (zaten var):",path); return
    for old,new,desc in edits:
        if old not in s: raise SystemExit("ANCHOR YOK (%s): %s"%(path,desc))
        s=s.replace(old,new,1)
    open(path,'w',encoding='utf-8').write(s); print("PATCHLENDI:",path)

SA='    if (method === "POST" && path === "/api/saha/rep-brain") {'
SB='''      // NABIZ_OZET_V1 — Memnuniyet izleme (manager/admin)
      if (method === "GET" && path === "/api/saha/nabiz-ozet") {
        const session = await requireSahaAccess(request, ["manager", "admin"]);
        const tid = session.tenantId;
        const F = "AND baglam::jsonb->>'deger' ~ '^[0-9]+$'";
        const ozet = await pool.query("SELECT count(*)::int adet, count(DISTINCT kullanici)::int rep, round(avg((baglam::jsonb->>'deger')::numeric),1) ort FROM bi_geri_bildirim WHERE tenant_id::text=$1::text AND hedef_tur='nabiz_capa' "+F, [tid]);
        const hafta = await pool.query("SELECT count(DISTINCT kullanici)::int rep, round(avg((baglam::jsonb->>'deger')::numeric),1) ort FROM bi_geri_bildirim WHERE tenant_id::text=$1::text AND hedef_tur='nabiz_capa' AND zaman > date_trunc('week', now()) "+F, [tid]);
        const dagilim = await pool.query("SELECT (baglam::jsonb->>'deger')::int deger, count(*)::int adet FROM bi_geri_bildirim WHERE tenant_id::text=$1::text AND hedef_tur='nabiz_capa' "+F+" GROUP BY 1 ORDER BY 1", [tid]);
        const repler = await pool.query("SELECT DISTINCT ON (g.kullanici) COALESCE(NULLIF(u.name,''),u.full_name) ad, (g.baglam::jsonb->>'deger') deger, g.zaman FROM bi_geri_bildirim g LEFT JOIN users u ON u.id::text=g.kullanici::text WHERE g.tenant_id::text=$1::text AND g.hedef_tur='nabiz_capa' ORDER BY g.kullanici, g.zaman DESC", [tid]);
        const mod3 = await pool.query("SELECT COALESCE(NULLIF(u.name,''),u.full_name) ad, g.tur capa, g.metin cevap, (g.baglam::jsonb->>'soru') soru, g.zaman FROM bi_geri_bildirim g LEFT JOIN users u ON u.id::text=g.kullanici::text WHERE g.tenant_id::text=$1::text AND g.hedef_tur='nabiz_mod3' ORDER BY g.zaman DESC LIMIT 30", [tid]);
        const trend = await pool.query("SELECT zaman::date gun, count(*)::int adet, round(avg((baglam::jsonb->>'deger')::numeric),1) ort FROM bi_geri_bildirim WHERE tenant_id::text=$1::text AND hedef_tur='nabiz_capa' AND zaman > now()-interval '14 days' "+F+" GROUP BY 1 ORDER BY 1", [tid]);
        if (!response.headersSent) sendJson(response, 200, { ozet: ozet.rows[0], hafta: hafta.rows[0], dagilim: dagilim.rows, repler: repler.rows, mod3: mod3.rows, trend: trend.rows });
        return;
      }
'''
patch('server_container.mjs','NABIZ_OZET_V1',[(SA, SB+SA, 'rep-brain POST anchor')])

NAV_OLD = """${navBtn("sistem", "Sistem", '<path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>')}"""
NAV_NEW = NAV_OLD + '\n        ' + """${navBtn("memnuniyet", "Memnuniyet", '<path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>')}"""
MAP_OLD = '      sistem: ["Sistem", "Saha hata & sistem raporu", renderSistem]'
MAP_NEW = '      sistem: ["Sistem", "Saha hata & sistem raporu", renderSistem],\n      memnuniyet: ["Memnuniyet", "Saha memnuniyet nabzi", renderMemnuniyet]'
FN_ANCHOR='  async function renderAktivite(content) {'
FN='''  // Denetim: Memnuniyet (saha nabiz) — MEMNUNIYET_PANEL_V1
  async function renderMemnuniyet(content) {
    let d;
    try { d = await apiFetch("/api/saha/nabiz-ozet"); }
    catch (e) { content.innerHTML = `<div class="ta-empty">Memnuniyet verisi yuklenemedi: ${esc(e.message)}</div>`; return; }
    const oz = d.ozet || {}, hf = d.hafta || {}, dag = d.dagilim || [];
    const mx = Math.max(1, ...dag.map(x => x.adet));
    const rk = (v) => v >= 9 ? "#067647" : v >= 7 ? "#f59e0b" : "#b42318";
    const bar = (x) => `<div style="display:flex;align-items:center;gap:8px;margin:3px 0"><span style="width:20px;text-align:right;font-weight:700;color:${rk(x.deger)}">${x.deger}</span><div style="flex:1;background:#f2f4f7;border-radius:5px;height:16px"><div style="width:${Math.round(x.adet/mx*100)}%;background:${rk(x.deger)};height:16px;border-radius:5px"></div></div><span class="ta-muted" style="width:24px">${x.adet}</span></div>`;
    const dt = (z) => z ? new Date(z).toLocaleString("tr-TR", { day:"2-digit", month:"2-digit", hour:"2-digit", minute:"2-digit" }) : "—";
    const repRow = (r) => `<tr><td><b>${esc(r.ad||"—")}</b></td><td style="text-align:center;font-weight:700;color:${rk(+r.deger)}">${r.deger==null?"—":r.deger}</td><td class="ta-muted" style="white-space:nowrap">${dt(r.zaman)}</td></tr>`;
    const m3 = (m) => `<div style="padding:8px 0;border-bottom:1px solid #f2f4f7;font-size:12.5px"><div style="display:flex;justify-content:space-between;margin-bottom:2px"><b>${esc(m.ad||"—")}</b><span class="ta-muted">${dt(m.zaman)}</span></div>${m.soru?`<div class="ta-muted" style="margin-bottom:2px">${esc(m.soru)}</div>`:""}<div style="color:#1a2233">${esc(m.cevap||m.capa||"—")}</div></div>`;
    content.innerHTML = `
      <div class="ta-izin-head"><div class="ta-izin-hint">Genel: <b>${oz.rep||0}</b> temsilci · <b>${oz.adet||0}</b> cevap · ort deger <b>${oz.ort==null?"—":oz.ort}</b>/10 · bu hafta ${hf.rep||0} temsilci (ort ${hf.ort==null?"—":hf.ort})</div></div>
      <div class="ta-grid">
        <div class="ta-card"><h3 class="ta-h3">Deger capasi dagilimi (0-10)</h3>${dag.length?dag.map(bar).join(""):`<div class="ta-empty-sm">Henuz cevap yok</div>`}</div>
        <div class="ta-card"><h3 class="ta-h3">Temsilci basina son cevap</h3>${(d.repler&&d.repler.length)?`<div class="ta-tablewrap"><table class="ta-table ta-compact"><thead><tr><th>Temsilci</th><th style="text-align:center">Deger</th><th>Zaman</th></tr></thead><tbody>${d.repler.map(repRow).join("")}</tbody></table></div>`:`<div class="ta-empty-sm">Kayit yok</div>`}</div>
      </div>
      <div class="ta-card" style="margin-top:16px"><h3 class="ta-h3">Asistan soru cevaplari (Mod-3) · ${(d.mod3||[]).length}</h3>${(d.mod3&&d.mod3.length)?d.mod3.map(m3).join(""):`<div class="ta-empty-sm">Henuz asistan cevabi yok</div>`}</div>`;
  }

'''
patch('shells/tenant-admin.js','MEMNUNIYET_PANEL_V1',[
  (NAV_OLD, NAV_NEW, 'Denetim nav sistem navBtn'),
  (MAP_OLD, MAP_NEW, 'renderView dispatch sistem'),
  (FN_ANCHOR, FN + FN_ANCHOR, 'renderAktivite anchor'),
])
PY

echo ">> node --check"
node --check server_container.mjs
node --check shells/tenant-admin.js
echo ">> build + recreate"
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4
echo -n ">> server NABIZ_OZET_V1: "; docker exec krb-assessment grep -c NABIZ_OZET_V1 /app/server.mjs || true
echo -n ">> client MEMNUNIYET_PANEL_V1: "; docker exec krb-assessment grep -c MEMNUNIYET_PANEL_V1 /app/shells/tenant-admin.js || true
echo -n ">> route benzersiz: "; docker exec krb-assessment grep -c "/api/saha/nabiz-ozet" /app/server.mjs || true
trap - ERR
echo ">> BITTI"
