# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KONTROL_CITY_SERVER — enrich /api/saha/kontrol-musteriler with a live best
# candidate + both cities, so the rep can compare locations when deciding a match.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''        `SELECT m.id, m.firma, m.il, m.ilce, m.notlar,
                (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) AS ziyaret_sayisi
           FROM saha_musteri m
          WHERE m.tenant_id=$1 AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL' AND m.aktif=true
            AND EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=$2)
          ORDER BY m.firma`,''',
'''        `SELECT m.id, m.firma, m.il, m.ilce, m.notlar,
                (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) AS ziyaret_sayisi,
                c.firma AS oneri_firma, c.il AS oneri_il,
                round(similarity(m.firma, c.firma)::numeric, 2) AS oneri_skor
           FROM saha_musteri m
           LEFT JOIN LATERAL (
             SELECT x.firma, x.il
               FROM saha_musteri x
              WHERE x.tenant_id=m.tenant_id AND x.aktif=true AND x.id<>m.id
                AND x.kayit_kaynagi<>'EXCEL_IMPORT_KONTROL'
              ORDER BY similarity(m.firma, x.firma) DESC
              LIMIT 1
           ) c ON true
          WHERE m.tenant_id=$1 AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL' AND m.aktif=true
            AND EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=$2)
          ORDER BY m.firma`,''',
    "kontrol-city-sql")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
