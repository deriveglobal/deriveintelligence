#!/usr/bin/env python3
# FINSCHED_FIX_V1 — scheduler'daki queryAsTenant (inner-scope, görünmez) referansını kaldır;
# doğrudan module-level query() kullan (arka planda elevated pool + açık tenant filtresi çalışıyor).
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "queryAsTenant(T, sql, params)" not in s:
    print("finsched-fix: queryAsTenant referansı yok, skip"); print("DONE."); raise SystemExit

old = ('      const T = row.t; if (!T) continue;\n'
       '      const q = (sql, params) => queryAsTenant(T, sql, params);\n'
       '      try {\n'
       '        const has = (await q(`SELECT 1 FROM bi_finansal_icgoru WHERE tenant_id::text=$1 AND gun=$2`, [T, gun])).rowCount;\n'
       '        if (has) continue;\n'
       '        await _finIcgoruGunluk(T, false, q);')
new = ('      const T = row.t; if (!T) continue;\n'
       '      try {\n'
       '        const has = (await query(`SELECT 1 FROM bi_finansal_icgoru WHERE tenant_id::text=$1 AND gun=$2`, [T, gun])).rowCount;\n'
       '        if (has) continue;\n'
       '        await _finIcgoruGunluk(T, false);')
assert s.count(old) == 1, "scheduler block anchor"
s = s.replace(old, new, 1)

write(FP, s)
print("finsched-fix: queryAsTenant kaldırıldı, query() kullanılıyor")
print("DONE.")
