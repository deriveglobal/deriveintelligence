# -*- coding: utf-8 -*-
# BAYILIK_SCOPE_FIX_V1 — KOK NEDEN: _bayilikMi/_sonAlisFiyati CEO-beyin blogu icinde
#   tanimli (28670/28685), saha teklif zenginlestirmesi (32095) o kapsami GOREMIYOR ->
#   "_bayilikMi is not defined" -> BAYILIK_V2 catch yutuyor -> TUM tekliflerde maliyet bos.
#   COZUM: saha handler'inin gordugu kapsamda (requireSahaAccess yaninda) ERISILEBILIR
#   kopyalar tanimla (_bayilikMiSaha/_sonAlisFiyatiSaha), iki cagriyi onlara cevir.
#   Ayni SQL, ayni davranis; beyin blogundaki orijinaller (brain tool icin) korunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BAYILIK_SCOPE_FIX_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

HELPERS = r'''
  // BAYILIK_SCOPE_FIX_V1 — beyin-blogundaki _bayilikMi/_sonAlisFiyati saha kapsaminda gorunmez;
  //   burada saha handler'inin gorebilecegi ESDEGER kopyalar (ayni sorgu/davranis).
  async function _bayilikMiSaha(pool, tenantId, marka) {
    if (!marka) return false;
    const r = await pool.query(
      "SELECT 1 FROM bi_fiyat_iskonto WHERE tenant_id=$1::uuid " +
      " AND upper(marka)=upper($2) AND aktif=true LIMIT 1",
      [tenantId, marka]);
    return r.rows.length > 0;
  }
  async function _sonAlisFiyatiSaha(pool, tenantId, kalemKodu) {
    if (!kalemKodu) return null;
    const r = await pool.query(
      "SELECT birim_fiyat_kdv_haric AS f, fatura_tarihi AS t, tedarikci_adi AS td, " +
      "       vade_gun AS vg, (CURRENT_DATE - fatura_tarihi)::int AS gun " +
      "  FROM bi_tedarikci_faturalari " +
      " WHERE tenant_id=$1::uuid AND kalem_kodu=$2 AND birim_fiyat_kdv_haric > 0 " +
      "   AND miktar > 0 " +
      " ORDER BY fatura_tarihi DESC LIMIT 1",
      [tenantId, kalemKodu]);
    const x = r.rows[0];
    if (!x) return null;
    const g = Number(x.gun);
    return {
      fiyat: Math.round(Number(x.f) * 100) / 100,
      tarih: x.t, tedarikci: x.td,
      vade_gun: x.vg == null ? null : Number(x.vg),
      gun_once: g,
      bayat: g > 180
    };
  }

'''
ANCHOR = 'async function requireSahaAccess(req, allowedRoles = null) {'
assert s.count(ANCHOR) == 1, "requireSahaAccess anchor count=%d" % s.count(ANCHOR)
s = s.replace(ANCHOR, HELPERS + "\n  " + ANCHOR, 1)

# cagri yerlerini saha-kapsam kopyalarina cevir
OLD1 = '(await _bayilikMi(pool, session.tenantId, k.marka))'
NEW1 = '(await _bayilikMiSaha(pool, session.tenantId, k.marka))'
assert s.count(OLD1) == 1, "call1 count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

OLD2 = '_sonAlis = await _sonAlisFiyati(pool, session.tenantId, k.kalem_kodu);'
NEW2 = '_sonAlis = await _sonAlisFiyatiSaha(pool, session.tenantId, k.kalem_kodu);'
assert s.count(OLD2) == 1, "call2 count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] BAYILIK_SCOPE_FIX_V1")
