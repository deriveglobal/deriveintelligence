#!/usr/bin/env python3
"""VARDIYA_V1 — sahte vardiya defterini GERCEK kaynaga bagla.

⚠ ESKI HALI SAHTEYDI: 6 satirin 6'si da '13/07 17:32'.
   Bu bir kesif akisi degil, bi_sinyal tablosunun tek seferlik uretim damgasi.
   "AI is basinda" susu. Tam da bastan reddettigimiz sey.

✅ GERCEK KAYNAKLAR (zaman damgalari GERCEKTEN farkli):
   ops_health        — gunluk kontroller. Bu sabah 00:00:06'da kostu.
                       app.saha_5xx: 24 saatte 5 sunucu hatasi (UYARI)
                       dq.ebat_parse: 98.966 ilanin 361'inde ebat okunamadi
   bi_ingestion_log  — hangi dosya, kac satir, ne zaman, kac reddedildi
   bi_rakip_fiyat    — tarama ne zaman kostu, kac fiyat cekti

⚠ SINYAL BAYATLIGI: sinyaller BAYAT DEGIL (canli veriyle birebir uyusuyor),
   ama 2,5 saatlik ANLIK GORUNTU ve bunu SOYLEMIYORLAR.
   Cozum: gizlemek degil, "X saat once hesaplandi" YAZMAK.
"""
import re, sys, pathlib

p = pathlib.Path("server_container.mjs")
src = p.read_text(encoding="utf-8")
if "VARDIYA_V1" in src:
    sys.exit("ZATEN YAMALI")

# ── 1) Vardiya sorgusunu DEGISTIR ────────────────────────────────────────────
eski = """        // 5) VARDIYA DEFTERI — sistem ne yapti
        query(`
          SELECT olusma, tur, baslik
            FROM bi_sinyal
           WHERE tenant_id=$1::uuid AND olusma >= now() - interval '48 hours'
           ORDER BY olusma DESC LIMIT 6`, [T])"""

if eski not in src:
    # olusma sorgusu $1::text kalmis olabilir (sinyal_fix oncesi)
    eski = eski.replace("$1::uuid", "$1::text")
    if eski not in src:
        sys.exit("❌ anchor yok: vardiya sorgusu")

yeni = """        // 5) VARDIYA_V1 — ⚠ GERCEK kaynaklar. Eskisi SAHTEYDI (6 satir, ayni damga).
        query(`
          WITH kontrol AS (   -- gunluk saglik kontrolleri (ops_health)
            SELECT checked_at AS zaman,
                   CASE WHEN status='ok' THEN 'normal' ELSE 'dikkat' END AS durum,
                   title || ' — ' || COALESCE(value,'') AS metin,
                   1 AS oncelik
              FROM ops_health
             WHERE checked_at >= now() - interval '72 hours'
               AND (status <> 'ok' OR check_key IN ('dq.ebat_parse','app.errors'))),
          yukleme AS (        -- ERP yuklemeleri (bi_ingestion_log)
            SELECT processed_at AS zaman,
                   CASE WHEN status='ok' THEN 'normal' ELSE 'dikkat' END AS durum,
                   query_type || ' — ' || row_count_kept || '/' || row_count_raw || ' satır' ||
                   CASE WHEN row_count_raw > row_count_kept
                        THEN ' (' || (row_count_raw - row_count_kept) || ' reddedildi)' ELSE '' END AS metin,
                   2 AS oncelik
              FROM bi_ingestion_log
             WHERE tenant_id=$1::uuid AND processed_at >= now() - interval '72 hours'),
          tarama AS (         -- rakip fiyat taramasi
            SELECT max(scraped_at) AS zaman, 'normal' AS durum,
                   'E-ticaret taraması — ' || count(*) || ' fiyat · ' ||
                   count(DISTINCT marka) || ' marka' AS metin,
                   3 AS oncelik
              FROM bi_rakip_fiyat
             WHERE scraped_at >= now() - interval '72 hours'
             HAVING count(*) > 0)
          SELECT zaman, durum, metin FROM (
            SELECT * FROM kontrol UNION ALL
            SELECT * FROM yukleme UNION ALL
            SELECT * FROM tarama
          ) x
           WHERE zaman IS NOT NULL
           ORDER BY zaman DESC LIMIT 8`, [T])"""

src = src.replace(eski, yeni, 1)
print("  ✅ vardiya defteri -> ops_health + bi_ingestion_log + bi_rakip_fiyat")

# ── 2) Sinyal TAZELIGI dondur ────────────────────────────────────────────────
eski2 = """        kararlar : sinyaller.rows,"""
if eski2 not in src:
    sys.exit("❌ anchor yok: kararlar")
yeni2 = """        kararlar : sinyaller.rows,
        // ⚠ SINYALLER BAYAT DEGIL (canli veriyle birebir uyusuyor) ama ANLIK GORUNTU.
        //   Bayatligi GIZLEMIYORUZ — ne zaman hesaplandigini SOYLUYORUZ.
        sinyal_yasi: sinyaller.rows.length
          ? Math.round((Date.now() - new Date(sinyaller.rows[0].olusma || Date.now()).getTime())/3600000)
          : null,"""
src = src.replace(eski2, yeni2, 1)
print("  ✅ sinyal yasi (saat) donuyor")

# ── 3) olusma kolonunu sinyal sorgusuna ekle ─────────────────────────────────
eski3 = "          SELECT id, tur, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var, detay,"
if eski3 not in src:
    sys.exit("❌ anchor yok: sinyal SELECT")
src = src.replace(eski3, "          SELECT id, tur, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var, detay, olusma,", 1)
print("  ✅ olusma kolonu eklendi")

p.write_text(src, encoding="utf-8")
print("\n  ⚠ ops_health'te tenant_id YOK — platform seviyesi. Filtre uygulanmadi.")
