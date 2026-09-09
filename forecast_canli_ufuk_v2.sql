-- Eski uretici artik bagimsiz kod degil, ufuk=1 sarmalayicisi.
-- Sebep: sampiyon defteri iki ufku birden tutuyor; ufka bakmayan uretici
-- ayni anahtardan iki satir uretiyordu. Tek tanim = tek davranis.
CREATE OR REPLACE FUNCTION bi_tahmin_canli_uret(p_hedef date DEFAULT NULL)
RETURNS TABLE(kosum_tipi text, satir_say integer) LANGUAGE plpgsql AS $fn$
BEGIN
  RETURN QUERY SELECT * FROM bi_tahmin_canli_uret_ufuk(
    COALESCE(p_hedef, date_trunc('month',CURRENT_DATE)::date), 1);
END $fn$;
