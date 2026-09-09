#!/usr/bin/env python3
# omurga_73 YAMA — server_container.mjs (kokpit-data endpoint + /kokpit route) + bi.js (finans odasi -> iframe).
# Yedekli + node --check'li + basarisizsa GERI ALIR. READ sonra WRITE. Sunucuda calisir.
import re, shutil, subprocess, sys, os
REPO="/opt/krb-assessment"
S=f"{REPO}/server_container.mjs"; B=f"{REPO}/shells/bi.js"
Sbak=S+".kokpit.bak"; Bbak=B+".kokpit.bak"

srv=open(S,encoding="utf-8").read()
bijs=open(B,encoding="utf-8").read()

# ---- 1) server_container.mjs: /ops route'undan SONRA iki route ekle ----
if "/api/bi/kokpit-data" in srv: sys.exit("ZATEN VAR: kokpit-data endpoint mevcut — elle bak")
ops_re = re.compile(r'url\.pathname === "/ops"\) \{.*?ops paneli bulunamadi.*?return;\s*\}', re.DOTALL)
_m = ops_re.search(srv)
if not _m: sys.exit("HATA: /ops anchor (regex) bulunamadi — server yamasi iptal")

KOKPIT_ROUTES = r'''
  if (request.method === "GET" && url.pathname === "/kokpit") {
    try {
      const _h = await readFile("/app/shells/kokpit.html", "utf8");
      response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      response.end(_h);
    } catch (e) { sendJson(response, 404, { error: "kokpit bulunamadi" }); }
    return;
  }
  if (request.method === "GET" && url.pathname === "/api/bi/kokpit-data") {
    try {
      const session = await getSessionUser(request);
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const trend = (await query(`SELECT to_char(donem,'YY-MM') ay,
          round((max(deger) FILTER (WHERE metrik='ciro_lastik'))/1e6,1)::float8 ciro,
          round((max(deger) FILTER (WHERE metrik='stok_deger'))/1e6,1)::float8 stok,
          round(max(deger) FILTER (WHERE metrik='dso'))::int dso
        FROM bi_metrik_gecmis WHERE tenant_id=$1::uuid AND boyut_tipi='sirket' AND periyot='ay'
          AND donem>=(CURRENT_DATE - INTERVAL '13 months') GROUP BY donem ORDER BY donem`, [T])).rows;
      const marka = (await query(`WITH a AS (SELECT marka, sum(ciro) ciro, sum(brut_kar) kar, sum(adet) adet
          FROM bi_marj_atom WHERE tenant_id=$1::uuid AND ay>=(CURRENT_DATE - INTERVAL '12 months') GROUP BY marka),
        s AS (SELECT boyut_deger marka, deger stok FROM bi_metrik_gecmis
          WHERE tenant_id=$1::uuid AND metrik='stok_deger' AND boyut_tipi='marka'
            AND donem=(SELECT max(donem) FROM bi_metrik_gecmis WHERE tenant_id=$1::uuid AND metrik='stok_deger' AND boyut_tipi='marka'))
        SELECT a.marka m, round(a.ciro/1e6,1)::float8 c, round((a.kar/nullif(a.ciro,0)*100)::numeric,1)::float8 mj,
               round(coalesce(s.stok,0)/1e6,1)::float8 st, a.adet::int adet
        FROM a LEFT JOIN s ON s.marka=a.marka WHERE a.ciro>0 ORDER BY a.ciro DESC LIMIT 18`, [T])).rows;
      const segment = (await query(`SELECT kategori_segment(kategori) s, round(sum(ciro)/1e6,1)::float8 c,
          round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj
        FROM bi_marj_atom WHERE tenant_id=$1::uuid AND ay>=(CURRENT_DATE - INTERVAL '12 months') GROUP BY 1 ORDER BY 2 DESC`, [T])).rows;
      const sezon = (await query(`SELECT kategori_sezon(kategori) s, round(sum(ciro)/1e6,1)::float8 c,
          round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj
        FROM bi_marj_atom WHERE tenant_id=$1::uuid AND ay>=(CURRENT_DATE - INTERVAL '12 months') GROUP BY 1 ORDER BY 2 DESC`, [T])).rows;
      const kanal = (await query(`WITH cust AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, grup
          FROM bi_musteri_risk WHERE tenant_id=$1::uuid ORDER BY muhatap_kodu, export_date DESC)
        SELECT kanal_normalize(c.grup) k, round(sum(f.satir_tutar)/1e6,1)::float8 c,
          round(((sum(f.satir_tutar)-sum(f.miktar*a.birim_maliyet))/nullif(sum(f.satir_tutar),0)*100)::numeric,1)::float8 mj
        FROM bi_satis_faturalari f
        JOIN bi_marj_atom a ON a.tenant_id=f.tenant_id AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date
        LEFT JOIN cust c ON c.muhatap_kodu=f.musteri_kodu
        WHERE f.tenant_id=$1::uuid AND f.fatura_tarihi>=(CURRENT_DATE - INTERVAL '12 months') AND f.miktar>0
        GROUP BY 1 ORDER BY 2 DESC`, [T])).rows;
      const insights = (await query(`SELECT bolum, tip, ozet, anlati, oneri, guven FROM bi_icgoru
        WHERE tenant_id=$1::uuid AND durum='yeni' ORDER BY surpriz_skoru DESC NULLS LAST, ts DESC LIMIT 30`, [T])).rows;
      sendJson(response, 200, { trend, marka, segment, sezon, kanal, insights });
    } catch (e) { console.error("[kokpit-data]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
'''
srv2 = srv[:_m.end()] + "\n" + KOKPIT_ROUTES + srv[_m.end():]

# ---- 2) bi.js: finans odasi icerigi -> iframe + ciz_finans erken-return ----
if 'src="/kokpit"' in bijs: sys.exit("ZATEN VAR: bi.js kokpit iframe mevcut — bi.js yamasi atlandi")
# 2a) finans-govde innerHTML -> iframe (regex, ellipsis toleransli)
pat = re.compile(r"_f\.innerHTML = '<div id=\"finans-govde\".*?</div>';")
if not pat.search(bijs): sys.exit("HATA: bi.js finans-govde anchor bulunamadi")
iframe = ("""_f.innerHTML = '<iframe id="kokpit-frame" src="/kokpit" style="width:100%;height:100%;min-height:82vh;border:0;display:block;background:#05070a" title="Finans Kokpiti"></iframe>'; try{_f.style.padding='0';}catch(e){}""")
bijs2 = pat.sub(iframe.replace("\\","\\\\"), bijs, count=1)
# 2b) ciz_finans erken-return (finans-govde artik yok -> eski render kosmaz)
ANCH='async function ciz_finans() {'
if ANCH not in bijs2: sys.exit("HATA: bi.js ciz_finans anchor bulunamadi")
bijs2 = bijs2.replace(ANCH, ANCH + "\n    if (!document.getElementById('finans-govde')) return; /* kokpit iframe aktif */", 1)

# ---- 3) YEDEK + YAZ + node --check ----
shutil.copy2(S, Sbak); shutil.copy2(B, Bbak)
open(S,"w",encoding="utf-8").write(srv2)
open(B,"w",encoding="utf-8").write(bijs2)
try:
    chk = subprocess.run(["node","--check",S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(Sbak, S); shutil.copy2(Bbak, B)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI.\n"+chk.stderr)
    print("OK: server_container.mjs + shells/bi.js yamalandi, node --check GECTI.")
except FileNotFoundError:
    print("UYARI: host'ta node yok, --check ATLANDI (yedekler duruyor). Syntax hatasi olursa compose up sonrasi konteyner boot etmez -> yedekle geri al.")
    print("OK: dosyalar yamalandi (check'siz).")
print("Yedekler:", Sbak, Bbak)
print("Sonraki: kokpit.html shells/'e, sonra docker build + compose up.")
