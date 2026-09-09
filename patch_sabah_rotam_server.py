# -*- coding: utf-8 -*-
# SABAH_ROTAM_V1 (server) — GET /api/saha/rapor/sabah-rotam + POST /api/saha/rep-baslangic
#   Rep'in kitabı → şeffaf öncelik skoru (Risk+İhmal+Değer+Fırsat) + koordinat (m.lat/lng ya da son check-in)
#   + kayıtlı başlangıç + son-check-in'den öneri başlangıç. Başlangıç POST: öner-kabul / check-in / harita.
#   ⚠ TÜM tenant/rep karşılaştırmaları ::text (uuid=text tuzağı yok — RISK_SAHA_FIX1 dersi).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = """      sendJson(response, 200, { rol: session.sahaRole === "rep" ? "rep" : "yonetici", musteriler });
      return;
    }"""
assert s.count(ANCH) == 1, "anchor=%d" % s.count(ANCH)

NEW = ANCH + r"""

    if (method === "GET" && path === "/api/saha/rapor/sabah-rotam") {  /* SABAH_ROTAM_V1 */
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId;
      const bs = await query(`SELECT lat, lng, ad, kaynak FROM saha_rep_baslangic WHERE tenant_id::text=$1::text AND rep_id::text=$2::text LIMIT 1`, [tid, uid]);
      const sg = await query(`SELECT checkin_lat AS lat, checkin_lng AS lng FROM saha_ziyaret WHERE tenant_id::text=$1::text AND rep_id::text=$2::text AND checkin_lat IS NOT NULL ORDER BY ziyaret_tarihi DESC NULLS LAST LIMIT 1`, [tid, uid]);
      const r = await query(`
        WITH risk AS (
          SELECT muhatap_kodu, MAX(vadesi_gecmis)::numeric vg
            FROM bi_musteri_risk WHERE tenant_id::text=$1::text AND COALESCE(musteri_mi, true)=true AND vadesi_gecmis > 0
           GROUP BY muhatap_kodu
        )
        SELECT m.id, m.firma, m.tip, m.il, m.ilce, m.musteri_kodu, m.telefon,
               COALESCE(m.lat, (SELECT z.checkin_lat FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.checkin_lat IS NOT NULL ORDER BY z.ziyaret_tarihi DESC LIMIT 1)) AS lat,
               COALESCE(m.lng, (SELECT z.checkin_lng FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.checkin_lng IS NOT NULL ORDER BY z.ziyaret_tarihi DESC LIMIT 1)) AS lng,
               COALESCE((SELECT rk.vg FROM risk rk WHERE rk.muhatap_kodu=m.musteri_kodu), 0)::numeric AS overdue,
               (SELECT MAX(z.ziyaret_tarihi) FROM saha_ziyaret z WHERE z.tenant_id::text=$1::text AND z.musteri_id=m.id AND z.durum='TAMAMLANDI') AS son_ziyaret,
               COALESCE((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f WHERE f.tenant_id::text=$1::text AND f.musteri_kodu=m.musteri_kodu AND f.fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days')), 0)::numeric AS ciro,
               COALESCE((SELECT COUNT(*) FROM saha_teklif t WHERE t.tenant_id::text=$1::text AND t.musteri_id=m.id AND COALESCE(t.durum,'') NOT IN ('KAZANILDI','KAYBEDILDI','IPTAL','REDDEDILDI','KAPANDI')), 0)::int AS teklif,
               (SELECT MIN(z.ziyaret_tarihi) FROM saha_ziyaret z WHERE z.tenant_id::text=$1::text AND z.musteri_id=m.id AND z.rep_id::text=$2::text AND z.durum='PLANLANDI' AND z.ziyaret_tarihi >= CURRENT_DATE) AS plan_tarihi
          FROM saha_musteri m
         WHERE m.tenant_id::text=$1::text AND m.aktif=true AND m.sorumlu_rep::text=$2::text AND m.musteri_kodu IS NOT NULL`, [tid, uid]);
      const now = Date.now();
      const bugunStr = new Date(now).toISOString().slice(0, 10);
      const duraklar = r.rows.map((x) => {
        let gun = null;
        if (x.son_ziyaret) { const d = new Date(x.son_ziyaret); if (!isNaN(d)) gun = Math.max(0, Math.floor((now - d.getTime()) / 86400000)); }
        const overdue = Number(x.overdue) || 0, ciro = Number(x.ciro) || 0, teklif = Number(x.teklif) || 0;
        const risk = Math.min(35, (overdue / 1e6) * 1.6), ihmal = Math.min(28, (gun === null ? 60 : gun) / 2.2), deger = Math.min(22, (ciro / 1e6) * 0.28), firsat = Math.min(15, teklif * 6);
        const planBugun = x.plan_tarihi ? (new Date(x.plan_tarihi).toISOString().slice(0, 10) === bugunStr) : false;
        return { id: x.id, firma: x.firma, tip: x.tip, il: x.il, ilce: x.ilce, telefon: x.telefon || null,
                 lat: x.lat != null ? Number(x.lat) : null, lng: x.lng != null ? Number(x.lng) : null,
                 overdue, ciro, teklif, gun, skor: Math.round(risk + ihmal + deger + firsat),
                 plan_tarihi: x.plan_tarihi || null, plan_bugun: planBugun };
      });
      sendJson(response, 200, { baslangic: bs.rows[0] || null, oneri_baslangic: sg.rows[0] || null, duraklar });
      return;
    }

    if (method === "POST" && path === "/api/saha/rep-baslangic") {  /* SABAH_ROTAM_V1 */
      const session = await requireSahaAccess(request);
      let raw = ""; for await (const ch of request) raw += ch;
      let body = {}; try { body = raw ? JSON.parse(raw) : {}; } catch (e) { sendJson(response, 400, { error: "gecersiz govde" }); return; }
      const lat = Number(body.lat), lng = Number(body.lng);
      if (!isFinite(lat) || !isFinite(lng)) { sendJson(response, 400, { error: "lat/lng gerekli" }); return; }
      await query(`INSERT INTO saha_rep_baslangic (tenant_id, rep_id, lat, lng, ad, kaynak, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, now())
        ON CONFLICT (tenant_id, rep_id) DO UPDATE SET lat=EXCLUDED.lat, lng=EXCLUDED.lng, ad=EXCLUDED.ad, kaynak=EXCLUDED.kaynak, updated_at=now()`,
        [session.tenantId, session.userId, lat, lng, (body.ad || null), (body.kaynak || "checkin")]);
      sendJson(response, 200, { ok: true, baslangic: { lat, lng, ad: body.ad || null, kaynak: body.kaynak || "checkin" } });
      return;
    }"""

s = s.replace(ANCH, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_V1 (server)")
