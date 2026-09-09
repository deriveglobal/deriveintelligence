# -*- coding: utf-8 -*-
# SABAH_ROTAM_MGR_V1 (server) — sabah-rotam'a YÖNETİCİ dalı: ekip dağılımı + öncelik uyumu + sahipsiz kritik.
#   Rep → kişisel rota (mevcut). Manager/admin → {rol:"yonetici", toplam, ekip, kritik}.
#   Skor per-müşteri = Risk+İhmal+Değer+Fırsat (rep rotasıyla AYNI). CTE'lerle hızlı (korelasyon subquery yok).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_MGR_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_V1" in s, "HATA: once SABAH_ROTAM_V1 olmali"

# 1) rep yanıtına rol:"rep" ekle
o1 = "      sendJson(response, 200, { baslangic: bs.rows[0] || null, oneri_baslangic: sg.rows[0] || null, duraklar });"
n1 = "      sendJson(response, 200, { rol: \"rep\", baslangic: bs.rows[0] || null, oneri_baslangic: sg.rows[0] || null, duraklar });"
assert s.count(o1) == 1, "rep sendJson anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) yönetici dalı — session+tid+uid'den hemen sonra
anchor = "      const session = await requireSahaAccess(request);\n      const tid = session.tenantId, uid = session.userId;"
MGR = anchor + r'''
      if (session.sahaRole === "manager" || session.sahaRole === "admin") {  /* SABAH_ROTAM_MGR_V1 */
        const vc = await query(`SELECT rep_id::text rid,
                 COUNT(*) FILTER (WHERE durum='PLANLANDI' AND ziyaret_tarihi=CURRENT_DATE)::int plan,
                 COUNT(*) FILTER (WHERE durum='TAMAMLANDI' AND ziyaret_tarihi=CURRENT_DATE)::int yapilan
            FROM saha_ziyaret WHERE tenant_id::text=$1::text AND rep_id IS NOT NULL GROUP BY rep_id`, [tid]);
        const rp = await query(`SELECT u.id::text rid, COALESCE(u.full_name, u.email, '—') ad,
                 (SELECT tum.permissions_json->>'saha_tip' FROM tenant_user_modules tum WHERE tum.user_id=u.id AND tum.tenant_id::text=$1::text AND tum.module_id='saha' LIMIT 1) saha_tip
            FROM users u WHERE u.id IN (SELECT DISTINCT sorumlu_rep FROM saha_musteri WHERE tenant_id::text=$1::text AND aktif=true AND sorumlu_rep IS NOT NULL)`, [tid]);
        const cu = await query(`
          WITH risk AS (SELECT muhatap_kodu, MAX(vadesi_gecmis)::numeric vg FROM bi_musteri_risk WHERE tenant_id::text=$1::text AND COALESCE(musteri_mi,true)=true AND vadesi_gecmis>0 GROUP BY muhatap_kodu),
               ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),
               son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id),
               tek AS (SELECT musteri_id, COUNT(*) c FROM saha_teklif WHERE tenant_id::text=$1::text AND COALESCE(durum,'') NOT IN ('KAZANILDI','KAYBEDILDI','IPTAL','REDDEDILDI','KAPANDI') GROUP BY musteri_id),
               plani AS (SELECT DISTINCT musteri_id FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='PLANLANDI' AND ziyaret_tarihi=CURRENT_DATE)
          SELECT m.id::text id, m.firma, m.il, m.ilce, m.sorumlu_rep::text rid,
                 COALESCE(r.vg,0)::numeric overdue, COALESCE(c.yil,0)::numeric ciro, COALESCE(t.c,0)::int teklif, s.mx son,
                 (p.musteri_id IS NOT NULL) planned_today
            FROM saha_musteri m
            LEFT JOIN risk r ON r.muhatap_kodu=m.musteri_kodu
            LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
            LEFT JOIN son s ON s.musteri_id=m.id
            LEFT JOIN tek t ON t.musteri_id=m.id
            LEFT JOIN plani p ON p.musteri_id=m.id
           WHERE m.tenant_id::text=$1::text AND m.aktif=true AND m.musteri_kodu IS NOT NULL`, [tid]);
        const now = Date.now();
        const skorOf = (overdue, gun, ciro, teklif) => {
          const risk = Math.min(35, (overdue / 1e6) * 1.6), ihmal = Math.min(28, (gun === null ? 60 : gun) / 2.2), deger = Math.min(22, (ciro / 1e6) * 0.28), firsat = Math.min(15, teklif * 6);
          return Math.round(risk + ihmal + deger + firsat);
        };
        const repMap = {}; for (const r of rp.rows) repMap[r.rid] = { ad: r.ad, saha_tip: r.saha_tip };
        const vcMap = {}; for (const v of vc.rows) vcMap[v.rid] = { plan: v.plan || 0, yapilan: v.yapilan || 0 };
        const ekipMap = {};
        for (const rid in repMap) ekipMap[rid] = { rid, oneri: 0, skip: null };
        const kritik = [];
        for (const x of cu.rows) {
          let gun = null; if (x.son) { const d = new Date(x.son); if (!isNaN(d)) gun = Math.max(0, Math.floor((now - d.getTime()) / 86400000)); }
          const overdue = Number(x.overdue) || 0, ciro = Number(x.ciro) || 0, teklif = Number(x.teklif) || 0;
          const skor = skorOf(overdue, gun, ciro, teklif);
          const rid = x.rid;
          if (rid) { const e = ekipMap[rid] || (ekipMap[rid] = { rid, oneri: 0, skip: null }); if (skor >= 40) e.oneri++; if (!x.planned_today && (!e.skip || skor > e.skip.s)) e.skip = { f: x.firma, s: skor, id: x.id }; }
          if (skor >= 55 && !x.planned_today) kritik.push({ id: x.id, firma: x.firma, il: x.il, ilce: x.ilce, skor, rid, overdue, gun });
        }
        kritik.sort((a, b) => b.skor - a.skor);
        const kritikTop = kritik.slice(0, 12).map((k) => ({ id: k.id, firma: k.firma, il: k.il, ilce: k.ilce, skor: k.skor, overdue: k.overdue, gun: k.gun, rep: k.rid ? (repMap[k.rid] ? repMap[k.rid].ad : null) : null }));
        const ekip = Object.values(ekipMap).map((e) => { const r = repMap[e.rid] || {}, v = vcMap[e.rid] || {}; return { rep: r.ad || "—", rep_id: e.rid, saha_tip: r.saha_tip || null, plan: v.plan || 0, yapilan: v.yapilan || 0, oneri: e.oneri, skip: e.skip }; })
          .sort((a, b) => ((b.skip ? b.skip.s : 0) - (a.skip ? a.skip.s : 0)));
        const toplam = { plan: ekip.reduce((s2, e) => s2 + e.plan, 0), yapilan: ekip.reduce((s2, e) => s2 + e.yapilan, 0), oneri: ekip.reduce((s2, e) => s2 + e.oneri, 0), kritik: kritik.length, sahipsiz: kritik.filter((k) => !k.rid).length };
        sendJson(response, 200, { rol: "yonetici", toplam, ekip, kritik: kritikTop });
        return;
      }'''
assert s.count(anchor) == 1, "mgr anchor=%d" % s.count(anchor)
s = s.replace(anchor, MGR, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_MGR_V1 (server)")
