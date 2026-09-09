#!/usr/bin/env python3
# UMBRELLA_SONAY — kokpit-umbrella yanitina son_ay (bi_marj_atom max ay) + canli (bu takvim ayi MTD) ekle.
#  son_ay : marj/kirilim son TAM ay (bi_marj_atom bir ay geride).
#  canli  : GERCEK takvim ayi (bugun) MTD ciro+adet, bi_satis_faturalari (grup_adi lastik), CANLI.
#          -> "Bu ay" = gercek ay; ciro/adet canli, marj/kirilim son kapali ay.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "UMBRELLA_SONAY" in s:
    print("[skip] UMBRELLA_SONAY zaten var"); sys.exit(0)

OLD1 = '      const pick = (u) => tot.find((r) => r.umb === u) || { c: 0, mj: null, adet: 0 };'
NEW1 = (
'      const _sa = (await query("SELECT to_char(max(ay),' + "'YYYY-MM'" + ') s FROM bi_marj_atom WHERE tenant_id::text=$1", [String(T)])).rows[0]; const son_ay = _sa ? _sa.s : null; /* UMBRELLA_SONAY */\n'
'      const _cl = (await query("SELECT to_char(date_trunc(' + "'month'" + ',CURRENT_DATE),' + "'YYYY-MM'" + ') ay, round(sum(satir_tutar)/1e6,1)::float8 ciro, sum(miktar)::int adet FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND grup_adi IN (' + "'LASTIK TUKETICI','LASTIK TICARI'" + ') AND date_trunc(' + "'month'" + ',fatura_tarihi)=date_trunc(' + "'month'" + ',CURRENT_DATE) AND satir_tutar>0", [String(T)])).rows[0]; const canli = (_cl && _cl.ciro != null) ? { ay: _cl.ay, ciro: _cl.ciro, adet: _cl.adet } : null;\n'
'      const pick = (u) => tot.find((r) => r.umb === u) || { c: 0, mj: null, adet: 0 };'
)

OLD2 = '        ay: ytd ? "ytd" : ayN,\n        toplam:'
NEW2 = '        ay: ytd ? "ytd" : ayN, son_ay: son_ay, canli: canli,\n        toplam:'

assert OLD1 in s, "HATA: pick satiri bulunamadi"
assert OLD2 in s, "HATA: sendJson ay satiri bulunamadi"
s = s.replace(OLD1, NEW1, 1).replace(OLD2, NEW2, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] UMBRELLA_SONAY — kokpit-umbrella artik son_ay + canli (bu ay MTD) doner")
