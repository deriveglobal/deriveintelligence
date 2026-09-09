/* MANAGER_PF_BEYAZ_V1 — Beyaz alan: bizden alan ama saha temsilcisi olmayan B2B. Salt-okunur.
   GET /api/saha/manager-portfoyum/beyaz  → { hesap, ciro, gruplar:[{grup,hesap,ciro}], liste:[...top 200] }
   NEREYE: /api/saha/manager-portfoyum/ekran endpoint'inin HEMEN ÜSTÜNE (patch otomatik). */
if (method === "GET" && path === "/api/saha/manager-portfoyum/beyaz") {
  const session = await requireSahaAccess(request, ["manager", "admin"]);
  const T = session.tenantId;
  const WS = `
    WITH satan AS (
      SELECT f.musteri_kodu, round(sum(f.satir_tutar))::bigint ciro
        FROM bi_satis_faturalari f
       WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
         AND f.grup_adi NOT IN ('PRİM HAKEDİŞLERİ','HAMMADDE','DURAN VARLIKLAR','ALINAN HIZMETLER')
       GROUP BY 1),
    b2b AS (
      SELECT s.musteri_kodu, s.ciro, r.grup
        FROM satan s JOIN bi_musteri_risk r ON r.tenant_id::text=$1::text AND r.muhatap_kodu=s.musteri_kodu
       WHERE r.grup IN ('FILO TICARI','FILO TUKETICI','TOPTAN','KURUM')),
    ws AS (
      SELECT b.* FROM b2b b
       WHERE NOT EXISTS (SELECT 1 FROM saha_musteri m
                          WHERE m.tenant_id=$1 AND m.aktif AND m.musteri_kodu=b.musteri_kodu AND m.sorumlu_rep IS NOT NULL))`;

  const grupR = (await query(WS + `
    SELECT grup, count(*) hesap, round(sum(ciro))::bigint ciro FROM ws GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;

  const listeR = (await query(WS + `
    SELECT ws.musteri_kodu, mm.musteri_adi AS firma, mm.sehir AS il, ws.ciro AS ciro_12, ws.grup
      FROM ws LEFT JOIN master_musteri mm ON mm.tenant_id=$1 AND mm.musteri_kodu=ws.musteri_kodu
     ORDER BY ws.ciro DESC NULLS LAST LIMIT 200`, [T])).rows;

  const gruplar = grupR.map(x => ({ grup: x.grup, hesap: +x.hesap || 0, ciro: +x.ciro || 0 }));
  const liste = listeR.map(x => ({ musteri_kodu: x.musteri_kodu, firma: x.firma || x.musteri_kodu, il: x.il || "—",
    segment: null, ciro_12: +x.ciro_12 || 0, son_ziyaret: null, grup: x.grup }));
  sendJson(response, 200, {
    hesap: gruplar.reduce((a, g) => a + g.hesap, 0),
    ciro:  gruplar.reduce((a, g) => a + g.ciro, 0),
    gruplar, liste
  });
  return;
}
