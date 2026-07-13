#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ONSIPARIS_V3 — YENI SKU'LAR KOR NOKTAYDI. UC KADEMELI EBAT COZUMU.
#
# ⚠ V2'DE KALAN ACIK (olculdu):
#   Kis stogunun 252 adedi (46 SKU, %5,8) satis tablosunda HIC GECMIYOR
#   -> ebat eslesmiyor -> o ebatlarda "mevcut stok" OLDUGUNDAN AZ gorunuyor
#   -> "eksik" OLDUGUNDAN FAZLA -> FAZLA SIPARIS onerilir.
#
#   VE ESLESMEYENLER TAM OLARAK SUNLAR:
#     BRIDGESTONE BLIZZAK 6 · LASSA SNOWAYS 4 · LASSA WINTUS 2 · BRIDGESTONE LM32
#   = BRISA DONUSUYLE GELEN YEPYENI KIS URUNLERI.
#   Henuz satilmadiklari icin satis tablosunda yoklar.
#   VE TAM OLARAK BU KIS ON SIPARIS VERECEGIMIZ URUNLER.
#   Bugun %5,8; Brisa sevkiyat yaptikca BUYUR. Model kendi hedef kitlesinde KOR KALIR.
#
# ⚠ V2'nin regex'i neden basarisizdi:
#   '^([0-9]+[/.][0-9]*[A-Z]*R?[0-9.]+C?)' — TICARI ebatlarda (185R14C) BOS donuyordu.
#   Cunku kalip '/' bekliyordu; 185R14C'de '/' YOK.
#
# ✅ COZUM — URUN ADININ ILK KELIMESI ZATEN EBAT:
#     "245/40R18 97V BLIZZAK 6 M+S"     -> 245/40R18
#     "185R14C 102/100R WINTUS 2"       -> 185R14C
#     "195/65R16C 104/102R WINTUS 2"    -> 195/65R16C
#     "12.00R24 VCHSZ IDU TCF"          -> 12.00R24
#   Karmasik kalip kurmaya gerek YOK. Ilk bosluga kadar al.
#
# UC KADEME (ve hangisinin kullanildigi EKRANDA yaziyor):
#   1) satis tablosu   — ERP'nin KENDI 'ebat' alani. EN GUVENILIR.
#   2) bi_urun_master  — urun master (varsa)
#   3) ilk kelime      — kalem_tanimi'ndan turetilmis. 'turetilmis' diye ETIKETLI.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)


rep("""      kod_ebat AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND ebat IS NOT NULL AND ebat <> ''
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      stok AS (
        SELECT ke.ebat AS ebat,
               SUM(s.adet) AS mevcut,
               SUM(s.adet * m.maliyet) / NULLIF(SUM(s.adet) FILTER (WHERE m.maliyet IS NOT NULL), 0) AS birim_maliyet,
               SUM(s.adet) FILTER (WHERE m.maliyet IS NULL) AS maliyetsiz_adet
          FROM bi_stok_anlik s
          JOIN kod_ebat ke      ON ke.kalem_kodu = s.kalem_kodu
          LEFT JOIN son_maliyet m ON m.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0 AND s.sezon ILIKE $2
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
         GROUP BY 1
      ),""",
"""      -- ONSIPARIS_V3 — KADEME 1: satis tablosu (ERP'nin KENDI alani)
      kod_ebat AS (
        SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat
          FROM bi_satis_faturalari
         WHERE tenant_id = $1::text AND ebat IS NOT NULL AND ebat <> ''
         ORDER BY kalem_kodu, fatura_tarihi DESC
      ),
      -- ⚠ KADEME 3: urun adinin ILK KELIMESI zaten ebattir.
      --   "245/40R18 97V BLIZZAK 6"  -> 245/40R18
      --   "185R14C 102/100R WINTUS"  -> 185R14C   (V2'nin regex'i BUNU KACIRIYORDU)
      --   Yeni SKU'lar (Brisa donusu: BLIZZAK 6, SNOWAYS 4, WINTUS 2) satista
      --   henuz gecmedigi icin KADEME 1 onlari bulamiyor. Kor nokta buydu.
      stok_ebat AS (
        SELECT s.kalem_kodu, s.adet,
               COALESCE(ke.ebat, substring(s.kalem_tanimi from '^([^ ]+)')) AS ebat,
               CASE WHEN ke.ebat IS NOT NULL THEN 'erp' ELSE 'turetilmis' END AS ebat_kaynagi
          FROM bi_stok_anlik s
          LEFT JOIN kod_ebat ke ON ke.kalem_kodu = s.kalem_kodu
         WHERE s.tenant_id = $1::uuid AND s.adet > 0 AND s.sezon ILIKE $2
           AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id = $1::uuid)
      ),
      stok AS (
        SELECT se.ebat AS ebat,
               SUM(se.adet) AS mevcut,
               SUM(se.adet * m.maliyet) / NULLIF(SUM(se.adet) FILTER (WHERE m.maliyet IS NOT NULL), 0) AS birim_maliyet,
               SUM(se.adet) FILTER (WHERE m.maliyet IS NULL) AS maliyetsiz_adet,
               SUM(se.adet) FILTER (WHERE se.ebat_kaynagi = 'turetilmis') AS turetilmis_adet
          FROM stok_ebat se
          LEFT JOIN son_maliyet m ON m.kalem_kodu = se.kalem_kodu
         WHERE se.ebat IS NOT NULL AND se.ebat <> ''
         GROUP BY 1
      ),""",
    "v3-uc-kademe")


rep("""             CASE WHEN st.birim_maliyet IS NOT NULL THEN 'stok_son_alis'
                  WHEN em.maliyet IS NOT NULL       THEN 'ebat_ortalamasi'
                  ELSE 'MALIYET_YOK' END             AS maliyet_kaynagi,
             COALESCE(st.maliyetsiz_adet, 0)           AS maliyetsiz_adet""",
"""             CASE WHEN st.birim_maliyet IS NOT NULL THEN 'stok_son_alis'
                  WHEN em.maliyet IS NOT NULL       THEN 'ebat_ortalamasi'
                  ELSE 'MALIYET_YOK' END             AS maliyet_kaynagi,
             COALESCE(st.maliyetsiz_adet, 0)           AS maliyetsiz_adet,
             -- ⚠ Bu ebattaki stogun kaci URUN ADINDAN turetildi? (yeni SKU'lar)
             COALESCE(st.turetilmis_adet, 0)           AS turetilmis_adet""",
    "v3-turetilmis-cikti")


rep("""      maliyet_kaynagi: x.maliyet_kaynagi,
      durum: Number(x.mevcut_stok) === 0 ? "yok\"""",
"""      maliyet_kaynagi: x.maliyet_kaynagi,
      // ⚠ Ebati URUN ADINDAN turetilen adet (yeni SKU — satista henuz gecmemis)
      turetilmis_adet: Number(x.turetilmis_adet || 0),
      durum: Number(x.mevcut_stok) === 0 ? "yok\"""",
    "v3-kalem-turetilmis")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
