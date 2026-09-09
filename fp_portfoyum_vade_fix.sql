-- FINGERPRINT — PORTFOYUM_VADE_FIX_V1 (vade regex JS-kaçış bug düzeltmesi)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'PORTFOYUM_VADE_FIX_V1',
       'Ağırlıklı vade regex düzeltildi: JS template içinde (\d+)\s*[Gg]ün → \d/\s düşüyordu → vade hep 0; backslash''sız POSIX ([0-9]+[[:space:]]*[Gg]ün) ile çözüldü',
       'odeme_kosulu ''30/60/90 Gün Vade'' etiketleri okunamıyordu → müşteri kartı satılan vade 0 görünüyordu',
       '{"dosya":"server_container.mjs","alan":"agirlikli_vade","tum_occurrences":true,"marker":"PORTFOYUM_VADE_FIX_V1"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_VADE_FIX_V1');
SELECT (regexp_match('30 Gün Vade','([0-9]+)[[:space:]]*[Gg]ün'))[1] AS test_30, adim FROM bi_insa_gunlugu WHERE adim='PORTFOYUM_VADE_FIX_V1';
