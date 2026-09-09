/* MANAGER_PF_LENSLER_V1 — 7 lens gerçek veri. Salt-okunur.
   GET /api/saha/manager-portfoyum/lensler?donem=...
   NEREYE: /api/saha/manager-portfoyum/ekran endpoint'inin HEMEN ÜSTÜNE (patch otomatik). */
if (method === "GET" && path === "/api/saha/manager-portfoyum/lensler") {
  const session = await requireSahaAccess(request, ["manager", "admin"]);
  const T = session.tenantId;
  let _u; try { _u = new URL(request.url, "http://x"); } catch (e) { _u = null; }
  const donem = (_u && _u.searchParams.get("donem")) || "12ay";
  const DSTART = donem === "buay" ? "date_trunc('month',CURRENT_DATE)"
              : donem === "3ay"  ? "CURRENT_DATE - INTERVAL '3 months'"
              : donem === "6ay"  ? "CURRENT_DATE - INTERVAL '6 months'"
              : donem === "ytd"  ? "date_trunc('year',CURRENT_DATE)"
              :                    "CURRENT_DATE - INTERVAL '12 months'";

  const sube = (await query(
    `SELECT sube AS ad, count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} AND COALESCE(sube,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;

  const sektor = (await query(
    `SELECT CASE WHEN satis_kanali='TBR SATIŞ' THEN 'Uzun yol (TBR)'
                 WHEN satis_kanali='OTR SATIŞ' THEN 'İnşaat/Maden (OTR)'
                 WHEN satis_kanali LIKE '%FİLO%' THEN 'Filo'
                 WHEN satis_kanali LIKE 'MAĞAZA%' OR satis_kanali LIKE 'LASTİK SERVİS%' OR satis_kanali='TÜKETİCİ ÜRÜNLER SATIŞ' OR satis_kanali LIKE 'E-TİCARET%' THEN 'Binek/Tüketici'
                 ELSE 'Diğer' END AS ad,
            count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART}
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;

  const bolge = (await query(
    `SELECT sehir AS ad, count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} AND COALESCE(sehir,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;

  const marka = (await query(
    `SELECT marka AS ad, count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART}
        AND marka NOT IN ('İŞÇİLİK','PRİM HAKEDİŞLERİ','DURAN VARLIK','ALINAN HİZMET','TÜM MARKALAR','DIGER')
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;

  const rakip = (await query(
    `SELECT m AS ad, count(*) n FROM saha_musteri sm, unnest(sm.tedarikci_markalar) m
      WHERE sm.tenant_id=$1 AND sm.aktif GROUP BY 1 ORDER BY 2 DESC LIMIT 8`, [T])).rows;

  const kohort = (await query(
    `SELECT extract(year from ilk_fatura)::int yil, count(*) kazanilan,
            count(*) FILTER (WHERE son_fatura >= CURRENT_DATE - INTERVAL '12 months') aktif
       FROM master_musteri WHERE tenant_id=$1 AND ilk_fatura >= DATE '2022-01-01'
      GROUP BY 1 ORDER BY 1`, [T])).rows;

  const urunR = (await query(
    `SELECT count(*) FILTER (WHERE NOT (kategori_kirilimi ? 'MOTOR YAGLARI')) yag_yok,
            count(*) FILTER (WHERE NOT (kategori_kirilimi ? 'AKU')) aku_yok,
            count(*) toplam
       FROM master_musteri WHERE tenant_id=$1 AND kategori_kirilimi IS NOT NULL AND kategori_kirilimi <> '{}'::jsonb`, [T])).rows[0] || {};

  const konsR = (await query(
    `WITH c AS (SELECT musteri_kodu, sum(satir_tutar) v FROM bi_satis_faturalari
                 WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} GROUP BY 1),
     r AS (SELECT v, sum(v) OVER (ORDER BY v DESC) run, sum(v) OVER () tot, row_number() OVER (ORDER BY v DESC) rn FROM c)
     SELECT (SELECT count(*) FROM c) toplam_hesap,
            min(rn) FILTER (WHERE run >= 0.8*tot) hesap_80,
            round(100.0*max(v)/NULLIF(max(tot),0))::int en_buyuk_pct FROM r`, [T])).rows[0] || {};

  const num = v => v == null ? null : Number(v);
  sendJson(response, 200, {
    donem,
    sube:   sube.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),
    sektor: sektor.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),
    bolge:  bolge.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),
    marka:  marka.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),
    rakip:  rakip.map(x => ({ ad: x.ad, n: +x.n || 0 })),
    kohort: kohort.map(x => ({ yil: +x.yil, kazanilan: +x.kazanilan || 0, aktif: +x.aktif || 0,
                              pct: x.kazanilan ? Math.round(100 * x.aktif / x.kazanilan) : 0 })),
    urun:   { yag_yok: num(urunR.yag_yok), aku_yok: num(urunR.aku_yok), toplam: num(urunR.toplam) },
    konsantr: { toplam_hesap: num(konsR.toplam_hesap), hesap_80: num(konsR.hesap_80), en_buyuk_pct: num(konsR.en_buyuk_pct) }
  });
  return;
}
