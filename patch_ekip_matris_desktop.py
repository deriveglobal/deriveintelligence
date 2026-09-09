# -*- coding: utf-8 -*-
# EKIP_MATRIS_V1 (masaustu) — Ekip erisim matrisi, SLICE 1 (OKUMA):
#   VIEWS.temsilciler stub'i (VIEWS._todo fallback) yerine gercek grid matris.
#   Tum kullanicilar (GET /api/tenant/users) x saha alt-araclari; her hucrede
#   erisim isareti. Rol/Segment/Aktif/Son giris sutunlari. Duzenleme S2'de.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "EKIP_MATRIS_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCHOR = "const VIEWS = {};"

VIEW = r'''

VIEWS.temsilciler = async (m) => {  /* EKIP_MATRIS_V1 — Ekip erisim matrisi (okuma; duzenleme S2) */
  const canManage = S.isOwner || S.isYonetim || (S.me && S.me.tenantRole === "tenant_admin");
  if (!canManage) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🔒</div><h3>Erişim yok</h3><p>Ekip yönetimi yalnız tenant yöneticisine açıktır.</p></div></div>`; return; }

  const CATALOG = [
    ["Saha", [["bugun","Bugün"],["ziyaretler","Ziyaretler"],["plan","Plan"],["musteriler","Müşteriler"],["musterikart","Müşteri Kartı"],["ebatkart","Ebat Kartı"],["iskonto","Teklif"],["notlarim","Notlarım"],["rep-brain","Rep-Brain"]]],
    ["Zeka & Pazar", [["harita","Harita"],["piyasa","Piyasa"],["rakip","Rakip"],["oneriler","Öneriler"]]],
    ["Yönetim & Analiz", [["rapor","Rapor"],["kokpit","Kokpit"],["ceo","CEO"],["rep-aktivite","Aktivite"]]],
    ["İletişim", [["duyurular","Duyurular"],["mesajlar","Mesajlar"]]],
    ["Sistem & Erişim", [["temsilciler","Ekip"],["sistem","Sistem"]]]
  ];
  const TOOLS = CATALOG.flatMap(g => g[1].map(t => t[0]));

  let users;
  try { users = await api("/api/tenant/users"); }
  catch (e) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">⚠</div><h3>Yüklenemedi</h3><p>${esc(e.message || e)}</p></div></div>`; return; }
  if (!Array.isArray(users)) users = [];

  const sahaOf = (u) => (u.module_access || []).find(x => x && x.module_id === "saha") || null;
  const rolPill = (r) => { const map = { admin:["Admin","p-info"], manager:["Müdür","p-viol"], rep:["Saha","p-mut"] }; const v = map[r] || ["—","p-mut"]; return `<span class="pill ${v[1]}">${esc(v[0])}</span>`; };
  const segLbl = (t) => ({ TUKETICI:"Tüketici", TICARI:"Ticari", KARMA:"Karma" }[String(t || "").toUpperCase()] || "Oto");
  const tRole = (tr) => tr === "tenant_admin" ? `<span class="pill p-ok" title="Tenant yöneticisi" style="margin-left:6px">👑</span>` : (tr === "platform_owner" ? `<span class="pill p-info" style="margin-left:6px">Platform</span>` : "");
  const dt = (ts) => ts ? new Date(ts).toLocaleDateString("tr-TR", { day:"2-digit", month:"2-digit", year:"2-digit" }) : "—";

  const STICKY = "position:sticky;left:0;z-index:1;box-shadow:1px 0 0 var(--cizgi)";
  const TH_TOOL = "padding:8px 5px;text-align:center;min-width:60px;white-space:normal;line-height:1.15";
  const grpTh = CATALOG.map(g => `<th colspan="${g[1].length}" style="text-align:center;background:var(--zemin-2)">${esc(g[0])}</th>`).join("");
  const toolTh = CATALOG.flatMap(g => g[1].map(t => `<th style="${TH_TOOL}" title="${esc(t[1])}">${esc(t[1])}</th>`)).join("");

  const row = (u) => {
    const sm = sahaOf(u);
    const perms = (sm && sm.permissions) || {};
    const has = new Set(Array.isArray(perms.departments) ? perms.departments : []);
    const active = sm ? sm.active !== false : false;
    const nm = u.full_name || u.name || u.email || "—";
    const cells = TOOLS.map(id => `<td style="text-align:center;padding:8px 5px">${has.has(id) ? `<span style="color:var(--yesil,#16a34a);font-weight:700">✓</span>` : `<span style="color:var(--tx-3)">·</span>`}</td>`).join("");
    return `<tr>
      <td style="${STICKY};background:var(--zemin-1);font-weight:600">${esc(nm)}${tRole(u.tenant_role)}<div style="font-size:11px;color:var(--tx-2);font-weight:400">${esc(u.email || "")}</div></td>
      <td>${sm ? rolPill(sm.module_role) : `<span class="pill p-mut">yok</span>`}</td>
      <td style="white-space:nowrap">${sm ? esc(segLbl(perms.saha_tip)) : "—"}</td>
      <td style="text-align:center">${active ? `<span style="color:var(--yesil,#16a34a)">●</span>` : `<span style="color:var(--tx-3)">○</span>`}</td>
      ${cells}
      <td style="white-space:nowrap;color:var(--tx-1)">${dt(u.last_login_at)}</td>
    </tr>`;
  };

  m.innerHTML = `
    <div class="dk-card" style="padding:0;overflow:hidden">
      <div class="dk-card-h" style="padding:16px 20px 10px"><h3>👥 Ekip — Erişim Matrisi</h3><span class="sub">${users.length} kullanıcı · saha modülü</span></div>
      <div style="overflow-x:auto">
        <table class="dk-t" style="min-width:100%">
          <thead>
            <tr>
              <th rowspan="2" style="${STICKY};background:var(--zemin-2)">Kullanıcı</th>
              <th rowspan="2">Rol</th>
              <th rowspan="2">Segment</th>
              <th rowspan="2" style="text-align:center">Aktif</th>
              ${grpTh}
              <th rowspan="2">Son giriş</th>
            </tr>
            <tr>${toolTh}</tr>
          </thead>
          <tbody>${users.length ? users.map(row).join("") : `<tr><td colspan="99"><div class="dk-empty-s">Kullanıcı yok</div></td></tr>`}</tbody>
        </table>
      </div>
      <div style="padding:10px 20px;color:var(--tx-2);font-size:12px;border-top:1px solid var(--cizgi)">Okuma görünümü · düzenleme sonraki adımda. <span style="color:var(--yesil,#16a34a);font-weight:700">✓</span> = erişimli alt-araç.</div>
    </div>`;
};
'''

assert s.count(ANCHOR) == 1, "anchor bulunamadi (%d): %s" % (s.count(ANCHOR), ANCHOR)
s = s.replace(ANCHOR, ANCHOR + VIEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] EKIP_MATRIS_V1 (masaustu)")
