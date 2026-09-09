-- Iki yonlu tam binom testi (kucuk-olasilik yontemi). n kucuk oldugu icin dogrudan hesap.
CREATE OR REPLACE FUNCTION bi_binom_p_iki_yonlu(n integer, k integer, p numeric)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE pm numeric[]; i integer; c numeric; s numeric := 0; esik numeric;
BEGIN
  IF n IS NULL OR k IS NULL OR n <= 0 OR k < 0 OR k > n OR p <= 0 OR p >= 1 THEN
    RETURN NULL;
  END IF;
  c  := power(1::numeric - p, n);            -- pmf(0)
  pm := ARRAY[c];
  FOR i IN 1..n LOOP
    c  := c * ((n - i + 1)::numeric / i::numeric) * (p / (1::numeric - p));
    pm := pm || c;
  END LOOP;
  esik := pm[k+1] * 1.000001;                -- kayan nokta esitligi icin kucuk tolerans
  FOR i IN 1..(n+1) LOOP
    IF pm[i] <= esik THEN s := s + pm[i]; END IF;
  END LOOP;
  RETURN least(s, 1::numeric);
END $fn$;
