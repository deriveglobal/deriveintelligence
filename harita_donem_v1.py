#!/usr/bin/env python3
# HARITA_DONEM_V1 — metrik uclarina tarih araligi (from/to). Ust global tarih filtresiyle senkron.
#   harita-musteri-ozet + harita-il-ozet: ziyaret/teklif/satis metrikleri [from,to]'ya scope'lanir.
#   from/to yoksa: ziyaret/teklif all-time, satis all-time (defansif). Pinler DEGISMEZ.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_DONEM_V1" in s:
    print("harita-donem: already present, skip"); print("DONE."); raise SystemExit

# ── harita-musteri-ozet ──
A_oid = '      const oid = osp.get("id") || "";\n'
assert s.count(A_oid) == 1, "ozet oid anchor"
s = s.replace(A_oid, A_oid + '      const oFrom = osp.get("from") || null, oTo = osp.get("to") || null; /* HARITA_DONEM_V1 */\n', 1)

A_zi = '      const zi = (await query("SELECT COUNT(*)::int n, MAX(ziyaret_tarihi)::text son FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum=\'TAMAMLANDI\'", [session.tenantId, oid])).rows[0];\n'
assert s.count(A_zi) == 1, "ozet zi anchor"
N_zi = '      const zi = (await query("SELECT COUNT(*)::int n, MAX(ziyaret_tarihi)::text son FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum=\'TAMAMLANDI\' AND ($3::date IS NULL OR ziyaret_tarihi BETWEEN $3 AND $4)", [session.tenantId, oid, oFrom, oTo])).rows[0];\n'
s = s.replace(A_zi, N_zi, 1)

A_tk = '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif WHERE tenant_id=$1 AND musteri_id=$2", [session.tenantId, oid])).rows[0];\n'
assert s.count(A_tk) == 1, "ozet tk anchor"
N_tk = '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif WHERE tenant_id=$1 AND musteri_id=$2 AND ($3::date IS NULL OR created_at::date BETWEEN $3 AND $4)", [session.tenantId, oid, oFrom, oTo])).rows[0];\n'
s = s.replace(A_tk, N_tk, 1)

A_sr = '          const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL \'12 months\')", [session.tenantId, kod])).rows[0];\n'
assert s.count(A_sr) == 1, "ozet satis anchor"
N_sr = '          const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND musteri_kodu=$2 AND ($3::date IS NULL OR fatura_tarihi BETWEEN $3 AND $4)", [session.tenantId, kod, oFrom, oTo])).rows[0];\n'
s = s.replace(A_sr, N_sr, 1)

# ── harita-il-ozet ──
A_il = '      const il = (new URL(request.url, "http://x").searchParams.get("il") || "").trim();\n'
assert s.count(A_il) == 1, "il anchor"
s = s.replace(A_il, A_il + '      const ilSp = new URL(request.url, "http://x").searchParams; const iFrom = ilSp.get("from") || null, iTo = ilSp.get("to") || null; /* HARITA_DONEM_V1 */\n', 1)

A_izi = '      const zi = (await query("SELECT COUNT(*) FILTER (WHERE z.durum=\'TAMAMLANDI\')::int ziyaret, COUNT(DISTINCT sm.id)::int musteri FROM saha_musteri sm LEFT JOIN saha_ziyaret z ON z.musteri_id=sm.id AND z.tenant_id=sm.tenant_id WHERE sm.tenant_id=$1 AND sm.il=$2 AND sm.aktif=true", [session.tenantId, il])).rows[0];\n'
assert s.count(A_izi) == 1, "il zi anchor"
N_izi = '      const zi = (await query("SELECT COUNT(*) FILTER (WHERE z.durum=\'TAMAMLANDI\' AND ($3::date IS NULL OR z.ziyaret_tarihi BETWEEN $3 AND $4))::int ziyaret, COUNT(DISTINCT sm.id)::int musteri FROM saha_musteri sm LEFT JOIN saha_ziyaret z ON z.musteri_id=sm.id AND z.tenant_id=sm.tenant_id WHERE sm.tenant_id=$1 AND sm.il=$2 AND sm.aktif=true", [session.tenantId, il, iFrom, iTo])).rows[0];\n'
s = s.replace(A_izi, N_izi, 1)

A_itk = '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE t.durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE t.durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif t JOIN saha_musteri sm ON sm.id=t.musteri_id WHERE t.tenant_id=$1 AND sm.il=$2", [session.tenantId, il])).rows[0];\n'
assert s.count(A_itk) == 1, "il tk anchor"
N_itk = '      const tk = (await query("SELECT COUNT(*)::int toplam, COUNT(*) FILTER (WHERE t.durum=\'KAZANILDI\')::int kazan, COUNT(*) FILTER (WHERE t.durum=\'KAYBEDILDI\')::int kayip FROM saha_teklif t JOIN saha_musteri sm ON sm.id=t.musteri_id WHERE t.tenant_id=$1 AND sm.il=$2 AND ($3::date IS NULL OR t.created_at::date BETWEEN $3 AND $4)", [session.tenantId, il, iFrom, iTo])).rows[0];\n'
s = s.replace(A_itk, N_itk, 1)

A_isr = '        const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir ILIKE $2 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL \'12 months\')", [session.tenantId, il])).rows[0];\n'
assert s.count(A_isr) == 1, "il satis anchor"
N_isr = '        const sr = (await query("SELECT COALESCE(SUM(miktar),0)::numeric adet, COALESCE(SUM(satir_tutar),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND sehir ILIKE $2 AND ($3::date IS NULL OR fatura_tarihi BETWEEN $3 AND $4)", [session.tenantId, il, iFrom, iTo])).rows[0];\n'
s = s.replace(A_isr, N_isr, 1)

write(FP, s)
print("harita-donem: her iki metrik ucuna from/to eklendi")
print("marker count:", s.count("HARITA_DONEM_V1"))
print("DONE.")
