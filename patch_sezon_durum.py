#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SEZON_DURUM_V1 — /api/bi/sezon/durum
#   ZINCIRIN TAMAMI TEK YANITTA:
#     siparis -> sevk -> gumruk/depo -> stok -> satis -> tahsilat -> risk
#
# ⚠ BUGUN OLCULEN GERCEKLER (kod bunlara dayaniyor):
#   • KRB kis on siparisi VERILDI: 72.170 adet
#       KRB kendi stogu    38.088  (STOK riski)
#       Mutaflar+YediOto+BarOto 34.082  (KREDI riski — musteri on satisi)
#   • Sevk BASLAMIS (Haziran): BRIDGESTONE 205/55R16 %74 gelmis,
#     MATADOR 185/65R15 %0 gelmis. AYNI SEZON, TABAN TABANA ZIT.
#   • Odeme: Brisa 1.donem -> 18 Kas + 16 Ara · 2.donem -> 22 Oca + 22 Sub
#   • Mutaflar: limit 1M · risk 47,6M · gecikmis 49,4M · siparis 21.250 adet
#
# ⚠ TALEP HESABI bi_satis_faturalari'ndan. bi_stok_hareket TALEP ICIN KULLANILMAZ
#   (iki kaynaktan talep = iki farkli dogru).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

YENI = '''
// SEZON_DURUM_V1 ═════════════════════════════════════════════════════════
// GET /api/bi/sezon/durum?sezon=KIS
//   Zincir: siparis -> sevk -> stok -> satis -> nakit -> kredi
if (request.method === "GET" && url.pathname === "/api/bi/sezon/durum") {
  try {
    const session = await requireModuleAccess(request, "intelligence");
    if (!session.tenantId) { sendJson(response, 200, {}); return; }
    const sezon = (url.searchParams.get("sezon") || "KIS").toUpperCase();
    const SY = "2026-27";

    // ── 1) EBAT BAZINDA ZINCIR
    const kalem = await query(`
      WITH kod_ebat AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
               regexp_replace(upper(ebat),'\\\\s+','','g') AS ebat, marka
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND ebat <> ''
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      siparis AS (
        SELECT upper(marka) AS marka, regexp_replace(upper(ebat),'\\\\s+','','g') AS ebat,
               SUM(adet) FILTER (WHERE alici = 'KRB')  AS krb,
               SUM(adet) FILTER (WHERE alici <> 'KRB') AS musteri,
               SUM(adet) AS toplam,
               SUM(adet) FILTER (WHERE donem = '1')    AS donem1,
               SUM(adet) FILTER (WHERE donem = '2')    AS donem2
          FROM bi_on_siparis
         WHERE tenant_id = $1::uuid AND sezon_yili = $3 AND sezon = $2
         GROUP BY 1,2
      ),
      -- ⚠ SEVK: sadece MAL_GIRISI (sevk_girisi_mi). TRANSFER TALEP DEGIL, GIRIS de degil.
      sevk AS (
        SELECT upper(ke.marka) AS marka, ke.ebat,
               SUM(h.giris) AS gelen, MAX(h.belge_tarihi) AS son_giris
          FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu = h.kalem_kodu
         WHERE h.tenant_id = $1::uuid AND h.sevk_girisi_mi AND h.lastik_mi
           AND h.belge_tarihi >= DATE '2026-06-01'
         GROUP BY 1,2
      ),
      stok AS (
        SELECT upper(ke.marka) AS marka, ke.ebat, SUM(s.adet) AS mevcut
          FROM bi_stok_anlik s JOIN kod_ebat ke ON ke.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
         GROUP BY 1,2
      ),
      -- ⚠ TALEP: bi_satis_faturalari (TEK dogru kaynak). Gecen sezon (Eki-Oca).
      gecen AS (
        SELECT upper(marka) AS marka, regexp_replace(upper(ebat),'\\\\s+','','g') AS ebat,
               SUM(miktar) AS gecen_sezon
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND grup_adi LIKE 'LASTIK%' AND miktar > 0
           AND kategori ILIKE '%' || $2 || '%' AND ebat <> ''
           AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
         GROUP BY 1,2
      )
      SELECT sp.marka, sp.ebat,
             sp.krb::int, sp.musteri::int, sp.toplam::int,
             sp.donem1::int, sp.donem2::int,
             COALESCE(sv.gelen, 0)::int              AS gelen,
             (sp.toplam - COALESCE(sv.gelen, 0))::int AS bekleyen,
             ROUND(100.0 * COALESCE(sv.gelen,0) / NULLIF(sp.toplam,0))::int AS gerceklesme_pct,
             sv.son_giris,
             COALESCE(st.mevcut, 0)::int             AS mevcut_stok,
             COALESCE(g.gecen_sezon, 0)::int         AS gecen_sezon
        FROM siparis sp
        LEFT JOIN sevk  sv ON sv.marka = sp.marka AND sv.ebat = sp.ebat
        LEFT JOIN stok  st ON st.marka = sp.marka AND st.ebat = sp.ebat
        LEFT JOIN gecen g  ON g.marka  = sp.marka AND g.ebat  = sp.ebat
       WHERE sp.toplam > 0
       ORDER BY sp.toplam DESC
       LIMIT 80`,
      [session.tenantId, sezon, SY]);

    // ── 2) OZET + NAKIT TAKVIMI
    const ozet = await query(`
      WITH son AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
          FROM bi_tedarikci_faturalari
         WHERE tenant_id = $1::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      eb AS (
        SELECT regexp_replace(upper(f.ebat),'\\\\s+','','g') AS ebat, AVG(son.m) AS maliyet
          FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
         WHERE f.tenant_id = $1::text AND f.grup_adi LIKE 'LASTIK%' AND f.ebat <> ''
         GROUP BY 1
      )
      SELECT o.tedarikci, o.donem,
             SUM(o.adet)::int AS adet,
             ROUND(SUM(o.adet * COALESCE(eb.maliyet, 0)))::bigint AS tutar,
             SUM(o.adet) FILTER (WHERE o.alici = 'KRB')::int  AS krb,
             SUM(o.adet) FILTER (WHERE o.alici <> 'KRB')::int AS musteri
        FROM bi_on_siparis o
        LEFT JOIN eb ON eb.ebat = regexp_replace(upper(o.ebat),'\\\\s+','','g')
       WHERE o.tenant_id = $1::uuid AND o.sezon_yili = $2
       GROUP BY 1,2 ORDER BY 1,2`,
      [session.tenantId, SY]);

    // ── 3) ⚠ KREDI CAKISMASI — on satis yapilan musterinin RISKI
    const kredi = await query(`
      WITH os AS (
        SELECT alici, SUM(adet)::int AS adet
          FROM bi_on_siparis
         WHERE tenant_id = $1::uuid AND sezon_yili = $2 AND alici <> 'KRB'
         GROUP BY 1
      ),
      esles AS (
        SELECT o.alici, o.adet,
               (SELECT r.kredi_limiti FROM bi_musteri_risk r
                 WHERE r.tenant_id = $1::uuid AND r.musteri_mi
                   AND upper(replace(r.muhatap_adi,'İ','I')) LIKE '%' || replace(o.alici,'_',' ') || '%'
                 ORDER BY r.toplam_risk DESC LIMIT 1) AS limit,
               (SELECT r.toplam_risk FROM bi_musteri_risk r
                 WHERE r.tenant_id = $1::uuid AND r.musteri_mi
                   AND upper(replace(r.muhatap_adi,'İ','I')) LIKE '%' || replace(o.alici,'_',' ') || '%'
                 ORDER BY r.toplam_risk DESC LIMIT 1) AS risk,
               (SELECT r.vadesi_gecmis FROM bi_musteri_risk r
                 WHERE r.tenant_id = $1::uuid AND r.musteri_mi
                   AND upper(replace(r.muhatap_adi,'İ','I')) LIKE '%' || replace(o.alici,'_',' ') || '%'
                 ORDER BY r.toplam_risk DESC LIMIT 1) AS gecikmis
          FROM os o
      )
      SELECT alici, adet, limit, risk, gecikmis FROM esles ORDER BY adet DESC`,
      [session.tenantId, SY]);

    // ── 4) SEZON PENCERESI
    const bugun = new Date();
    const ay = bugun.getMonth() + 1;

    sendJson(response, 200, {
      sezon: sezon,
      sezon_yili: SY,
      // ⚠ ODEME TAKVIMI — Brisa'nin kendi slaydindan
      odeme_takvimi: {
        brisa_1donem: "18 Kasım 2026 + 16 Aralık 2026",
        brisa_2donem: "22 Ocak 2027 + 22 Şubat 2027",
        conti: "Kasım–Aralık–Ocak (3 taksit, Fatih Bilen notu — teyit bekliyor)",
        not: "⚠ Ödeme tarihleri TAKVİME ÇAKILI, fatura tarihine bağlı değil. " +
             "Temmuz'da mal gelse bile para Kasım'a kadar çıkmıyor — stoğu tedarikçi finanse ediyor."
      },
      ozet: ozet.rows,
      kredi_cakismasi: kredi.rows,
      kalemler: kalem.rows,
      uyarilar: [
        "⚠ Müşteri ön satışı (Mutaflar/Yedi Oto/Bar Oto) KRB'nin STOK riski DEĞİL, " +
        "KREDİ riskidir. İkisini karıştırmak 72.170 adedi 'KRB fazla stok bağladı' diye okumaktır.",
        "⚠ Sevk gerçekleşmesi ebatlar arasında TABAN TABANA ZIT: bazı ebatlar %74, bazıları %0. " +
        "Bu, sipariş Excel'de sevk SAP'te olduğu için bugüne kadar görülemiyordu.",
        "⚠ Talep tahmini bi_satis_faturalari'ndan gelir. bi_stok_hareket TALEP için kullanılmaz."
      ],
      kaynaklar: {
        siparis: "bi_on_siparis (Özet Tablo ile 4/4 mutabık)",
        sevk: "bi_stok_hareket (MAL_GIRISI; TRANSFER hariç — giriş=çıkış, fark 0)",
        stok: "bi_stok_anlik (son alış maliyetiyle)",
        talep: "bi_satis_faturalari (6 yıl, Fatih Bilen'in rakamıyla mutabık)",
        risk: "bi_musteri_risk (38.604 muhatap)"
      }
    });
  } catch (error) { sendJson(response, error.statusCode || 500, { error: error.message }); }
  return;
}
'''

rep('''// ONSIPARIS_V1 ═══════════════════════════════════════════════════════════''',
    YENI + '''
// ONSIPARIS_V1 ═══════════════════════════════════════════════════════════''',
    "sezon-durum-endpoint")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
