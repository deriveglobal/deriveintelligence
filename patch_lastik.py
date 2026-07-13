#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# LASTIK_FILTRE_V1
#
# TAM ciro yuklendi (29.186 satir, Haziran 121,76M ✅ Fatih Bilen'in rakami).
# AMA artik tabloda 19.115 LASTIK DISI satir var (17.000'i VERILEN SERVIS HIZMET).
# Bunlarin ebat'i BOS, markasi 'İŞÇİLİK'.
#
# OLCULEN HASAR (filtresiz GROUP BY marka):
#     İŞÇİLİK      16.996 satir   ← KRB'nin "en cok satan markasi"
#     CONTINENTAL   2.263
#     ebat=(BOS)   19.141 satir   ← "en cok satan ebat"
#
# KURAL: ciro/musteri/DSO sorgulari TUM satirlari saymali (dogru davranis).
#        marka/ebat/urun sorgulari SADECE lastik saymali.
# Zaten kategori IN ('YAZ','KIS',...) ile filtreli olanlara DOKUNULMUYOR --
# servis satirlari o kategorilere zaten girmiyor.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: %d bulundu (%d bekleniyordu)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

L = "\n          AND grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1"

# ── 1) EN KRITIK: urun master. Servis kalemleri URUN olarak kaydoluyordu.
rep("""    FROM bi_satis_faturalari f
    WHERE f.kalem_kodu IS NOT NULL
    GROUP BY f.tenant_id, f.kalem_kodu""",
"""    FROM bi_satis_faturalari f
    WHERE f.kalem_kodu IS NOT NULL
      AND f.grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1: İŞÇİLİK/YEDEK PARCA urun degil
    GROUP BY f.tenant_id, f.kalem_kodu""",
    "urun-master (26542)")

# ── 2) top_brands — 'İŞÇİLİK' 1 numarali marka gorunuyordu
rep("""      SELECT marka, SUM(miktar) AS adet, SUM(satir_tutar) AS tutar
      FROM bi_satis_faturalari
      WHERE tenant_id = $1 AND fatura_tarihi >= now() - interval '30 days'
      GROUP BY marka ORDER BY tutar DESC LIMIT 10""",
"""      SELECT marka, SUM(miktar) AS adet, SUM(satir_tutar) AS tutar
      FROM bi_satis_faturalari
      WHERE tenant_id = $1 AND fatura_tarihi >= now() - interval '30 days'
        AND grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1
      GROUP BY marka ORDER BY tutar DESC LIMIT 10""",
    "top_brands (22154)")

# ── 3) DISTINCT ebat — bos ebat listeye giriyordu
rep("""      SELECT DISTINCT ebat
      FROM bi_satis_faturalari
      WHERE tenant_id = $1::text""",
"""      SELECT DISTINCT ebat
      FROM bi_satis_faturalari
      WHERE tenant_id = $1::text
        AND grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1""",
    "distinct-ebat (21060)")

# ── 4) marka bazli maliyet/marj (2 yer, ayni kalip)
rep("""        SELECT s.marka, s.miktar, lp.cost
        FROM bi_satis_faturalari s
        JOIN last_purchase lp ON lp.kalem_kodu = s.kalem_kodu
        WHERE s.tenant_id = $1::text""",
"""        SELECT s.marka, s.miktar, lp.cost
        FROM bi_satis_faturalari s
        JOIN last_purchase lp ON lp.kalem_kodu = s.kalem_kodu
        WHERE s.tenant_id = $1::text
          AND s.grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1""",
    "marka-maliyet (21165)")

rep("""        SELECT s.marka, s.ebat, lp.cost, s.miktar
        FROM bi_satis_faturalari s
        JOIN last_purchase lp ON lp.kalem_kodu = s.kalem_kodu
        WHERE s.tenant_id = $1::text""",
"""        SELECT s.marka, s.ebat, lp.cost, s.miktar
        FROM bi_satis_faturalari s
        JOIN last_purchase lp ON lp.kalem_kodu = s.kalem_kodu
        WHERE s.tenant_id = $1::text
          AND s.grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1""",
    "marka-ebat-maliyet (21536)")

# ── 5) marka performans (365g)
rep("""        FROM bi_satis_faturalari sf
        WHERE sf.tenant_id = $1::text
          AND sf.fatura_tarihi >= now() - interval '365 days'
          AND sf.marka IS NOT NULL AND sf.marka <> ''""",
"""        FROM bi_satis_faturalari sf
        WHERE sf.tenant_id = $1::text
          AND sf.fatura_tarihi >= now() - interval '365 days'
          AND sf.marka IS NOT NULL AND sf.marka <> ''
          AND sf.grup_adi LIKE 'LASTIK%'   -- LASTIK_FILTRE_V1""",
    "marka-performans (23042)")

# ── 6) AI PROMPT — asistan kendi SQL'ini yaziyor. Kural vermezsek yine bozuk yazar.
rep("""      '  Marka bazlı: SELECT marka, SUM(miktar) AS adet, SUM(satir_tutar) AS ciro FROM bi_satis_faturalari WHERE tenant_id=$1 GROUP BY marka ORDER BY ciro DESC LIMIT 10\\n' +""",
"""      '  ⚠ LASTİK KURALI: bi_satis_faturalari ARTIK TÜM ciroyu içeriyor (servis, jant, akü, yedek parça dahil).\\n' +
      '    • ciro / müşteri / tahsilat / DSO sorularında FİLTRE KOYMA — toplam ciro doğrudur.\\n' +
      '    • marka / ebat / ürün sorularında MUTLAKA:  AND grup_adi LIKE \\'LASTIK%\\'\\n' +
      '    Aksi halde \\'İŞÇİLİK\\' (16.996 satır, servis işçiliği) en çok satan MARKA, boş ebat da en çok satan EBAT görünür.\\n' +
      '    Doğrulama: Haziran 2026 toplam ciro = 121,76 M TL (GM\\'in SAP rakamıyla birebir).\\n' +
      '  Marka bazlı: SELECT marka, SUM(miktar) AS adet, SUM(satir_tutar) AS ciro FROM bi_satis_faturalari WHERE tenant_id=$1 AND grup_adi LIKE \\'LASTIK%\\' GROUP BY marka ORDER BY ciro DESC LIMIT 10\\n' +""",
    "ai-prompt-kural (24607)")

# ── 7) AI'nin ebat sablonlari
rep("""      '  bi_satis_faturalari  — ebat kolonu VAR. Filtre: WHERE ebat=\\'385/65R22.5\\'\\n' +""",
"""      '  bi_satis_faturalari  — ebat kolonu VAR. Filtre: WHERE ebat=\\'385/65R22.5\\' AND grup_adi LIKE \\'LASTIK%\\'\\n' +
      '    (grup_adi filtresi ŞART: tabloda 19.115 lastik-dışı satır var, ebat\\'ları BOŞ.)\\n' +""",
    "ai-ebat-notu (24624)")

open(fn, "w", encoding="utf-8").write(s)
print("\nWROTE %s (%d -> %d)" % (fn, o, len(s)))
