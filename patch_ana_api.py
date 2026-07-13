#!/usr/bin/env python3
"""ANA_API_V1 — /api/bi/ana endpointi.

⚠ ICINDEKI HER RAKAM ana_sayfa_sql2.sh ile POSTGRES'TE DOGRULANDI:
    bagli sermaye 507,3M · stok 268,5M · alacak 238,8M
    stok 131 gun · GERCEK DSO 116 gun · sermaye yuku 202,9M/yil
    kor nokta: bayilik cirosunun %92'si (319,4M / 347,6M)
    serbest stok 263,2M (taahhutlu sadece 5,4M)

⚠ GERCEK DSO 116 GUN, ekrandaki 26,9 DEGIL.
   bi_fatura_tahsilat sadece TAHSIL EDILMIS faturalari tutuyor —
   145,4M odemeyen ortalamaya HIC GIRMIYOR. Hayatta kalan yanliligi.
   Dogrusu: alacak / gunluk ciro.

⚠ NOPAT / EVA HESAPLANMIYOR. Cunku marj hesaplanamiyor:
   bayilik cirosunun %92'sinin maliyeti yok (yaz+4mevsim iskontosu, TBR listesi).
   UYDURMUYORUZ. Ekranda "hesaplanamiyor" yazacak + EKSIK DOSYA LISTESI.
   Sistemin ilk soyledigi sey KENDI KORLUGU olacak.

⚠ PLANLI ODEMELER karar kuyrugundan AYRILDI. "18 Kas odemesi" bir SORUN degil,
   TAKVIM. Ilk 6 sinyalin 4'u bunlardi, gercek kararlari asagi itiyorlardi.
"""
import re, sys, pathlib

p = pathlib.Path("server_container.mjs")
src = p.read_text(encoding="utf-8")
if "ANA_API_V1" in src:
    sys.exit("ZATEN YAMALI")

ENDPOINT = r'''
  // ── ANA_API_V1 ────────────────────────────────────────────────────────────
  // ⚠ Her rakam Postgres'te dogrulandi. Uydurma sayi YOK.
  // ⚠ EVA/NOPAT DONMUYOR — bayilik cirosunun %92'sinin maliyeti yok.
  //   "Hesaplanamiyor" + eksik dosya listesi donuyor. Sistem korlugunu ILAN EDIYOR.
  if (request.method === 'GET' && url.pathname === '/api/bi/ana') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const T = session.tenantId;

      const [sermaye, kor, sinyaller, odemeler, vardiya] = await Promise.all([
        // 1) BAGLI SERMAYE + GERCEK NAKIT DONGUSU
        query(`
          WITH sa AS (
            SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
                   bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat
              FROM bi_tedarikci_faturalari
             WHERE tenant_id=$1::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
             ORDER BY 1, fatura_tarihi DESC),
          stok AS (
            SELECT COALESCE(sum(st.adet*sa.fiyat),0)           AS deger,
                   COALESCE(sum(st.taahhut*sa.fiyat),0)        AS taahhutlu,
                   COALESCE(sum(st.kullanilabilir*sa.fiyat),0) AS serbest,
                   COALESCE(sum(st.adet),0)                     AS adet
              FROM bi_stok_anlik st
              LEFT JOIN sa ON sa.sku=bi_sku_norm(st.kalem_kodu)
             WHERE st.tenant_id=$1::uuid AND st.adet>0),
          alacak AS (
            SELECT COALESCE(sum(toplam_risk),0)    AS risk,
                   COALESCE(sum(vadesi_gecmis),0)  AS gecikmis,
                   count(*) FILTER (WHERE vadesi_gecmis>0)  AS gecikmis_musteri,
                   count(*) FILTER (WHERE limit_asimi>0)    AS limit_asan
              FROM bi_musteri_risk
             WHERE tenant_id=$1::uuid AND COALESCE(musteri_mi,true)),
          ciro AS (
            SELECT COALESCE(sum(satir_tutar),0)/365.0 AS gunluk
              FROM bi_satis_faturalari
             WHERE tenant_id=$1::text AND miktar>0 AND ebat IS NOT NULL
               AND fatura_tarihi >= CURRENT_DATE-365)
          SELECT s.deger AS stok, s.taahhutlu, s.serbest, s.adet,
                 a.risk AS alacak, a.gecikmis, a.gecikmis_musteri, a.limit_asan,
                 c.gunluk AS gunluk_ciro,
                 (s.deger + a.risk)                                  AS bagli_sermaye,
                 ROUND(s.deger  / NULLIF(c.gunluk,0))                AS stok_gun,
                 -- ⚠ GERCEK DSO: tahsil EDILMEYENI de icerir. Tablo 26,9 diyordu; yalan.
                 ROUND(a.risk   / NULLIF(c.gunluk,0))                AS dso_gun,
                 ROUND((s.deger + a.risk) * 0.40)                    AS sermaye_yuku
            FROM stok s, alacak a, ciro c`, [T]),

        // 2) ⚠ KOR NOKTA — SADECE bayilik markalarinda anlamli.
        //    Net-fiyat markalarinin maliyeti son alistir ve DOGRUDUR.
        query(`
          WITH isk AS (SELECT DISTINCT upper(marka) marka, sezon
                         FROM bi_fiyat_iskonto WHERE tenant_id=$1::uuid AND aktif),
               lst AS (SELECT DISTINCT upper(marka) marka, kategori
                         FROM bi_fiyat_listesi_uploads WHERE tenant_id=$1::uuid AND aktif),
               s AS (SELECT f.kategori, upper(f.marka) AS marka, sum(f.satir_tutar) AS ciro
                       FROM bi_satis_faturalari f
                      WHERE f.tenant_id=$1::text AND f.miktar>0 AND f.ebat IS NOT NULL
                        AND f.fatura_tarihi >= CURRENT_DATE-365
                        AND upper(f.marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')
                        AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')
                        AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%'
                      GROUP BY 1,2)
          SELECT s.kategori,
                 ROUND(sum(s.ciro)) AS ciro,
                 bool_or(i.marka IS NOT NULL) AS iskonto_var,
                 bool_or(l.marka IS NOT NULL) AS liste_var
            FROM s
            LEFT JOIN isk i ON i.marka=s.marka AND i.sezon=s.kategori
            LEFT JOIN lst l ON l.marka=s.marka AND l.kategori=s.kategori
           GROUP BY 1 ORDER BY 2 DESC`, [T]),

        // 3) KARAR KUYRUGU — ⚠ planli odemeler HARIC, susturulmus HARIC
        query(`
          SELECT id, tur, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var, detay,
                 bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS puan,
                 bi_sinyal_puan_detay(tutar_tl, son_tarih, eylem_var) AS puan_detay
            FROM bi_sinyal
           WHERE tenant_id=$1::text AND durum='acik' AND tur <> 'odeme'
           ORDER BY puan DESC LIMIT 6`, [T]),

        // 4) ⚠ BILGI (karar degil) — Brisa odeme takvimi
        query(`
          SELECT count(*)::int AS adet, COALESCE(sum(tutar_tl),0) AS toplam,
                 min(son_tarih) AS en_yakin
            FROM bi_sinyal
           WHERE tenant_id=$1::text AND durum='acik' AND tur='odeme'`, [T]),

        // 5) VARDIYA DEFTERI — sistem ne yapti
        query(`
          SELECT olusma, tur, baslik
            FROM bi_sinyal
           WHERE tenant_id=$1::text AND olusma >= now() - interval '48 hours'
           ORDER BY olusma DESC LIMIT 6`, [T])
      ]);

      const s  = sermaye.rows[0] || {};
      const kk = kor.rows;
      const korCiro   = kk.filter(r => !r.iskonto_var).reduce((a,r) => a + Number(r.ciro||0), 0);
      const toplamCiro= kk.reduce((a,r) => a + Number(r.ciro||0), 0);

      // ⚠ EKSIK DOSYALAR — sikayet degil, YAPILACAK IS.
      const eksik = kk.filter(r => !r.iskonto_var).map(r => ({
        kategori : r.kategori,
        ciro     : Number(r.ciro||0),
        neEksik  : r.liste_var ? 'iskonto' : 'liste + iskonto'
      }));

      sendJson(response, 200, {
        sermaye: {
          bagli        : Number(s.bagli_sermaye||0),
          stok         : Number(s.stok||0),
          stok_serbest : Number(s.serbest||0),
          stok_taahhut : Number(s.taahhutlu||0),
          alacak       : Number(s.alacak||0),
          gecikmis     : Number(s.gecikmis||0),
          gecikmis_musteri: Number(s.gecikmis_musteri||0),
          limit_asan   : Number(s.limit_asan||0),
          stok_gun     : Number(s.stok_gun||0),
          dso_gun      : Number(s.dso_gun||0),
          yillik_yuk   : Number(s.sermaye_yuku||0),
          // ⚠ SEFFAFLIK: her sayi kaynagini soylesin. Kullanici itiraz edebilmeli.
          kaynak: {
            stok   : 'bi_stok_anlik × son alış (bi_tedarikci_faturalari)',
            alacak : 'bi_musteri_risk.toplam_risk',
            dso    : 'alacak ÷ günlük ciro — tahsil EDİLMEYENİ de içerir',
            dso_not: '⚠ Tahsilat tablosundaki 26,9 gün SADECE ödeyenleri ölçüyor. 145,4M ödemeyen o ortalamada yok.',
            oran   : 'sermaye maliyeti %40/yıl'
          }
        },
        // ⚠ KARLILIK HESAPLANMIYOR. Uydurmuyoruz.
        karlilik: {
          hesaplanabilir : korCiro === 0,
          kor_ciro       : korCiro,
          toplam_ciro    : toplamCiro,
          kor_pct        : toplamCiro ? Math.round(100*korCiro/toplamCiro) : null,
          eksik          : eksik,
          aciklama       : 'Bayilik markalarının maliyeti liste × (1−iskonto kaskadı) ile hesaplanır. İskonto kademesi olmayan kategoride maliyet bilinmiyor — marj uydurulmuyor.'
        },
        kararlar : sinyaller.rows,
        bilgi    : odemeler.rows[0] || {},
        vardiya  : vardiya.rows
      });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }
'''

# ⚠ ANCHOR: mevcut bir /api/bi/ endpointinden ONCE. Taze grep'ten, ezberden DEGIL.
anchors = [
    (r"\n\s*//\s*GET /api/bi/pricing/ccc", "pricing/ccc yorumu"),
    (r"\n\s*if \(request\.method === 'GET' && url\.pathname === '/api/bi/pricing/ccc'\)", "pricing/ccc if"),
    (r"\n\s*if \(request\.method === 'GET' && url\.pathname === '/api/bi/sezon/durum'\)", "sezon/durum if"),
]
for pat, ad in anchors:
    m = re.search(pat, src)
    if m:
        i = m.start()
        src = src[:i] + "\n" + ENDPOINT + src[i:]
        print(f"  endpoint eklendi → {ad} oncesi (offset {i})")
        break
else:
    sys.exit("❌ HICBIR ANCHOR TUTMADI — yama iptal, dosyaya dokunulmadi.")

p.write_text(src, encoding="utf-8")
print("  ✅ /api/bi/ana yazildi")
