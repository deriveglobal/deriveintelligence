BEGIN;
UPDATE saha_ziyaret SET ziyaret_tarihi='2026-07-02', updated_at=now()
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND rep_id='5421b8b6-8292-47e8-b52a-94e3afed8f67'
   AND kaynak='EXCEL_MIGRASYON' AND ziyaret_tarihi='2027-07-02';
COMMIT;
