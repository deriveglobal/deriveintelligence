/* MANAGER_PF_LENSLISTE_V1 — lens satırının arkasındaki gerçek müşteriler. Salt-okunur.
   GET /api/saha/manager-portfoyum/lens-liste?tip=sube|bolge|marka|sektor|urun|kohort&ref=<deger>
   NEREYE: /api/saha/manager-portfoyum/ekran endpoint'inin HEMEN ÜSTÜNE (patch otomatik). */
if (method === "GET" && path === "/api/saha/manager-portfoyum/lens-liste") {
  const session = await requireSahaAccess(request, ["manager", "admin"]);
  const T = session.tenantId;
  let _u; try { _u = new URL(request.url, "http://x"); } catch (e) { _u = null; }
  const tip = (_u && _u.searchParams.get("tip")) || "";
  const ref = (_u && _u.searchParams.get("ref")) || "";
  let rows = [];
  if (tip === "urun" && ref) {
    rows = (await query(
      `SELECT m.musteri_kodu, m.musteri_adi AS firma, m.sehir AS il,
              round(COALESCE(c.ciro,0))::bigint AS ciro_12
         FROM master_musteri m
         LEFT JOIN LATERAL (SELECT sum(x.satir_tutar) AS ciro FROM bi_satis_faturalari x
                             WHERE x.tenant_id=$1 AND x.musteri_kodu=m.musteri_kodu AND x.satir_tutar>0
                               AND x.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months') c ON true
        WHERE m.tenant_id=$1 AND m.kategori_kirilimi IS NOT NULL AND m.kategori_kirilimi <> '{}'::jsonb
          AND NOT (m.kategori_kirilimi ? $2)
        ORDER BY ciro_12 DESC NULLS LAST LIMIT 200`, [T, ref])).rows;
  } else if (tip === "kohort" && ref) {
    rows = (await query(
      `SELECT musteri_kodu, musteri_adi AS firma, sehir AS il,
              round(COALESCE(toplam_ciro,0))::bigint AS ciro_12, son_fatura AS son_ziyaret
         FROM master_musteri WHERE tenant_id=$1 AND extract(year from ilk_fatura)::int = $2::int
        ORDER BY ciro_12 DESC NULLS LAST LIMIT 200`, [T, ref])).rows;
  } else if (tip) {
    let clause, params = [T];
    if (tip === "sube")       { params.push(ref); clause = "f.sube = $2"; }
    else if (tip === "bolge") { params.push(ref); clause = "f.sehir = $2"; }
    else if (tip === "marka") { params.push(ref); clause = "f.marka = $2"; }
    else if (tip === "sektor") {
      clause = ref === "TBR" ? "f.satis_kanali='TBR SATIŞ'"
             : ref === "OTR" ? "f.satis_kanali='OTR SATIŞ'"
             : ref === "FILO" ? "f.satis_kanali LIKE '%FİLO%'"
             : "(f.satis_kanali LIKE 'MAĞAZA%' OR f.satis_kanali LIKE 'LASTİK SERVİS%' OR f.satis_kanali='TÜKETİCİ ÜRÜNLER SATIŞ' OR f.satis_kanali LIKE 'E-TİCARET%')";
    } else { sendJson(response, 200, { tip, ref, toplam: 0, liste: [] }); return; }
    rows = (await query(
      `SELECT mm.musteri_adi AS firma, mm.sehir AS il, t.musteri_kodu, round(t.ciro)::bigint AS ciro_12
         FROM (SELECT f.musteri_kodu, sum(f.satir_tutar) AS ciro FROM bi_satis_faturalari f
                WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
                  AND ${clause}
                GROUP BY 1 ORDER BY 2 DESC LIMIT 200) t
         LEFT JOIN master_musteri mm ON mm.tenant_id=$1 AND mm.musteri_kodu=t.musteri_kodu
        ORDER BY ciro_12 DESC NULLS LAST`, params)).rows;
  } else { sendJson(response, 200, { tip, ref, toplam: 0, liste: [] }); return; }
  const liste = rows.map(x => ({
    musteri_kodu: x.musteri_kodu, firma: x.firma || x.musteri_kodu, il: x.il || "—",
    segment: x.segment || null, ciro_12: +x.ciro_12 || 0, son_ziyaret: x.son_ziyaret || null
  }));
  sendJson(response, 200, { tip, ref, toplam: liste.length, liste });
  return;
}
