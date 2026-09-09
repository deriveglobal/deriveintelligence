-- DONGU_KANON_ANA_V1 — deploy ONCESI (host patch sonrasi) dogrulama. PARAM'li (literal degil).
-- Endpoint'in artik okuyacagi BIREBIR alt-sorgu formu: dso_gun=100, stok_gun(dio)=146 olmali.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
PREPARE _dg(uuid) AS
  SELECT round(dso) AS dso_gun, round(dio) AS stok_gun, round(dpo) AS dpo, round(ccc) AS ccc
    FROM v_finans_ticari_sermaye WHERE tenant_id=$1;
EXECUTE _dg(:'t'::uuid);
DEALLOCATE _dg;
