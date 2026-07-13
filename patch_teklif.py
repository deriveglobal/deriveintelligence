#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# TEKLIF_V2 — teklif onay ekrani: GERCEK veriye dayali karar destegi.
#
# Fatih'in istedigi 5 sey:
#   1) Teklifte SATIS VADESI olsun, onaylayan gorsun.
#   2) Her kalemde o urunun MIN / MEDYAN / MAKS satis fiyati.
#   3) Her urunde AGIRLIKLI ORT. ALIS VADESI ve SATIS VADESI.
#   4) Min ve maks fiyati HANGI MUSTERI aldi.
#   5) Tum veri BU YILA ait olsun.
#
# ⚠ IKI MALIYET VAR VE IKISI DE GEREKLI (Fatih'in uyarisi):
#
#   IKAME MALIYETI  = liste fiyati - tesvikler  (mevcut 'net_maliyet')
#     -> Bu lastigi BUGUN yerine koymak kaca mal olur.
#     -> FIYATLAMA KARARININ DOGRU TEMELI BUDUR. Sattiktan sonra stogu
#        bu fiyattan yenileyecegiz. Marj buna gore hesaplanmali.
#
#   GERCEK (BATIK) MALIYET = alis faturalarindan agirlikli ort. odenen fiyat
#     -> Gecmiste ne odedik. Gerceklesen marj raporlamasi icin dogru.
#     -> Ama FIYATLAMA icin yanlis: tedarikci zam yaptiysa eski ucuz
#        maliyete gore indirim vermek yarinki marji yer.
#
#   IKISININ FARKI DA BILGIDIR: ikame >> batik ise fiyatlar artiyor demektir;
#   onaylayan bunu gormeli. Bu yuzden IKISINI DE gosteriyoruz, etiketleyerek.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


# ─────────────────────────────────────────────────────────────────────
# 1) /analiz endpoint — her kaleme GERCEK SATIS + GERCEK ALIS blogu ekle
# ─────────────────────────────────────────────────────────────────────
rep("""        const marj = (talep && _netMaliyet) ? Math.round((talep - _netMaliyet) / talep * 1000) / 10 : null;
        const _karAdet = (talep != null && _netMaliyet != null) ? Math.round(talep - _netMaliyet) : null;
        kalemler.push({ kalem_sira: k.kalem_sira, marka: k.marka, model: k.model, ebat: k.ebat, adet: k.adet, notlar: k.notlar, talep_fiyat: talep, mevcut_stok: stok, birim_maliyet: maliyet, liste_fiyati: _liste, iskonto_pct: _iskPct, net_maliyet: _netMaliyet, marj_pct: marj, kar_adet: _karAdet, fiyat_durumu: _fiyatDurumu, eticaret: eticaret, marka_araligi: marka_araligi, saha_teklifler: saha });""",
"""        const marj = (talep && _netMaliyet) ? Math.round((talep - _netMaliyet) / talep * 1000) / 10 : null;
        const _karAdet = (talep != null && _netMaliyet != null) ? Math.round(talep - _netMaliyet) : null;

        // ── TEKLIF_V2: KENDI SATIS GECMISIMIZ (bu yil) ──────────────────
        //   Fatih: "min/max/medyan satis fiyati + min ve max'i KIM aldi"
        //   Kaynak: gercek faturalar. Yil filtresi: bu yil (istegin 5. maddesi).
        let _kendi = null, _agir = null;
        try {
          if (k.ebat && k.marka) {
            const _ks = await pool.query(
              "SELECT COUNT(*)::int AS n, SUM(miktar)::numeric AS adet, " +
              "  ROUND(MIN(birim_fiyat)) AS mn, ROUND(MAX(birim_fiyat)) AS mx, " +
              "  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS med, " +
              "  (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_musteri, " +
              "  (array_agg(birim_fiyat ORDER BY birim_fiyat ASC))[1]  AS en_ucuz_fiyat, " +
              "  (array_agg(fatura_tarihi ORDER BY birim_fiyat ASC))[1] AS en_ucuz_tarih, " +
              "  (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] AS en_pahali_musteri, " +
              "  (array_agg(birim_fiyat ORDER BY birim_fiyat DESC))[1] AS en_pahali_fiyat, " +
              "  (array_agg(fatura_tarihi ORDER BY birim_fiyat DESC))[1] AS en_pahali_tarih " +
              " FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND ebat=$2 AND upper(marka)=upper($3) " +
              "   AND grup_adi LIKE 'LASTIK%' AND birim_fiyat > 0 " +
              "   AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)",
              [session.tenantId, k.ebat, k.marka]);
            const g = _ks.rows[0];
            if (g && Number(g.n) > 0) {
              _kendi = {
                satis_adedi: Number(g.n), toplam_adet: _num(g.adet),
                min: _num(g.mn), medyan: _num(g.med), max: _num(g.mx),
                en_ucuz:   { musteri: g.en_ucuz_musteri,   fiyat: _num(g.en_ucuz_fiyat),   tarih: g.en_ucuz_tarih },
                en_pahali: { musteri: g.en_pahali_musteri, fiyat: _num(g.en_pahali_fiyat), tarih: g.en_pahali_tarih },
                donem: 'bu_yil'
              };
            }
          }

          // ── AGIRLIKLI ALIS/SATIS VADESI + BATIK (gerceklesen) MALIYET ──
          //   Fatih: "her urun agirlikli ortalama alis ve satis vadesi gostersin"
          //   ⚠ Buradaki alis_fiyat = GECMISTE ODEDIGIMIZ (batik) maliyet.
          //     FIYATLAMA temeli DEGIL -- o, ikame maliyeti (liste-tesvik).
          //     Ikisi birlikte gosteriliyor; farki onaylayan yorumlar.
          if (k.kalem_kodu) {
            const _ag = await pool.query(
              "WITH sat AS ( " +
              "  SELECT SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0) AS ag_fiyat, " +
              "         SUM(miktar*(vade_tarihi - fatura_tarihi))/NULLIF(SUM(miktar),0) AS ag_vade, " +
              "         SUM(miktar) AS adet " +
              "    FROM bi_satis_faturalari " +
              "   WHERE tenant_id=$1::text AND kalem_kodu=$2 AND birim_fiyat>0 " +
              "     AND vade_tarihi IS NOT NULL " +
              "     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)), " +
              "alis AS ( " +
              "  SELECT SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0) AS ag_fiyat, " +
              "         SUM(miktar*vade_gun)/NULLIF(SUM(miktar),0) AS ag_vade, " +
              "         SUM(miktar) AS adet " +
              "    FROM bi_tedarikci_faturalari " +
              "   WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric>0 " +
              "     AND vade_gun IS NOT NULL " +
              "     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)) " +
              "SELECT ROUND(sat.ag_fiyat) AS satis_fiyat, ROUND(sat.ag_vade) AS satis_vade, sat.adet AS satis_adet, " +
              "       ROUND(alis.ag_fiyat) AS alis_fiyat, ROUND(alis.ag_vade) AS alis_vade, alis.adet AS alis_adet " +
              "  FROM sat, alis",
              [session.tenantId, k.kalem_kodu]);
            const a = _ag.rows[0];
            if (a && (a.satis_fiyat != null || a.alis_fiyat != null)) {
              const _batikMal = _num(a.alis_fiyat);   // GECMISTE odenen
              _agir = {
                alis_fiyat:  _batikMal,
                alis_vade_gun:  _num(a.alis_vade),
                alis_adet:   _num(a.alis_adet),
                satis_fiyat: _num(a.satis_fiyat),
                satis_vade_gun: _num(a.satis_vade),
                satis_adet:  _num(a.satis_adet),
                // Gerceklesen (batik) maliyete gore marj — RAPORLAMA icin
                batik_marj_pct: (talep && _batikMal)
                  ? Math.round((talep - _batikMal) / talep * 1000) / 10 : null,
                // ⚠ IKAME maliyeti (_netMaliyet) BATIK'tan ne kadar yuksek?
                //   Pozitifse tedarikci zam yapmis: eski ucuz maliyete gore
                //   indirim vermek YARINKI marji yer. Onaylayan bunu gormeli.
                ikame_batik_fark_pct: (_netMaliyet && _batikMal)
                  ? Math.round((_netMaliyet - _batikMal) / _batikMal * 1000) / 10 : null,
                donem: 'bu_yil'
              };
            }
          }
        } catch (e) { console.error('[teklif_v2] analiz:', e && e.message); }

        kalemler.push({ kalem_sira: k.kalem_sira, marka: k.marka, model: k.model, ebat: k.ebat, adet: k.adet, notlar: k.notlar, talep_fiyat: talep, mevcut_stok: stok, birim_maliyet: maliyet, liste_fiyati: _liste, iskonto_pct: _iskPct, net_maliyet: _netMaliyet, marj_pct: marj, kar_adet: _karAdet, fiyat_durumu: _fiyatDurumu, eticaret: eticaret, marka_araligi: marka_araligi, saha_teklifler: saha,
          kendi_satis: _kendi, agirlikli: _agir });""",
    "analiz-kalem")


# ─────────────────────────────────────────────────────────────────────
# 2) /analiz basligina TEKLIFIN VADESI + musterinin ERP odeme kosulu
# ─────────────────────────────────────────────────────────────────────
rep("""      const th = await pool.query("SELECT id, musteri_id, notlar, rakip_marka, rakip_fiyat FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);""",
"""      // TEKLIF_V2: teklifin vadesi + musterinin ERP'deki standart odeme kosulu
      const th = await pool.query("SELECT id, musteri_id, notlar, rakip_marka, rakip_fiyat, vade_gun, vade_turu FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);""",
    "analiz-header-vade")

rep("""      sendJson(response, 200, { teklif_id: _tid, notlar: th.rows[0].notlar, header_rakip: th.rows[0].rakip_marka ? { marka: th.rows[0].rakip_marka, fiyat: th.rows[0].rakip_fiyat != null ? Number(th.rows[0].rakip_fiyat) : null } : null, rep_rakip: rep_rakip, kalemler: kalemler });""",
"""      // TEKLIF_V2: onaylayan SATIS VADESINI gormeli (Fatih'in 1. istegi).
      //   Teklifte vade yoksa musterinin ERP'deki son odeme kosulunu gosteriyoruz
      //   ve bunun VARSAYILAN oldugunu acikca isaretliyoruz -- uydurmuyoruz.
      let _vade = null;
      try {
        const _tv = th.rows[0].vade_gun;
        if (_tv != null) {
          _vade = { gun: Number(_tv), tur: th.rows[0].vade_turu, kaynak: 'teklif' };
        } else {
          const _mk = await pool.query(
            "SELECT musteri_kodu FROM saha_musteri WHERE tenant_id=$1 AND id=$2",
            [session.tenantId, th.rows[0].musteri_id]);
          const _kod = _mk.rows[0] && _mk.rows[0].musteri_kodu;
          if (_kod) {
            const _ov = await pool.query(
              "SELECT odeme_kosulu, fatura_tarihi FROM bi_satis_faturalari " +
              " WHERE tenant_id=$1::text AND musteri_kodu=$2 AND odeme_kosulu IS NOT NULL " +
              " ORDER BY fatura_tarihi DESC LIMIT 1", [session.tenantId, _kod]);
            if (_ov.rows[0]) {
              const _t = _ov.rows[0].odeme_kosulu;
              const _g = String(_t).match(/(\\d{1,3})\\s*[Gg][üu]n/);
              _vade = { gun: _g ? parseInt(_g[1]) : (/[Pp]e[şs]in/.test(_t) ? 0 : null),
                        tur: _t, kaynak: 'musterinin_son_faturasi',
                        uyari: 'Teklifte vade girilmemiş — müşterinin ERP\\'deki son ödeme koşulu gösteriliyor.' };
            }
          }
        }
      } catch (e) { console.error('[teklif_v2] vade:', e && e.message); }

      sendJson(response, 200, { teklif_id: _tid, notlar: th.rows[0].notlar, vade: _vade, header_rakip: th.rows[0].rakip_marka ? { marka: th.rows[0].rakip_marka, fiyat: th.rows[0].rakip_fiyat != null ? Number(th.rows[0].rakip_fiyat) : null } : null, rep_rakip: rep_rakip, kalemler: kalemler });""",
    "analiz-vade-cikti")


# ─────────────────────────────────────────────────────────────────────
# 3) CEO araci bekleyen_teklifler — gercek maliyet + vadeler + kendi satis
# ─────────────────────────────────────────────────────────────────────
rep("""            " LEFT JOIN LATERAL (SELECT MIN(fiyat) AS marka_min, MAX(fiyat) AS marka_max FROM bi_rakip_fiyat_son rf WHERE rf.ebat=t.ebat AND t.rakip_marka IS NOT NULL AND lower(rf.marka)=lower(t.rakip_marka)) r3 ON true " +
            " WHERE t.tenant_id=$1 AND " + whereClause +""",
"""            " LEFT JOIN LATERAL (SELECT MIN(fiyat) AS marka_min, MAX(fiyat) AS marka_max FROM bi_rakip_fiyat_son rf WHERE rf.ebat=t.ebat AND t.rakip_marka IS NOT NULL AND lower(rf.marka)=lower(t.rakip_marka)) r3 ON true " +
            // TEKLIF_V2: kendi satis gecmisimiz (bu yil) — min/medyan/max + KIM aldi
            " LEFT JOIN LATERAL (SELECT ROUND(MIN(birim_fiyat)) AS oz_min, ROUND(MAX(birim_fiyat)) AS oz_max, " +
            "    ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) AS oz_med, COUNT(*)::int AS oz_n, " +
            "    (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1]  AS oz_ucuz_mus, " +
            "    (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] AS oz_pahali_mus " +
            "  FROM bi_satis_faturalari sf WHERE sf.tenant_id=t.tenant_id::text AND sf.ebat=t.ebat " +
            "    AND upper(sf.marka)=upper(t.marka) AND sf.birim_fiyat>0 AND sf.grup_adi LIKE 'LASTIK%' " +
            "    AND sf.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) oz ON true " +
            // TEKLIF_V2: GERCEK alis maliyeti + agirlikli vadeler (bu yil)
            " LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0)) AS ag_alis, " +
            "    ROUND(SUM(miktar*vade_gun)/NULLIF(SUM(miktar),0)) AS ag_alis_vade " +
            "  FROM bi_tedarikci_faturalari tf WHERE tf.tenant_id=t.tenant_id AND tf.kalem_kodu=t.kalem_kodu " +
            "    AND tf.birim_fiyat_kdv_haric>0 AND tf.vade_gun IS NOT NULL " +
            "    AND tf.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) al ON true " +
            " LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) AS ag_satis_vade " +
            "  FROM bi_satis_faturalari sv WHERE sv.tenant_id=t.tenant_id::text AND sv.kalem_kodu=t.kalem_kodu " +
            "    AND sv.vade_tarihi IS NOT NULL AND sv.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) sv ON true " +
            " WHERE t.tenant_id=$1 AND " + whereClause +""",
    "ceo-tool-sql")

rep("""            " t.talep_fiyat, t.birim_fiyat, t.toplam_tutar, t.mevcut_stok, " +
            " t.rakip_marka, t.rakip_fiyat, t.created_at, " +""",
"""            " t.talep_fiyat, t.birim_fiyat, t.toplam_tutar, t.mevcut_stok, " +
            " t.rakip_marka, t.rakip_fiyat, t.created_at, t.vade_gun, t.vade_turu, " +
            " oz.oz_min, oz.oz_med, oz.oz_max, oz.oz_n, oz.oz_ucuz_mus, oz.oz_pahali_mus, " +
            " al.ag_alis, al.ag_alis_vade, sv.ag_satis_vade, " +""",
    "ceo-tool-select")

rep("""            return { id: t.id, durum: t.durum, musteri: t.musteri, rep: t.rep,
              urun: [t.marka, t.ebat, t.model].filter(Boolean).join(' '), ebat: t.ebat, adet: t.adet,
              talep_fiyat: talep, birim_maliyet: maliyet, marj_pct: marj_pct, mevcut_stok: stok,""",
"""            // TEKLIF_V2: IKI MALIYET.
            //   maliyet     = IKAME (liste-tesvik) -> FIYATLAMA temeli
            //   batikMal    = alis faturalarindan gerceklesen -> raporlama
            const batikMal = t.ag_alis != null ? Number(t.ag_alis) : null;
            const batikMarj = (talep && batikMal) ? Math.round((talep - batikMal) / talep * 1000) / 10 : null;
            const ikameFark = (maliyet && batikMal) ? Math.round((maliyet - batikMal) / batikMal * 1000) / 10 : null;
            return { id: t.id, durum: t.durum, musteri: t.musteri, rep: t.rep,
              urun: [t.marka, t.ebat, t.model].filter(Boolean).join(' '), ebat: t.ebat, adet: t.adet,
              talep_fiyat: talep, birim_maliyet: maliyet, marj_pct: marj_pct, mevcut_stok: stok,
              satis_vadesi: t.vade_gun != null ? { gun: Number(t.vade_gun), tur: t.vade_turu } : null,
              ikame_maliyet: maliyet,          // liste-tesvik: BUGUN yerine koyma bedeli (FIYATLAMA TEMELI)
              ikame_marj_pct: marj_pct,        // fiyatlama karari bu marja gore verilir
              batik_maliyet: batikMal,         // gecmiste odenen (alis faturasi)
              batik_marj_pct: batikMarj,       // gerceklesen marj (raporlama)
              ikame_batik_fark_pct: ikameFark, // >0 ise tedarikci zam yapmis
              agirlikli_alis_vadesi_gun: num(t.ag_alis_vade),
              agirlikli_satis_vadesi_gun: num(t.ag_satis_vade),
              kendi_satis_bu_yil: (t.oz_n != null && Number(t.oz_n) > 0) ? {
                min: num(t.oz_min), medyan: num(t.oz_med), max: num(t.oz_max),
                satis_adedi: Number(t.oz_n),
                en_ucuz_alan: t.oz_ucuz_mus, en_pahali_alan: t.oz_pahali_mus
              } : null,""",
    "ceo-tool-map")


# ─────────────────────────────────────────────────────────────────────
# 4) CEO'ya bu yeni alanlari NASIL kullanacagini soyle
# ─────────────────────────────────────────────────────────────────────
rep("""          description: 'Onay bekleyen (ONAY_BEKLIYOR) saha tekliflerini listele. Her teklif; talep edilen fiyat, mevcut stok, birim maliyet, marj %, rakip fiyat ve müşteri/temsilci ile birlikte gelir. Sahip "onay bekleyen teklifler / bekleyen teklif var mı / teklifleri göster" dediğinde kullan.',""",
"""          description: 'Onay bekleyen (ONAY_BEKLIYOR) saha tekliflerini listele. Her teklif: talep fiyatı, stok, RAKİP fiyat, müşteri/temsilci VE (TEKLIF_V2, hepsi BU YILA ait): ' +
            '⚠ İKİ MALİYET VAR, KARIŞTIRMA: ' +
            'ikame_maliyet = liste fiyatı eksi teşvikler = bu lastiği BUGÜN yerine koyma bedeli. ' +
            'FİYATLAMA KARARININ TEMELİ BUDUR — sattıktan sonra stoğu bu fiyattan yenileyeceğiz. ' +
            'ikame_marj_pct = fiyatlama marjı; onay/ret bu marja göre verilir. ' +
            'batik_maliyet = alış faturalarından geçmişte fiilen ödediğimiz ağırlıklı ortalama. ' +
            'batik_marj_pct = gerçekleşen marj (raporlama için doğru, fiyatlama için DEĞİL). ' +
            'ikame_batik_fark_pct > 0 ise tedarikçi zam yapmış: eski ucuz maliyete bakıp indirim vermek YARINKİ marjı yer — UYAR. ' +
            'kendi_satis_bu_yil = aynı ürünü bu yıl kaça sattık: min/medyan/max + en ucuza ALAN ve en pahalıya ALAN müşteri (isim). ' +
            'agirlikli_alis_vadesi_gun / agirlikli_satis_vadesi_gun = kaç günde ödüyoruz / kaç günde tahsil ediyoruz. ' +
            'satis_vadesi = bu teklifin vadesi. ' +
            'KARAR VERİRKEN: (1) marjı İKAME maliyetine göre değerlendir. (2) Talep fiyatını kendi medyanımızla kıyasla; ' +
            'medyanın çok altındaysa sor: neden? (3) Aynı ürünü daha pahalıya alan müşteri varsa İSMİNİ SÖYLE. ' +
            '(4) Satış vadesi alış vadesinden UZUNSA nakit akışı bozulur — belirt.',""",
    "ceo-tool-desc")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
