#!/usr/bin/env python3
# omurga_75 — Piyasa Radar CANLI: kokpit-data'ya 'piyasa' blogu (SADECE izlenen SKU: bi_rakip_izle).
# son_min_fiyat + hedef band + alarm; bize-karsi-fark YOK (bi_price_monitor bos -> durustce sonraki adim).
# Yedekli + node --check'li + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

CORE = 'sendJson(response, 200, { trend, marka, segment, sezon, kanal, insights });'
if 'insights, piyasa }' in srv:
    sys.exit("ZATEN VAR: piyasa blogu eklenmis gibi.")
if CORE not in srv:
    sys.exit("HATA: kokpit-data sendJson satiri bulunamadi (elle bak).")
if srv.count(CORE) != 1:
    sys.exit("UYARI: birden fazla eslesme — belirsiz, elle bak.")

BLOCK = '''let piyasa = null;
      try {
        const pz = await query(`SELECT z.marka, z.ebat, z.son_min_fiyat::float8 son_min,
            z.hedef_dusuk::float8 hd, z.hedef_yuksek::float8 hy, z.alarm_esigi::float8 esik,
            (SELECT count(*) FROM bi_rakip_fiyat_alarm a WHERE a.izle_id=z.id AND a.tenant_id::text=$1 AND NOT a.goruldu)::int alarm
          FROM bi_rakip_izle z WHERE z.tenant_id::text=$1 AND z.aktif
          ORDER BY alarm DESC, z.marka LIMIT 12`, [T]);
        const ps = (await query(`SELECT
            (SELECT count(*) FROM bi_rakip_izle WHERE tenant_id::text=$1 AND aktif)::int izle_n,
            (SELECT count(*) FROM bi_rakip_fiyat_alarm WHERE tenant_id::text=$1 AND NOT goruldu)::int alarm,
            (SELECT to_char(max(scraped_at),'YYYY-MM-DD HH24:MI') FROM bi_rakip_fiyat_son WHERE tenant_id::text=$1) taze`, [T])).rows[0] || {};
        piyasa = { taze: ps.taze || null, izle_n: ps.izle_n || 0, alarm: ps.alarm || 0, izlenen: pz.rows };
      } catch (e) { console.error("[kokpit-data piyasa]", e && e.message); piyasa = null; }
      sendJson(response, 200, { trend, marka, segment, sezon, kanal, insights, piyasa });'''

srv = srv.replace(CORE, BLOCK, 1)
shutil.copy2(S, S + ".piyasa.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".piyasa.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .piyasa.bak)")
print("OK: kokpit-data 'piyasa' blogu eklendi (izlenen SKU radar). kokpit.html -> shells/, sonra docker build + compose up.")
