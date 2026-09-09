-- fix_ugur_ziyaret.sql — Ugur Yildiz'a YANLIS atanan 2 EXCEL_MIGRASYON ziyaretini kaldirir.
-- KANIT: bu 2 firma Ugur'un kendi Excel'inde YOK (Lastik Market-Ekrem Tasin/SAKARYA ve
--   Unallar Oto Lastik/BARTIN); musteriler Eftal'e ait (sorumlu_rep=Eftal), Eftal 2026-07-11'de ziyaret etmis.
--   Bu 2 kayit 2026-07-04 hatali import'unda Ugur'a yapismis.
-- GUVENLI + GERI ALINABILIR: silinenler once saha_ziyaret_yedek_ugur_fix tablosuna kopyalanir.
--   Yalniz Ugur'un rep_id'si guard'lı; EFTAL/HUSEYIN verisine DOKUNULMAZ.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;

CREATE TABLE IF NOT EXISTS saha_ziyaret_yedek_ugur_fix AS SELECT * FROM saha_ziyaret WHERE 1=0;
INSERT INTO saha_ziyaret_yedek_ugur_fix
  SELECT * FROM saha_ziyaret
   WHERE id IN ('60e04c35-db7e-4f81-8df9-cf775d5ede4c','35879715-ea8e-4cb8-bbe2-584b9f7cbd6c');
\echo '-- yedeklenen satir (2 bekleniyor):'
SELECT count(*) AS yedeklenen FROM saha_ziyaret_yedek_ugur_fix;

DELETE FROM saha_ziyaret_foto    WHERE ziyaret_id IN ('60e04c35-db7e-4f81-8df9-cf775d5ede4c','35879715-ea8e-4cb8-bbe2-584b9f7cbd6c');
DELETE FROM saha_ziyaret_gorulme WHERE ziyaret_id IN ('60e04c35-db7e-4f81-8df9-cf775d5ede4c','35879715-ea8e-4cb8-bbe2-584b9f7cbd6c');

DELETE FROM saha_ziyaret
 WHERE id IN ('60e04c35-db7e-4f81-8df9-cf775d5ede4c','35879715-ea8e-4cb8-bbe2-584b9f7cbd6c')
   AND rep_id = '44ec101f-9797-407c-8a29-1d0bb1317339';

\echo '-- Ugur kalan ziyaret (0 bekleniyor):'
SELECT count(*) AS ugur_kalan FROM saha_ziyaret WHERE rep_id='44ec101f-9797-407c-8a29-1d0bb1317339';
\echo '-- Bu 2 musterideki ziyaretler (yalniz Eftal kalmali, DEGISMEDI):'
SELECT COALESCE(u.full_name,'?') AS rep, count(*) AS ziyaret
  FROM saha_ziyaret z LEFT JOIN users u ON u.id=z.rep_id
 WHERE z.musteri_id IN ('e40b57f6-d0c2-4938-8719-3d62f52fc7c7','4f44d81d-e105-4235-9fda-08ea04a5e8aa')
 GROUP BY 1;

COMMIT;
\echo '-- BITTI. GERI ALMA: INSERT INTO saha_ziyaret SELECT * FROM saha_ziyaret_yedek_ugur_fix;'
