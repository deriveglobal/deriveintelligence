#!/usr/bin/env python3
# saha_fix_1b (omurga_78) — Piyasa dosya yuklenince BILDIRIM: saha_sinyal (feed/ozet) + owner'a ANLIK e-posta.
# Rep sorusu: "someone upload any file which can be important" -> owner e-posta ile haberdar olsun.
# ④ (patch_saha_dosya.py) ile ayni POST handler'a eklenir; bagimsiz (once/sonra fark etmez).
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

OLD = '''        [session.tenantId, session.userId, tip, p.baslik || null, p.rakip_marka || null, p.musteri_id || null, mime, buf.length, buf, p.notlar || null]);
      sendJson(response, 200, { dosya: r.rows[0] });
      return;
    }
    if (method === "GET" && path === "/api/saha/piyasa-dosya") {'''
NEW = '''        [session.tenantId, session.userId, tip, p.baslik || null, p.rakip_marka || null, p.musteri_id || null, mime, buf.length, buf, p.notlar || null]);
      // BILDIRIM_V1 — yukleme sinyali (feed/ozet) + owner'a ANLIK e-posta (dosya yuklemesi seyrek)
      try {
        const _tipAd = { FIYAT_LISTESI: "Fiyat Listesi", KAMPANYA: "Kampanya", RAKIP_TEKLIF: "Rakip Teklif", DIGER: "Dosya" }[tip] || "Dosya";
        const _onem = (tip === "FIYAT_LISTESI" || tip === "RAKIP_TEKLIF") ? 3 : 2;
        await query(
          "INSERT INTO saha_sinyal (tenant_id,tip,onem,ozet,detay,kaynak_tip,kaynak_id,rep_id,musteri_id,owner_bildirildi) VALUES ($1,'piyasa_dosya',$2,$3,$4,'piyasa_dosya',$5,$6,$7,TRUE)",
          [session.tenantId, _onem, "📎 Yeni " + _tipAd + ": " + (p.baslik || "(başlıksız)"),
           JSON.stringify({ tip, baslik: p.baslik || null, rakip_marka: p.rakip_marka || null, boyut: buf.length, mime }),
           r.rows[0].id, session.userId, p.musteri_id || null]);
        let _repAd = session.fullName || session.email || "";
        try { const _u = await query("SELECT COALESCE(full_name,email) ad FROM users WHERE id=$1", [session.userId]); _repAd = _u.rows[0]?.ad || _repAd; } catch (e) {}
        let _musAd = "";
        if (p.musteri_id) { try { const _mm = await query("SELECT firma FROM saha_musteri WHERE id=$1 AND tenant_id=$2", [p.musteri_id, session.tenantId]); _musAd = _mm.rows[0]?.firma || ""; } catch (e) {} }
        const _to = await _ownerAlarmEmail();
        const _link = "https://krb.deriveglobal.com/api/saha/piyasa-dosya/" + r.rows[0].id;
        const _body = "Sahadan yeni dosya yuklendi:\\n\\n"
          + "Tur: " + _tipAd + "\\n"
          + "Baslik: " + (p.baslik || "(basliksiz)") + "\\n"
          + (p.rakip_marka ? "Rakip marka: " + p.rakip_marka + "\\n" : "")
          + (_musAd ? "Musteri: " + _musAd + "\\n" : "")
          + (_repAd ? "Temsilci: " + _repAd + "\\n" : "")
          + "Boyut: " + Math.round(buf.length / 1024) + " KB\\n\\n"
          + "Dosyayi ac: " + _link;
        sendGraphMail({ to: _to, subject: "📎 Saha dosya: " + _tipAd + " — " + (p.baslik || _repAd || "yeni yukleme"), body: _body })
          .catch(e => console.error("[piyasa-dosya mail]", e && e.message));
      } catch (e) { console.error("[piyasa-dosya bildirim]", e && e.message); }
      sendJson(response, 200, { dosya: r.rows[0] });
      return;
    }
    if (method === "GET" && path === "/api/saha/piyasa-dosya") {'''

if 'BILDIRIM_V1' in srv:
    sys.exit("ZATEN VAR: saha_fix_1b uygulanmis gibi.")
if OLD not in srv:
    sys.exit("HATA: piyasa-dosya POST anchor bulunamadi (elle bak).")
if srv.count(OLD) != 1:
    sys.exit("UYARI: anchor %d kez — belirsiz." % srv.count(OLD))
srv = srv.replace(OLD, NEW, 1)

shutil.copy2(S, S + ".sahabildirim.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".sahabildirim.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .sahabildirim.bak)")
print("OK: dosya yukleme bildirimi eklendi (sinyal + owner e-posta). docker build + compose up.")
