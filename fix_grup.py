#!/usr/bin/env python3
# GRUP_FIX_V1 — gecikmiş alacaktan TEDARİKÇİ grubunu (Continental/TEVZİ gibi) ve bakiyesiz phantom'ları
# çıkar. Yetkili sinyal: grup (kod öneki değil). Müşteri overdue = grup!=TEDARİKÇİ AND hesap_bakiyesi>0,
# üstüne mahsup (bi_cari_bakiye). etki (KPI), koken.top (kim), by_vade düzeltilir. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "GRUP_FIX_V1" in s:
    print("grup: already present, skip"); print("DONE."); raise SystemExit

# (A) br risk CTE: grup ekle
a = ('      risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, GREATEST(vadesi_gecmis,0) vg, musteri_mi\n'
     '        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), /* FINNET_FIX_V1 */')
n = ('      risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),\'\'),\'\') grup\n'
     '        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), /* GRUP_FIX_V1 */')
assert s.count(a) == 1, "br risk anchor"; s = s.replace(a, n, 1)

# (B) br j WHERE: TEDARİKÇİ hariç + gerçek bakiye
a = "      j AS (SELECT r.hesap_bakiyesi, r.vg, COALESCE(cb.borc,0) borc FROM risk r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.musteri_mi),"
n = "      j AS (SELECT r.hesap_bakiyesi, r.vg, COALESCE(cb.borc,0) borc FROM risk r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND GREATEST(r.hesap_bakiyesi,0) > 0),"
assert s.count(a) == 1, "br j anchor"; s = s.replace(a, n, 1)

# (C) _topRows r CTE: grup + bak ekle
a = ('  const _topRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, satis_calisani, odeme_kosulu,\n'
     '              GREATEST(vadesi_gecmis,0) vg, musteri_mi\n'
     '            FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),')
n = ('  const _topRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, satis_calisani, odeme_kosulu,\n'
     '              GREATEST(vadesi_gecmis,0) vg, musteri_mi, GREATEST(hesap_bakiyesi,0) bak, COALESCE(NULLIF(TRIM(grup),\'\'),\'\') grup\n'
     '            FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),')
assert s.count(a) == 1, "topRows r anchor"; s = s.replace(a, n, 1)

# (C2) _topRows WHERE: filtre
a = "      WHERE r.musteri_mi AND GREATEST(r.vg+COALESCE(cb.borc,0),0)>0 ORDER BY net DESC LIMIT 12`, [T])).rows;"
n = "      WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND r.bak>0 AND GREATEST(r.vg+COALESCE(cb.borc,0),0)>0 ORDER BY net DESC LIMIT 12`, [T])).rows;"
assert s.count(a) == 1, "topRows where anchor"; s = s.replace(a, n, 1)

# (E) _vadeRows r CTE: grup + bak ekle
a = ('  const _vadeRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(odeme_kosulu),\'\'),\'—\') vade,\n'
     '          GREATEST(vadesi_gecmis,0) vg, musteri_mi\n'
     '        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),')
n = ('  const _vadeRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(odeme_kosulu),\'\'),\'—\') vade,\n'
     '          GREATEST(vadesi_gecmis,0) vg, musteri_mi, GREATEST(hesap_bakiyesi,0) bak, COALESCE(NULLIF(TRIM(grup),\'\'),\'\') grup\n'
     '        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),')
assert s.count(a) == 1, "vadeRows r anchor"; s = s.replace(a, n, 1)

# (E2) _vadeRows WHERE: filtre
a = "      WHERE r.musteri_mi GROUP BY r.vade HAVING SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))>0 ORDER BY tut DESC LIMIT 8`, [T])).rows;"
n = "      WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND r.bak>0 GROUP BY r.vade HAVING SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))>0 ORDER BY tut DESC LIMIT 8`, [T])).rows;"
assert s.count(a) == 1, "vadeRows where anchor"; s = s.replace(a, n, 1)

# (F) prompt: tedarikçi hariç notu
a = "etki.overdue=net, etki.overdue_brut=brüt, etki.mahsup=fark."
n = "etki.overdue=net, etki.overdue_brut=brüt, etki.mahsup=fark. TEDARİKÇİ grubundaki muhataplar (ör. Continental/TEVZİ) MÜŞTERİ DEĞİLDİR ve gecikmiş alacaktan hariç tutulmuştur — onları müşteri riski gibi anma."
assert s.count(a) == 1, "prompt anchor"; s = s.replace(a, n, 1)

write(FP, s)
print("grup: TEDARİKÇİ + bakiyesiz phantom hariç (br + topRows + vadeRows + prompt)")
print("DONE.")
