#!/usr/bin/env python3
# UMBRELLA_YOY — kokpit-umbrella'ya secilen pencerenin BIR YIL ONCESI (YoY) eklenir. ADDITIVE:
#   response'a yoy:{ciro,marj,adet} (bi_marj_atom, ayni pencere -12 ay) + canli_gy:{ciro,adet} (MTD gecen yil).
#   Mevcut alanlara DOKUNMAZ (masaustu Iki-Is yeni alani gormezden gelir). Donem toggle'inin (Faz C-frontend) beslemesi.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "UMBRELLA_YOY" in s:
    print("[skip] UMBRELLA_YOY zaten var"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# E1) params satirindan sonra: winSqlGy + yoy sorgulari
A1 = '''      const winSql = ytd ? "ay >= date_trunc('year', (SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1))" : "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - ($2 * INTERVAL '1 month'))";
      const params = ytd ? [String(T)] : [String(T), ayN];'''
E1 = A1 + r'''
      const winSqlGy = ytd ? "ay >= (date_trunc('year',(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1)) - INTERVAL '1 year') AND ay < date_trunc('year',(SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1))" : "ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - (($2 + 12) * INTERVAL '1 month')) AND ay <= ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - (12 * INTERVAL '1 month'))"; /* UMBRELLA_YOY */
      let _yoy = null, _canliGy = null;
      try {
        const _yr = (await query("SELECT round(sum(ciro)/1e6,1)::float8 ciro, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 marj, sum(adet)::int adet FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSqlGy, params)).rows[0];
        if (_yr) _yoy = { ciro: _yr.ciro, marj: _yr.marj, adet: _yr.adet };
        const _cg = (await query("SELECT round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar) FILTER (WHERE grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI'))::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND date_trunc('month',fatura_tarihi)=date_trunc('month',(CURRENT_DATE - INTERVAL '1 year')) AND fatura_tarihi <= (CURRENT_DATE - INTERVAL '1 year') AND satir_tutar>0", [String(T)])).rows[0];
        if (_cg) _canliGy = { ciro: _cg.ciro, adet: _cg.adet };
      } catch (e) { console.error("[umbrella-yoy]", e && e.message); }'''
rep(A1, E1, "yoy-sorgular")

# E2) response'a yoy + canli_gy ekle
A2 = '        ay: ytd ? "ytd" : ayN, son_ay: son_ay, sirket: sirket, canli: canli, marj_trend: marj_trend,'
rep(A2, A2 + "\n        yoy: _yoy, canli_gy: _canliGy, /* UMBRELLA_YOY */", "yoy-response")

s = s + "\n/* UMBRELLA_YOY */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] UMBRELLA_YOY — kokpit-umbrella response'a yoy{ciro,marj,adet} + canli_gy{ciro,adet} eklendi")
