/* MANAGER_PF_LISTE_V1 — drill listesi: bir rep'in / kovanın GERÇEK müşterileri.
   Salt-okunur. GET /api/saha/manager-portfoyum/liste?tip=rep|kova&ref=<user_id|segment>&donem=...
   NEREYE: /api/saha/manager-portfoyum/ekran endpoint'inin HEMEN ÜSTÜNE (patch otomatik yapar). */
if (method === "GET" && path === "/api/saha/manager-portfoyum/liste") {
  const session = await requireSahaAccess(request, ["manager", "admin"]);
  const T = session.tenantId;
  let _u; try { _u = new URL(request.url, "http://x"); } catch (e) { _u = null; }
  const tip = (_u && _u.searchParams.get("tip")) || "rep";
  const ref = (_u && _u.searchParams.get("ref")) || "";
  if (!ref) { sendJson(response, 200, { tip, ref, toplam: 0, liste: [] }); return; }
  const params = [T];
  let filt;
  if (tip === "kova") { params.push(ref); filt = "f.segment = $" + params.length; }
  else { params.push(ref); filt = "f.sorumlu_rep::text = $" + params.length; }  // tip=rep
  const r = await query(
    `WITH mk AS (
        SELECT DISTINCT ON (m.musteri_kodu) m.musteri_kodu, m.firma, m.il, m.sorumlu_rep, m.id
          FROM saha_musteri m
         WHERE m.tenant_id=$1 AND m.aktif=true AND COALESCE(m.musteri_kodu,'')<>''
         ORDER BY m.musteri_kodu, m.id
     ),
     f AS (
        SELECT mk.*, sk.segment
          FROM mk LEFT JOIN saha_satis_skor sk ON sk.tenant_id=$1 AND sk.musteri_kodu=mk.musteri_kodu
         WHERE ${filt}
     )
     SELECT f.musteri_kodu, f.firma, f.il, f.segment,
            round(COALESCE(c.ciro,0))::bigint AS ciro_12, z.son_ziyaret
       FROM f
       LEFT JOIN LATERAL (
            SELECT sum(x.satir_tutar) AS ciro FROM bi_satis_faturalari x
             WHERE x.tenant_id::text=$1::text AND x.musteri_kodu=f.musteri_kodu AND x.satir_tutar>0
               AND x.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
               AND x.grup_adi NOT IN ('PRİM HAKEDİŞLERİ','HAMMADDE','DURAN VARLIKLAR','ALINAN HIZMETLER')
       ) c ON true
       LEFT JOIN LATERAL (
            SELECT max(z2.ziyaret_tarihi)::date AS son_ziyaret FROM saha_ziyaret z2
             WHERE z2.tenant_id=$1 AND z2.musteri_id=f.id
       ) z ON true
      ORDER BY ciro_12 DESC NULLS LAST
      LIMIT 200`, params);
  const liste = r.rows.map(x => ({
    musteri_kodu: x.musteri_kodu, firma: x.firma || x.musteri_kodu, il: x.il || "—",
    segment: x.segment || null, ciro_12: +x.ciro_12 || 0, son_ziyaret: x.son_ziyaret || null
  }));
  sendJson(response, 200, { tip, ref, toplam: liste.length, liste });
  return;
}
