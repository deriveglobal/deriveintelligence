-- SL_INGEST_V1 — CO1 Service Layer gecelik ERP oto-besleme fingerprint (31 Tem 2026)
-- Calistir: docker exec -i krb-assessment-postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < insa_gunlugu_sl.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SL_INGEST_V1',
 'CO1 Service Layer (185.86.246.212:8090) gecelik ERP oto-besleme CANLI. sl_ingest.py (JSON-yerli yukleme) + sl_connector.py (5 rapor Basic-auth, satis EN SON) imaja eklendi (Dockerfile COPY 48-49). Gecelik cron 07:45. Ilk gercek yukleme before/after ile dogrulandi (donuk transaksiyon verisi 07-21 den 07-31 e acildi).',
 'Manuel Excel yuklemesini otomatiklestirmek (donuk ERP feed = en buyuk dis darbogaz). Motor Excel-yerli: tarih takas / sayi olcek onarimlari TEMIZ JSON-u bozardi, bu yuzden AYRI JSON-yerli yol. grupla(FIFO)+kapi+dedup+VADESI_CAP+MERGE_KORU+turet AYNEN korunur. erp_ingest.py DOKUNULMADI.',
 jsonb_build_object(
   'endpoint','185.86.246.212:8090',
   'auth','Basic KRBREPORT (sl.env 600)',
   'feed', jsonb_build_array('stok_hareket','tedarikci_faturalari','cari_bakiye','stok_anlik','satis_faturalari'),
   'disarida', jsonb_build_array('alacak_yaslandirma=15-gun-kismi-aging','tahsilat=zamanlama-alani-yok'),
   'cron','45 7 * * *',
   'marker','sl_ingest_v1',
   'dosyalar', jsonb_build_array('/app/sl_ingest.py','/app/sl_connector.py'),
   'atom_tazeleme','08:15 metrik+atom cron metrik_marj_atom_uret cagirir (cari ay haric = dogru)',
   'dedup','tarih_araligi delete-range + dogal_anahtar (15-gun cakisma cozulur)',
   'dok','claude/derive-service-layer-plan.md')
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SL_INGEST_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'sl_connector','fonksiyon',
 'CO1 Service Layer gecelik ERP oto-besleme: 5 SAP raporunu (stok_hareket, tedarikci, cari_bakiye, stok_anlik, satis) Basic-auth JSON ile ceker, sl_ingest ile yukler. Manuel Excel yuklemesinin yerini alir. aging + tahsilat henuz disarida.',
 'cron 07:45: docker exec krb-assessment python3 /app/sl_connector.py (SL_USER/SL_PASS env, sl.env 600). modlar: --probe / --dry / gercek.',
 'finans','canli','taslak',
 jsonb_build_object('endpoint','185.86.246.212:8090/api','marker','sl_ingest_v1','cron','45 7 * * *'),
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='sl_connector');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'sl_ingest','fonksiyon',
 'JSON-yerli ERP yukleme: CO1 JSON kayitlarini erp_ingest motor kolonlarina map eder (Excel onarimlari ATLANIR - temiz JSON-u bozmasin), AYNI grupla(FIFO)+kapi+dedup+VADESI_CAP+MERGE_KORU+turet kullanir. erp_ingest.py DOKUNULMADI.',
 'sl_connector cagirir: yukle_json(records, tip, tenant, alan_map). alan_map = CO1 alan adi -> motor kolon adi.',
 'finans','canli','taslak',
 jsonb_build_object('marker','sl_ingest_v1','motor','erp_ingest.py-yeniden-kullanir'),
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='sl_ingest');

SELECT 'insa_gunlugu' AS k, adim AS ad, ts::date::text AS d FROM bi_insa_gunlugu WHERE adim='SL_INGEST_V1'
UNION ALL SELECT 'yetenek', ad, durum FROM bi_yetenek WHERE ad IN ('sl_connector','sl_ingest');
