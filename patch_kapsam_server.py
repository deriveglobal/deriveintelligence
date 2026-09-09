# -*- coding: utf-8 -*-
# KAPSAM_V1 (server) — Kapsam & Beyaz Alan raporu:
#   GET /api/saha/rapor/kapsam        — kapsam + beyaz alan + eşleşmemiş + kırılımlar (rol-scoped)
#   GET /api/saha/rapor/kapsam-export — tüm portföy CSV (Excel, BOM'lu)
#   POST /api/saha/musteri-aksiyon    — GITTIM/PLANLA/ILET/ATA/SUSTUR/GERI_AL/NOT (loglu + yan etki)
#   + SAHA_DEPT_MAP kayıtları.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "KAPSAM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) SAHA_DEPT_MAP — kapsam uçlarını ekle
o1 = '''    "/api/saha/rapor/sabah-rotam": ["rotam"]
  };'''
n1 = '''    "/api/saha/rapor/sabah-rotam": ["rotam"],
    "/api/saha/rapor/kapsam": ["kapsam", "rapor"],
    "/api/saha/rapor/kapsam-export": ["kapsam", "rapor"],
    "/api/saha/musteri-aksiyon": ["kapsam", "musteriler", "ziyaretler", "rapor"]
  };'''
assert s.count(o1) == 1, "SAHA_DEPT_MAP anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) Endpoint'ler — rep-performans'tan önce ekle
anchor = '    if (method === "GET" && path === "/api/saha/rapor/rep-performans") {'
assert s.count(anchor) == 1, "rep-performans anchor=%d" % s.count(anchor)

BLOCK = r'''    if (method === "GET" && path === "/api/saha/rapor/kapsam") {  /* KAPSAM_V1 */
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, rol = session.sahaRole;
      const gun = Math.max(1, Math.min(365, parseInt(url.searchParams.get("gun") || "90", 10) || 90));
      const from90 = new Date(Date.now() - (gun - 1) * 86400000).toISOString().slice(0, 10);
      const p = [tid, from90];
      let repF = "", tipF = "";
      if (rol === "rep") { p.push(uid); repF = ` AND m.sorumlu_rep::text=$${p.length}::text`; }
      const _tip = url.searchParams.get("tip");
      if (_tip === "TUKETICI" || _tip === "TICARI") { p.push(_tip); tipF = ` AND m.tip=$${p.length}`; }
      const r = await query(`
        WITH vis AS (
          SELECT DISTINCT musteri_id FROM saha_ziyaret
           WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' AND ziyaret_tarihi >= $2
        ),
        ciro AS (
          SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
           WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days')
           GROUP BY musteri_kodu
        ),
        son AS (
          SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret
           WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id
        ),
        mute AS (
          SELECT DISTINCT ON (musteri_id) musteri_id, tur, gerekce, gerekce_metin, aktor_id, olusturma_ts
            FROM saha_musteri_aksiyon
           WHERE tenant_id::text=$1::text AND rapor='kapsam' AND tur IN ('SUSTUR','GERI_AL')
           ORDER BY musteri_id, olusturma_ts DESC
        )
        SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, m.sorumlu_rep::text rid, m.musteri_kodu,
               (m.musteri_kodu IS NOT NULL) matched,
               COALESCE(c.yil,0)::numeric ciro,
               (v.musteri_id IS NOT NULL) visited,
               s.mx son,
               (mu.musteri_id IS NOT NULL AND mu.tur='SUSTUR') muted,
               mu.gerekce, mu.gerekce_metin, mu.aktor_id::text mute_by, mu.olusturma_ts mute_ts
          FROM saha_musteri m
          LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
          LEFT JOIN vis v ON v.musteri_id=m.id
          LEFT JOIN son s ON s.musteri_id=m.id
          LEFT JOIN mute mu ON mu.musteri_id=m.id
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}`, p);
      const nm = await query(`SELECT u.id::text id, COALESCE(u.full_name,u.email,'—') ad
          FROM users u JOIN tenant_users tu ON tu.user_id=u.id WHERE tu.tenant_id::text=$1::text`, [tid]);
      const nameMap = {}; for (const x of nm.rows) nameMap[x.id] = x.ad;
      const now = Date.now();
      const gunOf = (mx) => { if (!mx) return null; const d = new Date(mx); return isNaN(d) ? null : Math.max(0, Math.floor((now - d.getTime()) / 86400000)); };
      const isBeyaz = (x) => x.matched && Number(x.ciro) > 0 && !x.visited && !x.muted;
      const rows = r.rows;
      const portfoy = rows.length;
      const ulasilan = rows.filter(x => x.visited).length;
      const beyaz = rows.filter(isBeyaz).sort((a, b) => Number(b.ciro) - Number(a.ciro));
      const eslesmemisAll = rows.filter(x => !x.matched);
      const eslesmemis = eslesmemisAll.filter(x => !x.visited && !x.muted);
      const susturulan = rows.filter(x => x.muted);
      const beyazCiro = beyaz.reduce((a, x) => a + Number(x.ciro), 0);
      const cityMap = {};
      for (const x of rows) { const il = x.il || "—"; const g = cityMap[il] || (cityMap[il] = { il, portfoy: 0, ulasilan: 0, beyaz_ciro: 0 }); g.portfoy++; if (x.visited) g.ulasilan++; if (isBeyaz(x)) g.beyaz_ciro += Number(x.ciro); }
      const sehir = Object.values(cityMap).sort((a, b) => b.beyaz_ciro - a.beyaz_ciro).slice(0, 25).map(g => ({ ...g, kapsam: g.portfoy ? Math.round(g.ulasilan / g.portfoy * 100) : 0 }));
      const segMap = {};
      for (const x of rows) { const sg = (x.tip === "TUKETICI" || x.tip === "TICARI") ? x.tip : "DIGER"; const g = segMap[sg] || (segMap[sg] = { seg: sg, portfoy: 0, ulasilan: 0, beyaz_ciro: 0 }); g.portfoy++; if (x.visited) g.ulasilan++; if (isBeyaz(x)) g.beyaz_ciro += Number(x.ciro); }
      const segment = Object.values(segMap).map(g => ({ ...g, kapsam: g.portfoy ? Math.round(g.ulasilan / g.portfoy * 100) : 0 }));
      let temsilci = [];
      if (rol !== "rep") {
        const rm = {};
        for (const x of rows) { const rid = x.rid; if (!rid) continue; const g = rm[rid] || (rm[rid] = { rep_id: rid, rep: nameMap[rid] || "—", portfoy: 0, ulasilan: 0, beyaz_sayi: 0, beyaz_ciro: 0 }); g.portfoy++; if (x.visited) g.ulasilan++; if (isBeyaz(x)) { g.beyaz_sayi++; g.beyaz_ciro += Number(x.ciro); } }
        temsilci = Object.values(rm).map(g => ({ ...g, kapsam: g.portfoy ? Math.round(g.ulasilan / g.portfoy * 100) : 0 })).sort((a, b) => b.beyaz_ciro - a.beyaz_ciro);
      }
      const mapRow = (x) => ({ id: x.id, firma: x.firma, il: x.il, tip: x.tip, ciro: Number(x.ciro) || 0, gun: gunOf(x.son), rep: x.rid ? (nameMap[x.rid] || null) : null, rep_id: x.rid || null });
      sendJson(response, 200, {
        rol: rol === "rep" ? "rep" : "yonetici", gun,
        ozet: { portfoy, ulasilan, kapsam: portfoy ? Math.round(ulasilan / portfoy * 100) : 0, beyaz_sayi: beyaz.length, beyaz_ciro: beyazCiro, eslesmemis_sayi: eslesmemisAll.length },
        sehir, segment, temsilci,
        beyaz: beyaz.slice(0, 300).map(mapRow), beyaz_toplam: beyaz.length,
        eslesmemis: eslesmemis.slice(0, 200).map(mapRow), eslesmemis_toplam: eslesmemis.length,
        hepsi: rows.slice().sort((a, b) => Number(b.ciro) - Number(a.ciro)).slice(0, 1000).map(x => ({ ...mapRow(x), durum: x.muted ? "susturuldu" : !x.matched ? "eslesmemis" : x.visited ? "ulasildi" : "beyaz" })), hepsi_toplam: rows.length,
        susturulan: (rol !== "rep" ? susturulan : susturulan.filter(x => x.mute_by === uid)).slice(0, 100).map(x => ({ id: x.id, firma: x.firma, il: x.il, gerekce: x.gerekce, gerekce_metin: x.gerekce_metin, mute_by: x.mute_by ? (nameMap[x.mute_by] || "—") : "—", mute_ts: x.mute_ts }))
      });
      return;
    }

    if (method === "GET" && path === "/api/saha/rapor/kapsam-export") {  /* KAPSAM_V1 */
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, rol = session.sahaRole;
      const gun = Math.max(1, Math.min(365, parseInt(url.searchParams.get("gun") || "90", 10) || 90));
      const from90 = new Date(Date.now() - (gun - 1) * 86400000).toISOString().slice(0, 10);
      const p = [tid, from90];
      let repF = "", tipF = "";
      if (rol === "rep") { p.push(uid); repF = ` AND m.sorumlu_rep::text=$${p.length}::text`; }
      const _tip = url.searchParams.get("tip");
      if (_tip === "TUKETICI" || _tip === "TICARI") { p.push(_tip); tipF = ` AND m.tip=$${p.length}`; }
      const r = await query(`
        WITH vis AS (SELECT DISTINCT musteri_id FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' AND ziyaret_tarihi >= $2),
             ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),
             son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id),
             mute AS (SELECT DISTINCT ON (musteri_id) musteri_id, tur FROM saha_musteri_aksiyon WHERE tenant_id::text=$1::text AND rapor='kapsam' AND tur IN ('SUSTUR','GERI_AL') ORDER BY musteri_id, olusturma_ts DESC)
        SELECT m.firma, m.il, m.ilce, m.tip, m.musteri_kodu, m.sorumlu_rep::text rid,
               (m.musteri_kodu IS NOT NULL) matched, COALESCE(c.yil,0)::numeric ciro,
               (v.musteri_id IS NOT NULL) visited, s.mx son, (mu.musteri_id IS NOT NULL AND mu.tur='SUSTUR') muted
          FROM saha_musteri m
          LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
          LEFT JOIN vis v ON v.musteri_id=m.id LEFT JOIN son s ON s.musteri_id=m.id LEFT JOIN mute mu ON mu.musteri_id=m.id
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}
         ORDER BY COALESCE(c.yil,0) DESC`, p);
      const nm = await query(`SELECT u.id::text id, COALESCE(u.full_name,u.email,'—') ad FROM users u JOIN tenant_users tu ON tu.user_id=u.id WHERE tu.tenant_id::text=$1::text`, [tid]);
      const nameMap = {}; for (const x of nm.rows) nameMap[x.id] = x.ad;
      const now = Date.now();
      const durumOf = (x) => x.muted ? "susturuldu" : !x.matched ? "eslesmemis" : x.visited ? "ulasildi" : "beyaz_alan";
      const esc = (s2) => { s2 = (s2 == null ? "" : String(s2)); return /[";\n]/.test(s2) ? '"' + s2.replace(/"/g, '""') + '"' : s2; };
      const lines = ["Firma;Il;Ilce;Segment;MusteriKodu;YillikCiro12Ay;SonZiyaretGun;Sorumlu;Durum"];
      for (const x of r.rows) {
        const g = x.son ? Math.max(0, Math.floor((now - new Date(x.son).getTime()) / 86400000)) : "";
        lines.push([esc(x.firma), esc(x.il), esc(x.ilce), esc(x.tip || ""), esc(x.musteri_kodu || ""), Math.round(Number(x.ciro) || 0), g, esc(x.rid ? (nameMap[x.rid] || "") : ""), durumOf(x)].join(";"));
      }
      const csv = "﻿" + lines.join("\n");
      response.writeHead(200, { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": 'attachment; filename="kapsam-beyaz-alan.csv"' });
      response.end(csv);
      return;
    }

    if (method === "POST" && path === "/api/saha/musteri-aksiyon") {  /* KAPSAM_V1 */
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, rol = session.sahaRole;
      let raw = ""; for await (const ch of request) raw += ch;
      let b = {}; try { b = raw ? JSON.parse(raw) : {}; } catch (e) { sendJson(response, 400, { error: "gecersiz govde" }); return; }
      const musteri_id = b.musteri_id, tur = String(b.tur || "").toUpperCase();
      const TUR = ["GITTIM", "PLANLA", "ILET", "ATA", "SUSTUR", "GERI_AL", "NOT"];
      if (!musteri_id || !TUR.includes(tur)) { sendJson(response, 400, { error: "musteri_id ve gecerli tur gerekli" }); return; }
      const mm = await query(`SELECT id, tip, sorumlu_rep::text rid FROM saha_musteri WHERE tenant_id::text=$1::text AND id=$2`, [tid, musteri_id]);
      if (!mm.rowCount) { sendJson(response, 404, { error: "musteri yok" }); return; }
      const mus = mm.rows[0];
      if (rol === "rep" && mus.rid && mus.rid !== uid) { sendJson(response, 403, { error: "bu musteri sizin degil" }); return; }
      if ((tur === "ATA" || tur === "ILET") && rol === "rep") { sendJson(response, 403, { error: "bu islem yonetici yetkisi" }); return; }
      const bugunTR = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
      let ziyaret_id = null, hedef_rep = null;
      if (tur === "GITTIM") {
        const zi = await query(`INSERT INTO saha_ziyaret (tenant_id,musteri_id,rep_id,tip,durum,planlanan_tarih,ziyaret_tarihi,notlar,detay,created_by) VALUES ($1,$2,$3,$4,'TAMAMLANDI',NULL,$5,$6,'{"kaynak":"KAPSAM_GITTIM"}'::jsonb,$3) RETURNING id`, [tid, musteri_id, uid, mus.tip || null, bugunTR, "Kapsam raporu: geç kayıt (gittim)"]);
        ziyaret_id = zi.rows[0].id;
      } else if (tur === "PLANLA") {
        const zi = await query(`INSERT INTO saha_ziyaret (tenant_id,musteri_id,rep_id,tip,durum,planlanan_tarih,ziyaret_tarihi,notlar,detay,created_by) VALUES ($1,$2,$3,$4,'PLANLANDI',$5,NULL,$6,'{"kaynak":"KAPSAM_PLANLA"}'::jsonb,$3) RETURNING id`, [tid, musteri_id, uid, mus.tip || null, bugunTR, "Kapsam raporu: planlandı"]);
        ziyaret_id = zi.rows[0].id;
      } else if (tur === "ILET") {
        hedef_rep = mus.rid || b.hedef_rep || null;
        if (!hedef_rep) { sendJson(response, 400, { error: "iletilecek sorumlu temsilci yok — once ata" }); return; }
        const zi = await query(`INSERT INTO saha_ziyaret (tenant_id,musteri_id,rep_id,tip,durum,planlanan_tarih,ziyaret_tarihi,notlar,detay,created_by) VALUES ($1,$2,$3,$4,'PLANLANDI',$5,NULL,$6,'{"kaynak":"KAPSAM_ILET"}'::jsonb,$7) RETURNING id`, [tid, musteri_id, hedef_rep, mus.tip || null, bugunTR, "Kapsam: yöneticiden iletildi", uid]);
        ziyaret_id = zi.rows[0].id;
      } else if (tur === "ATA") {
        hedef_rep = b.hedef_rep || null;
        if (!hedef_rep) { sendJson(response, 400, { error: "hedef_rep gerekli" }); return; }
        await query(`UPDATE saha_musteri SET sorumlu_rep=$3 WHERE tenant_id::text=$1::text AND id=$2`, [tid, musteri_id, hedef_rep]);
      }
      await query(`INSERT INTO saha_musteri_aksiyon (tenant_id,musteri_id,rapor,tur,aktor_id,aktor_rol,gerekce,gerekce_metin,hedef_rep,ziyaret_id) VALUES ($1,$2,'kapsam',$3,$4,$5,$6,$7,$8,$9)`,
        [tid, musteri_id, tur, uid, rol, (b.gerekce || null), (b.gerekce_metin || null), hedef_rep, ziyaret_id]);
      sendJson(response, 200, { ok: true, tur, ziyaret_id, hedef_rep });
      return;
    }

'''
s = s.replace(anchor, BLOCK + anchor, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_V1 (server) — 3 endpoint + SAHA_DEPT_MAP")
