# -*- coding: utf-8 -*-
# ZIYARET_GORDUM_BILDIRIM_V1 — Bir ziyaret detayi acilinca ("gordum") o ziyarete ait
#   OKUNMAMIS bildirim (bi_bildirim: tip='ziyaret', data->>'id'=ziyaret_id) OKUNDU
#   isaretlenmiyordu -> zil/bildirim kutusunda ziyaret hep "okunmamis" kaliyordu.
#   Cozum: /gordum endpoint'inde saha_ziyaret_gorulme insert'inden hemen sonra,
#   bu kullanicinin bu ziyarete ait okunmamis bildirimlerini okundu yap.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "ZIYARET_GORDUM_BILDIRIM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCHOR = '      } catch (e) { console.error("[ziyaret gordum]", e && e.message); }'
INSERT = '''      } catch (e) { console.error("[ziyaret gordum]", e && e.message); }
      try {  /* ZIYARET_GORDUM_BILDIRIM_V1: bu ziyaretin okunmamis bildirimini de okundu isaretle */
        await query(`UPDATE bi_bildirim SET okundu=true WHERE tenant_id=$1 AND user_id=$2 AND okundu=false AND tip='ziyaret' AND data->>'id'=$3`,
          [session.tenantId, session.userId, m[1]]);
      } catch (e) { console.error("[ziyaret gordum bildirim]", e && e.message); }'''
assert s.count(ANCHOR) == 1, "anchor count=%d" % s.count(ANCHOR)
s = s.replace(ANCHOR, INSERT, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] ZIYARET_GORDUM_BILDIRIM_V1")
