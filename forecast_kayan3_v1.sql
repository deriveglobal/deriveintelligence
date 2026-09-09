-- Kayan 3 aylik pencere: ayni anahtar seti, donem = pencerenin SON ayi.
-- Amac: parcalarin gurultusu birbirini goturdugu icin butun, parcalarindan
-- tahmin edilebilir hale geliyor (TOPLAM aylik yoy %23,3 -> ceyreklik %13,2).
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_gerceklesen_kayan3 AS
SELECT tid, varlik_tipi, varlik_kodu, donem,
       sum(adet) OVER w AS adet,
       sum(ciro) OVER w AS ciro,
       count(*)  OVER w AS ay_say
  FROM mv_gerceklesen_aylik
WINDOW w AS (PARTITION BY tid, varlik_tipi, varlik_kodu
             ORDER BY donem ROWS BETWEEN 2 PRECEDING AND CURRENT ROW);

CREATE UNIQUE INDEX IF NOT EXISTS mv_gerceklesen_kayan3_uq
  ON mv_gerceklesen_kayan3 (tid, varlik_tipi, varlik_kodu, donem);
