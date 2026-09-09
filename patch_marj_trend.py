#!/usr/bin/env python3
# MARJ_TREND — kokpit-umbrella yanitina son 13 ay marj trendi ekle (toplam + tuk/tic, donem bazi).
#   marj_trend: [{ay:'YYYY-MM', marj, tuk, tic}] — bi_marj_atom son 13 ay. Shell canli Temmuz noktasini ekler.
#   Donem-bagimsiz (her cagride ayni); sparkline icin.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MARJ_TREND" in s:
    print("[skip] MARJ_TREND zaten var"); sys.exit(0)

OLD_ANCHOR = 'const wmarj = _gm ? _gm.mj : null; /* MARJ_RAW_FIX */'
NEW_ANCHOR = OLD_ANCHOR + r'''
      const _mt = (await query("SELECT to_char(ay,'YYYY-MM') ay, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 marj, round((sum(brut_kar) FILTER (WHERE kategori_segment(kategori)='PSR'))/nullif(sum(ciro) FILTER (WHERE kategori_segment(kategori)='PSR'),0)*100,1)::float8 tuk, round((sum(brut_kar) FILTER (WHERE kategori_segment(kategori)<>'PSR'))/nullif(sum(ciro) FILTER (WHERE kategori_segment(kategori)<>'PSR'),0)*100,1)::float8 tic FROM bi_marj_atom WHERE tenant_id::text=$1 AND ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=$1) - (13 * INTERVAL '1 month')) GROUP BY ay ORDER BY ay", [String(T)])).rows; /* MARJ_TREND */
      const marj_trend = _mt.map((r) => ({ ay: r.ay, marj: r.marj, tuk: r.tuk, tic: r.tic }));'''

OLD_SEND = 'ay: ytd ? "ytd" : ayN, son_ay: son_ay, sirket: sirket, canli: canli,'
NEW_SEND = 'ay: ytd ? "ytd" : ayN, son_ay: son_ay, sirket: sirket, canli: canli, marj_trend: marj_trend,'

assert OLD_ANCHOR in s, "HATA: MARJ_RAW_FIX anchor bulunamadi (sirket_ciro deploy edilmis mi?)"
assert OLD_SEND in s, "HATA: sendJson sirket/canli satiri bulunamadi"
s = s.replace(OLD_ANCHOR, NEW_ANCHOR, 1).replace(OLD_SEND, NEW_SEND, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] MARJ_TREND — kokpit-umbrella artik marj_trend (son 13 ay, tuk/tic) doner")
