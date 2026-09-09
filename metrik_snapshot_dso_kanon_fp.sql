-- DONGU_KANON_SNAPSHOT_V1 fingerprint. Dogrulama (marker_var=t + snapshot_dso==kanon_dso) SONRASI calistir.
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'DONGU_KANON_SNAPSHOT_V1',
 'metrik_snapshot_al Blok B ''dso'' -> v_finans_ticari_sermaye (bilanco-tabanli kanon). Eskiden ham alacak/gunluk_kredili (~120); artik tenant basina v_finans.dso HESAPLANIR (literal degil). alacak + gunluk_kredili_satis metrikleri korundu. Boylece bi_metrik_gecmis ''dso'' okuyan tum yuzeyler (kokpit vitals + trend + finansal-icgoru + finans-seri) go-forward = kanon.',
 'Dongu Faz B/2. Teshis: bi_metrik_gecmis ''dso'' OLCULEN hiz degil, BILANCO-tabanli DSO idi (kanonla ayni metrik, farkli formul: ham alacak / kredili-satis payda -> 120 vs kanon 100). Ayri lens/etiket YANLIS olurdu; dogru hamle kanona uzlastirma (Fatih onayi). Gecmis seri backfill edilemez (bi_musteri_risk tek-export) -> Tem->Agu tek seferlik formul basamagi; go-forward tek sayi.',
 '{"fonksiyon":"metrik_snapshot_al","blok":"B dso","kaynak":"v_finans_ticari_sermaye","onceki":"round(alacak/gunluk_kredili)","yeni":"round(v_finans.dso) tenant basina","etkilenen_yuzey":["kokpit vitals.dso","finans-seri trend","finansal-icgoru","kokpit trend"],"korunan":["alacak","gunluk_kredili_satis","dso-icgoru odeme (bi_tahsilat olculen)","pricing/ccc"],"marker":"DONGU_KANON_SNAPSHOT_V1","faz":"B/2","not":"gecmis seri yaklasik kalir; ar_net aylik gecmisi yok"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='DONGU_KANON_SNAPSHOT_V1');

SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='DONGU_KANON_SNAPSHOT_V1';
