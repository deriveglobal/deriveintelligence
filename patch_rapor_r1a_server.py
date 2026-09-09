# -*- coding: utf-8 -*-
# RAPOR_R1A (server) — GUVEN duzeltmeleri (dogruluk):
#  1) Saha ROI: kapsam sayimi ever(tum-zaman) -> vc>0 (son 12 ay); ihmal/grup ort_ciro h1(6ay) -> h1+h2 (12 ay, "yillik" durust).
#  2) Rotam: plan-tespiti ziyaret_tarihi -> COALESCE(ziyaret_tarihi, planlanan_tarih) (Planla/Ilet artik Rotam'a duser); 3 nokta.
#  3) Rotam: yonetici panosu _sahaScopeSql (bolge/bolum yoneticisi tenant-genelini gormesin; opt-in, tumu/admin -> filtre yok).
#  4) Ciro: yonetici mukerrer toplam bug'i -> distinct-musteri gercek toplam alani (toplam_etki_ciro/toplam_musteri) eklendi (client R1B tuketir).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAPOR_R1A" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "_sahaScopeSql" in s, "_sahaScopeSql (FAZ3A) gerekli"

# ── 1) SAHA ROI kapsam: ever -> vc>0 ──
A1 = '      const ziyaretEdilmis = rows.filter((x) => x.ever).length;'
assert s.count(A1) == 1, "ROI ziyaretEdilmis anchor=%d" % s.count(A1)
s = s.replace(A1, '      const ziyaretEdilmis = rows.filter((x) => x.vc > 0).length;  /* RAPOR_R1A — son 12 ay (ever/tum-zaman degil) */', 1)

# ── 1b) SAHA ROI ort_ciro: h1(6ay) -> h1+h2 (12 ay) ──
A2 = '        const ortCiro = taban.length ? Math.round(taban.reduce((a, x) => a + x.h1, 0) / taban.length) : 0;'
assert s.count(A2) == 1, "ROI ortCiro anchor=%d" % s.count(A2)
s = s.replace(A2, '        const ortCiro = taban.length ? Math.round(taban.reduce((a, x) => a + x.h1 + x.h2, 0) / taban.length) : 0;  /* RAPOR_R1A — 12 ay (h1+h2), "yillik" durust */', 1)

# ── 2) ROTAM plan-tespiti COALESCE (3 nokta) ──
R1 = "                 COUNT(*) FILTER (WHERE durum='PLANLANDI' AND ziyaret_tarihi=CURRENT_DATE)::int plan,"
assert s.count(R1) == 1, "rotam vc plan anchor=%d" % s.count(R1)
s = s.replace(R1, "                 COUNT(*) FILTER (WHERE durum='PLANLANDI' AND COALESCE(ziyaret_tarihi, planlanan_tarih)=CURRENT_DATE)::int plan,  /* RAPOR_R1A */", 1)

R2 = "               plani AS (SELECT DISTINCT musteri_id FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='PLANLANDI' AND ziyaret_tarihi=CURRENT_DATE)"
assert s.count(R2) == 1, "rotam plani CTE anchor=%d" % s.count(R2)
s = s.replace(R2, "               plani AS (SELECT DISTINCT musteri_id FROM saha_ziyaret WHERE tenant_id::text=$1::text AND durum='PLANLANDI' AND COALESCE(ziyaret_tarihi, planlanan_tarih)=CURRENT_DATE)  /* RAPOR_R1A */", 1)

R3 = "               (SELECT MIN(z.ziyaret_tarihi) FROM saha_ziyaret z WHERE z.tenant_id::text=$1::text AND z.musteri_id=m.id AND z.rep_id::text=$2::text AND z.durum='PLANLANDI' AND z.ziyaret_tarihi >= CURRENT_DATE) AS plan_tarihi"
assert s.count(R3) == 1, "rotam rep plan_tarihi anchor=%d" % s.count(R3)
s = s.replace(R3, "               (SELECT MIN(COALESCE(z.ziyaret_tarihi, z.planlanan_tarih)) FROM saha_ziyaret z WHERE z.tenant_id::text=$1::text AND z.musteri_id=m.id AND z.rep_id::text=$2::text AND z.durum='PLANLANDI' AND COALESCE(z.ziyaret_tarihi, z.planlanan_tarih) >= CURRENT_DATE) AS plan_tarihi  /* RAPOR_R1A */", 1)

# ── 3) ROTAM yonetici cu sorgusuna scope ──
C1 = '        const cu = await query(`'
assert s.count(C1) == 1, "rotam cu start anchor=%d" % s.count(C1)
s = s.replace(C1, '        const _cp = [tid]; const _cuScope = _sahaScopeSql(session, _cp, "m");  /* RAPOR_R1A — yonetici veri kapsami */\n        const cu = await query(`', 1)
C2 = '           WHERE m.tenant_id::text=$1::text AND m.aktif=true AND m.musteri_kodu IS NOT NULL`, [tid]);'
assert s.count(C2) == 1, "rotam cu where anchor=%d" % s.count(C2)
s = s.replace(C2, '           WHERE m.tenant_id::text=$1::text AND m.aktif=true AND m.musteri_kodu IS NOT NULL${_cuScope}`, _cp);  /* RAPOR_R1A */', 1)

# ── 4) CIRO yonetici mukerrer toplam -> distinct gercek toplam ──
CIRO = '      sendJson(response, 200, { rol: "yonetici", repler });'
assert s.count(CIRO) == 1, "ciro yonetici sendJson anchor=%d" % s.count(CIRO)
CIRO_NEW = '''      /* RAPOR_R1A — yonetici "Toplam etki ciro": rep satirlarini toplamak ortak musteriyi MUKERRER sayar (gercegi asar). Distinct-musteri gercek toplam. */
      const _tq = await query(`
        WITH vis AS (SELECT DISTINCT z.musteri_id FROM saha_ziyaret z WHERE z.tenant_id=$1 AND z.durum='TAMAMLANDI' AND z.ziyaret_tarihi BETWEEN $2 AND $3),
             cust AS (SELECT DISTINCT m.musteri_kodu FROM vis v JOIN saha_musteri m ON m.id=v.musteri_id WHERE m.musteri_kodu IS NOT NULL${tipSql})
        SELECT COALESCE(SUM((SELECT SUM(f.satir_tutar) FROM bi_satis_faturalari f WHERE f.tenant_id::text=$1::text AND f.musteri_kodu=c.musteri_kodu AND f.fatura_tarihi BETWEEN $2 AND $3)),0)::numeric total,
               COUNT(*)::int musteri FROM cust c`, p);
      const toplam_etki_ciro = Number(_tq.rows[0] && _tq.rows[0].total) || 0, toplam_musteri = Number(_tq.rows[0] && _tq.rows[0].musteri) || 0;
      sendJson(response, 200, { rol: "yonetici", repler, toplam_etki_ciro, toplam_musteri });'''
s = s.replace(CIRO, CIRO_NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_R1A (server) — ROI kapsam/ortciro + Rotam COALESCE×3 + Rotam scope + Ciro distinct toplam")
