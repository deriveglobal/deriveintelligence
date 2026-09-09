# -*- coding: utf-8 -*-
# Slice-1 (server) — Musteri Karti bug'lari 3a + 3b:
#  ARAC_IZIN_UNIFY_V1 — /api/saha/araclarim: Izinler matrisi departments[] de arac yetkisi verir
#    (musterikart->musteri_kart, ebatkart->ebat_kart), mevcut bi_arac_yetki ile OR. Boylece matris
#    grant'i GERCEKTEN calisir (rep Ali'ye matristen verilince gorunur). manager/admin degismez.
#  MUSTERI_ARA_REP_SCOPE_V1 — /api/saha/musteri-ara: rep ise yalniz kendi musterileri (sorumlu_rep),
#    ERP cari listesi rep icin gizli. manager/admin tum musteriler (degismez). Her yerde (teklif/ziyaret dahil).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()

# ---- 3a: araclarim, departments'i onurlandir ----
if "ARAC_IZIN_UNIFY_V1" not in s:
    OLD_A = ('          araclar = g.rows.map(r => r.arac_kod);\n'
             '        } catch (e) {}\n'
             '      }\n'
             '      sendJson(response, 200, { araclar });')
    NEW_A = ('          araclar = g.rows.map(r => r.arac_kod);\n'
             '        } catch (e) {}\n'
             '        const _dep = (session.permissions && Array.isArray(session.permissions.departments)) ? session.permissions.departments : [];  /* ARAC_IZIN_UNIFY_V1 */\n'
             '        if (_dep.includes("musterikart") && !araclar.includes("musteri_kart")) araclar.push("musteri_kart");\n'
             '        if (_dep.includes("ebatkart") && !araclar.includes("ebat_kart")) araclar.push("ebat_kart");\n'
             '      }\n'
             '      sendJson(response, 200, { araclar });')
    assert s.count(OLD_A) == 1, "3a anchor bulunamadi (%d)" % s.count(OLD_A)
    s = s.replace(OLD_A, NEW_A, 1); print("[done] ARAC_IZIN_UNIFY_V1")
else:
    print("[skip] ARAC_IZIN_UNIFY_V1 zaten var")

# ---- 3b: musteri-ara rep-scope ----
if "MUSTERI_ARA_REP_SCOPE_V1" not in s:
    OLD_B = (
'      const like = `%${q}%`;\n'
'      const prefix = `${q}%`;\n'
'      const vknMi = /^\\d{10,11}$/.test(q); // 10-11 hane → vergi no araması\n'
'      const kart = await query(`\n'
'        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum, yetkili, telefon, vergi_no, tc_no\n'
'        FROM saha_musteri\n'
'        WHERE tenant_id = $1 AND aktif = true AND (firma ILIKE $2 ${vknMi ? "OR vergi_no = $4" : ""})\n'
'        ORDER BY (firma ILIKE $3) DESC, firma\n'
'        LIMIT 12\n'
'      `, vknMi ? [session.tenantId, like, prefix, q] : [session.tenantId, like, prefix]);\n'
'      const kodlar = kart.rows.map(r => r.musteri_kodu).filter(Boolean);\n'
'      const cari = await query(`\n'
'        SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro, vergi_no, tc_no\n'
'        FROM master_musteri\n'
'        WHERE tenant_id = $1 AND musteri_adi ILIKE $2\n'
'          AND NOT (musteri_kodu = ANY($4::text[]))\n'
'        ORDER BY (musteri_adi ILIKE $3) DESC, toplam_ciro DESC NULLS LAST\n'
'        LIMIT 12\n'
'      `, [session.tenantId, like, prefix, kodlar.length ? kodlar : ["__none__"]]);')
    NEW_B = (
'      const like = `%${q}%`;\n'
'      const prefix = `${q}%`;\n'
'      const vknMi = /^\\d{10,11}$/.test(q); // 10-11 hane → vergi no araması\n'
'      const isRep = session.sahaRole === "rep";  /* MUSTERI_ARA_REP_SCOPE_V1 — rep yalniz kendi musterileri (sorumlu_rep) */\n'
'      const paramsK = [session.tenantId, like, prefix];\n'
'      let condK = "firma ILIKE $2";\n'
'      if (vknMi) { paramsK.push(q); condK += ` OR vergi_no = $${paramsK.length}`; }\n'
'      let repK = "";\n'
'      if (isRep) { paramsK.push(session.userId); repK = ` AND sorumlu_rep = $${paramsK.length}`; }\n'
'      const kart = await query(`\n'
'        SELECT id, tip, firma, musteri_kodu, il, ilce, segment, durum, yetkili, telefon, vergi_no, tc_no\n'
'        FROM saha_musteri\n'
'        WHERE tenant_id = $1 AND aktif = true AND (${condK})${repK}\n'
'        ORDER BY (firma ILIKE $3) DESC, firma\n'
'        LIMIT 12\n'
'      `, paramsK);\n'
'      const kodlar = kart.rows.map(r => r.musteri_kodu).filter(Boolean);\n'
'      const cari = isRep ? { rows: [] } : await query(`\n'
'        SELECT musteri_kodu, musteri_adi, son_fatura, fatura_sayisi, toplam_ciro, vergi_no, tc_no\n'
'        FROM master_musteri\n'
'        WHERE tenant_id = $1 AND musteri_adi ILIKE $2\n'
'          AND NOT (musteri_kodu = ANY($4::text[]))\n'
'        ORDER BY (musteri_adi ILIKE $3) DESC, toplam_ciro DESC NULLS LAST\n'
'        LIMIT 12\n'
'      `, [session.tenantId, like, prefix, kodlar.length ? kodlar : ["__none__"]]);')
    assert s.count(OLD_B) == 1, "3b anchor bulunamadi (%d)" % s.count(OLD_B)
    s = s.replace(OLD_B, NEW_B, 1); print("[done] MUSTERI_ARA_REP_SCOPE_V1")
else:
    print("[skip] MUSTERI_ARA_REP_SCOPE_V1 zaten var")

open(F, "w", encoding="utf-8").write(s)
