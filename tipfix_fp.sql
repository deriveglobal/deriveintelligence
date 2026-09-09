\pset pager off
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'AGNOSTIK_TAKSONOMI_TIPFIX_V1',
       'HOTFIX: kategori_segment/sezon(kategori,$1::uuid) -> (kategori, tenant_id::uuid) — 26 site',
       'Regresyon: ayni $1 hem tenant_id::text=$1 hem $1::uuid -> Postgres $1=uuid -> text=uuid patladi (umbrella/kokpit). Fix: param yerine SUTUN (tenant_id::uuid); bi_satis(text)+bi_marj_atom(uuid) ikisini karsilar.',
       '{"site":26,"belirti":"operator does not exist: text = uuid (umbrella)","kural":"helper/taksonomi cagrisi tenant SUTUN, $1 param DEGIL — devir §2"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AGNOSTIK_TAKSONOMI_TIPFIX_V1');
SELECT 'AGNOSTIK_TAKSONOMI_TIPFIX_V1 kaydedildi' AS durum;
