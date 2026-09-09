# -*- coding: utf-8 -*-
# YETKI_YARDIM_V1 (tenant-admin.js) — uygulama ici "Yardim > Yetki Rehberi" (teknik dokumantasyon). Salt-oku, statik.
#   5 ekran + cekirdek model + iki eksen + uc katman + sik isler + uc listesi + veri modeli + uyarilar. Stiller taStyles() yh-*.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "tenant-admin.js"
s = open(F, encoding="utf-8").read()
if "YETKI_YARDIM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) nav — memnuniyet'ten sonra (admin blogu icinde)
NAV = '''${navBtn("memnuniyet", "Memnuniyet", '<path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/>')}'''
assert s.count(NAV) == 1, "memnuniyet nav anchor=%d" % s.count(NAV)
NAV2 = NAV + '''
        <div class="ta-nav-label">Yardım</div>
        ${navBtn("yardim", "Yetki Rehberi", '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>')}  <!-- YETKI_YARDIM_V1 -->'''
s = s.replace(NAV, NAV2, 1)

# 2) renderView map — memnuniyet'ten sonra (virgul ekle)
MAP = '      memnuniyet: ["Memnuniyet", "Saha memnuniyet nabzi", renderMemnuniyet]'
assert s.count(MAP) == 1, "memnuniyet map anchor=%d" % s.count(MAP)
s = s.replace(MAP, MAP + ',\n      yardim: ["Yetki Rehberi", "Yetki modülü — teknik dokümantasyon", renderYardim]  /* YETKI_YARDIM_V1 */', 1)

# 3) renderYardim fonksiyonu — renderMemnuniyet'ten once
FN_ANCH = '  async function renderMemnuniyet(content) {'
assert s.count(FN_ANCH) == 1, "renderMemnuniyet anchor=%d" % s.count(FN_ANCH)
FN = '''  function renderYardim(content) {  /* YETKI_YARDIM_V1 */
    content.innerHTML = `<div class="yh">
      <div class="yh-hero"><h1>🔐 Yetki Modülü — Teknik Rehber</h1><p>KRB saha yetkileri tek bir cebirle yönetilir: <b>yetki = (bölüm şablonları ∪ kişisel-ekleme) − kişisel-çıkarma</b>. Deny-by-default: bir kişide açıkça verilmeyen kapalıdır. Admin rolü tüm kapıları bypass eder.</p></div>

      <div class="yh-sec"><h2>1 · Beş ekran, tek zincir</h2><div class="yh-cards">
        <div class="yh-card"><div class="yh-ct">📦 Bölümler</div><p><b>Grubun yasası.</b> Bölüm şablonunda ne işaretliyse üyeleri onu alır; kaldırınca üyeden düşer. "Kaydet &amp; uygula" üyeleri şablona hizalar.</p></div>
        <div class="yh-card"><div class="yh-ct">👤 Kişiler</div><p><b>Kişisel istisna.</b> Bölüm dışında ekleme (kişisel +) ya da bölümden çıkarma (kişisel −). Bu istisnalar sonraki "uygula"da <b>ezilmez</b>.</p></div>
        <div class="yh-card"><div class="yh-ct">⭐ Roller</div><p><b>Referans.</b> Rol seçilince gelen varsayılan set (rep/müdür/admin). Salt-oku; gerçek yönetim Bölümler + Kişiler.</p></div>
        <div class="yh-card"><div class="yh-ct">🛡️ Yetki Denetimi</div><p><b>Durum.</b> Kişiye bak → her yetki nereden: bölüm / kişisel-ekleme / kişisel-çıkarma / admin.</p></div>
        <div class="yh-card"><div class="yh-ct">🕘 Yetki Günlüğü</div><p><b>Tarih.</b> Kim, kime/nereye, ne zaman, ne değişikliği yaptı (kişi yetkisi / bölüm uygula / üyelik).</p></div>
      </div></div>

      <div class="yh-sec"><h2>2 · Çekirdek model</h2>
        <div class="yh-formula">yetki(kişi) = ( ⋃ üye_olduğu_bölüm_şablonları ∪ personal_grant ) − personal_deny</div>
        <ul>
          <li><b>Deny-by-default:</b> kişinin <code>departments[]</code>'ı doluysa yalnız oradakini görür; boşsa rol varsayılanına düşer.</li>
          <li><b>personal_grant / personal_deny:</b> Kişiler'deki ekleme/çıkarma burada saklanır; bölüm "uygula" bunları korur.</li>
          <li><b>Admin bypass:</b> saha rolü <code>admin</code> olan kişi departments'a bakılmadan hepsini görür. Kısıtlanacak kişi <b>rep</b> veya <b>müdür</b> olmalı.</li>
          <li><b>Çıkış-giriş:</b> yetki değişince kişi oturumunu yenilemeli (yetkiler girişte yüklenir; iOS PWA cache yapışkan → uygulamayı öldür-aç).</li>
        </ul>
      </div>

      <div class="yh-sec"><h2>3 · İki eksen</h2>
        <table class="yh-tbl"><thead><tr><th>Eksen</th><th>Ne</th><th>Değerler</th></tr></thead><tbody>
          <tr><td><b>Yetkinlik (capability)</b></td><td>Hangi araç / sekme</td><td>ozet, ciro, risk, etki, portfoy, rotam, kapsam, pipeline, pazar, müşteriler, teklif, …</td></tr>
          <tr><td><b>Veri kapsamı (scope)</b></td><td>Hangi kayıtlar</td><td><b>Kendi</b> · <b>Bölge</b> (atanmış il) · <b>Bölüm</b> (bölüm arkadaşları) · <b>Tümü</b></td></tr>
        </tbody></table>
        <p class="yh-note">Kapsam bölüm şablonunda seçilir; server liste + tekil kart + agregat raporlarda (Kapsam/Portföy/Saha ROI) zorlar. <code>tümü / ayarsız / admin</code> → filtre yok.</p>
      </div>

      <div class="yh-sec"><h2>4 · Üç katman (client == server)</h2>
        <table class="yh-tbl"><thead><tr><th>Katman</th><th>Nerede</th><th>Ne yapar</th></tr></thead><tbody>
          <tr><td>Config</td><td><code>MODULES.saha.groups</code></td><td>Hangi capability'ler var; grid'i besler</td></tr>
          <tr><td>Client kapı</td><td><code>_rTabOk</code> / <code>_dok</code> (saha.js/desktop)</td><td>Ekranda sekme/aracı gösterir-gizler (deny-by-default)</td></tr>
          <tr><td>Server enforce</td><td><code>_enforceSahaDept</code> / <code>_sahaCap</code> / <code>_sahaScopeSql</code></td><td>API'de kapatır (token bilen de giremez) + kapsam WHERE</td></tr>
        </tbody></table>
        <p class="yh-note">Client kapısı ile server zorlaması <b>birebir</b> aynı olmalı. <b>Sert</b> yetki (Saha ROI=<code>etki</code>, Portföy=<code>portfoy</code>) hem gizler hem 403 verir. <b>View-cap</b> (Pipeline/Pazar/Özet) ekranı gizler ama veri paylaşımlı rapor ucundan gelir.</p>
      </div>

      <div class="yh-sec"><h2>5 · Sık işler</h2><div class="yh-how">
        <div class="yh-step"><span class="yh-n">A</span><div><b>Bir gruba yetki ver</b><br>Bölümler › bölümü seç → gruplarda işaretle → (üyeler açıksa işaretle) → <b>Kaydet &amp; uygula</b>. Tüm üyeler şablona hizalanır.</div></div>
        <div class="yh-step"><span class="yh-n">B</span><div><b>Tek kişiyi kısıtla</b><br>Kişiler › kişiyi seç → istemediğin sekmelerin işaretini kaldır → <b>Kaydet</b>. <code>personal_deny</code> oluşur; grup etkilenmez, sonraki uygula ezmez.</div></div>
        <div class="yh-step"><span class="yh-n">C</span><div><b>Tek kişiye ekstra ver</b><br>Kişiler › kişiyi seç → bölümde olmayan yetkiyi işaretle → <b>Kaydet</b>. <code>personal_grant</code> oluşur; yalnız o kişide.</div></div>
        <div class="yh-step"><span class="yh-n">D</span><div><b>"Neden bunu görüyor?"</b><br>Denetim › Yetki Denetimi › kişiyi seç → her yetkinin kaynağı renk-kodlu. Admin ise net uyarı çıkar.</div></div>
        <div class="yh-step"><span class="yh-n">E</span><div><b>Veri kapsamını ayarla</b><br>Bölümler › bölüm › Veri kapsamı: Kendi/Bölge/Bölüm/Tümü → uygula. Sahiplik kaynağı: Müşteriler › Atama (<code>sorumlu_rep</code>).</div></div>
      </div></div>

      <div class="yh-sec"><h2>6 · Uçlar (endpoint)</h2>
        <table class="yh-tbl"><thead><tr><th>Uç</th><th>Ne</th></tr></thead><tbody>
          <tr><td><code>GET/POST /api/tenant/departments</code></td><td>Bölüm listele / oluştur</td></tr>
          <tr><td><code>PATCH/DELETE /api/tenant/departments/:id</code></td><td>Şablon güncelle / sil</td></tr>
          <tr><td><code>GET/POST …/departments/:id/members</code></td><td>Üye listele / ekle-çıkar (recompute)</td></tr>
          <tr><td><code>POST …/departments/:id/apply</code></td><td>Şablonu üyelere uygula (recompute)</td></tr>
          <tr><td><code>PATCH /api/tenant/users/:id/modules</code></td><td>Kişi yetkisi (personal_grant/deny türetir)</td></tr>
          <tr><td><code>GET /api/tenant/users/:id/yetki-kaynak</code></td><td>Etkin-yetki denetçisi verisi</td></tr>
          <tr><td><code>GET /api/tenant/yetki-log</code></td><td>Yetki değişiklik günlüğü</td></tr>
          <tr><td><code>SAHA_DEPT_MAP</code> (server)</td><td>Her saha ucu → gerekli capability (enforce)</td></tr>
        </tbody></table>
      </div>

      <div class="yh-sec"><h2>7 · Veri modeli</h2>
        <p><code>tenant_user_modules.permissions_json</code> (module_id = 'saha'):</p>
        <pre class="yh-code">{
  "departments":    ["ozet","risk","etki", ...],   // ETKIN yetki (gating bunu okur)
  "personal_grant": ["kapsam"],                     // kisisel ekleme
  "personal_deny":  ["ciro"],                       // kisisel cikarma
  "scope": { "level":"kendi|bolge|bolum|tumu", "regions":[], "segments":[] },
  "saha_tip": "TUKETICI|TICARI|KARMA"
}</pre>
        <table class="yh-tbl"><thead><tr><th>Tablo</th><th>Ne</th></tr></thead><tbody>
          <tr><td><code>tenant_department</code></td><td>Bölüm + <code>template_json{capabilities,scope}</code></td></tr>
          <tr><td><code>tenant_department_membership</code></td><td>Kişi ↔ bölüm üyeliği</td></tr>
          <tr><td><code>tenant_yetki_log</code></td><td>Değişiklik günlüğü (actor/target/department/eylem/detay/ts)</td></tr>
          <tr><td><code>saha_musteri.sorumlu_rep</code></td><td>Veri kapsamının kaynağı (Atama panelinden)</td></tr>
        </tbody></table>
      </div>

      <div class="yh-sec yh-warn-sec"><h2>⚠ Dikkat</h2><ul>
        <li><b>Admin = her şey.</b> Bir kişi "hepsini görüyorsa" önce saha rolüne bak — admin departments'ı okumaz.</li>
        <li><b>"Uygula" grubu hizalar.</b> Şablonu tüm-grup tabanı olarak kur; tek kişiyi Kişiler'den ayır.</li>
        <li><b>Çıkış-giriş şart.</b> Yetki değişikliği aktif oturuma anında yansımaz.</li>
        <li><b>Kayıt bırak.</b> Her yapısal değişiklik <code>bi_insa_gunlugu</code> + <code>bi_yetenek</code>'e işlenir (fingerprint sözleşmesi).</li>
      </ul></div>

      <div class="yh-foot">KRB / Derive · Yetki Modülü v2 · Bölümler=yasa · Kişiler=istisna · Roller=referans · Denetim=durum+tarih</div>
    </div>`;
  }

'''
s = s.replace(FN_ANCH, FN + FN_ANCH, 1)

# 4) yh-* CSS — yl blogunun sonuna
CSS_ANCH = '     .yl-ey-uyelik{background:#ecfdf5;color:#047857}'
assert s.count(CSS_ANCH) == 1, "yl-ey-uyelik css anchor=%d" % s.count(CSS_ANCH)
CSS = CSS_ANCH + '''
     /* YETKI_YARDIM_V1 — yetki rehberi */
     .yh{max-width:920px;line-height:1.6;color:#1f2937}
     .yh-hero{background:linear-gradient(135deg,#1e293b,#334155);color:#fff;padding:22px 24px;border-radius:14px;margin-bottom:20px}
     .yh-hero h1{margin:0 0 8px;font-size:22px}
     .yh-hero p{margin:0;color:#cbd5e1;font-size:14px}.yh-hero b{color:#fff}
     .yh-sec{margin:22px 0}
     .yh-sec h2{font-size:16px;color:#0f172a;border-bottom:2px solid #eef2f6;padding-bottom:8px;margin:0 0 14px}
     .yh-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:12px}
     .yh-card{background:#f8fafc;border:1px solid #eef2f6;border-radius:12px;padding:14px}
     .yh-ct{font-weight:800;margin-bottom:6px;font-size:14px}
     .yh-card p{margin:0;font-size:13px;color:#475569}
     .yh-formula{background:#0f172a;color:#a7f3d0;font-family:ui-monospace,Menlo,monospace;font-size:13px;padding:14px 16px;border-radius:10px;text-align:center;margin-bottom:14px;overflow-x:auto}
     .yh ul{margin:8px 0;padding-left:20px}.yh li{margin:6px 0;font-size:13px}
     .yh-tbl{width:100%;border-collapse:collapse;font-size:13px;margin:6px 0}
     .yh-tbl th{text-align:left;background:#f1f5f9;padding:8px 10px;font-weight:700;font-size:12px}
     .yh-tbl td{padding:8px 10px;border-bottom:1px solid #f1f5f9;vertical-align:top}
     .yh-note{font-size:12px;color:#64748b;background:#f8fafc;border-left:3px solid #cbd5e1;padding:8px 12px;border-radius:0 8px 8px 0;margin:8px 0}
     .yh-how{display:flex;flex-direction:column;gap:10px}
     .yh-step{display:flex;gap:12px;background:#f8fafc;border:1px solid #eef2f6;border-radius:10px;padding:12px;font-size:13px}
     .yh-n{flex:none;width:26px;height:26px;border-radius:50%;background:#1d4ed8;color:#fff;font-weight:800;display:flex;align-items:center;justify-content:center;font-size:13px}
     .yh code{background:#eef2f6;padding:1px 6px;border-radius:5px;font-family:ui-monospace,Menlo,monospace;font-size:12px;color:#0f172a}
     .yh-code{background:#0f172a;color:#e2e8f0;padding:14px 16px;border-radius:10px;font-size:12px;overflow-x:auto;line-height:1.5;white-space:pre}
     .yh-warn-sec ul{background:#fffbeb;border:1px solid #fde68a;border-radius:10px;padding:12px 12px 12px 32px}
     .yh-warn-sec li{color:#92400e}
     .yh-foot{margin-top:24px;padding-top:14px;border-top:1px solid #eef2f6;color:#94a3b8;font-size:12px;text-align:center}'''
s = s.replace(CSS_ANCH, CSS, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_YARDIM_V1 (tenant-admin.js) — Yardim > Yetki Rehberi (teknik dok) + yh-* stiller")
