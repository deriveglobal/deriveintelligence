#!/usr/bin/env bash
# RAPOR_R2B_PORTFOY — ilk kanon migrasyonu: view v2 (ritim+recency_ay eklenir) + Portfoy raporu saha_musteri_kanon'a tasinir.
#   Sayi DEGISMEZ (view = ayni hesap; saf tutarlilik/pattern). server_container.mjs + view DDL. Rollback'li.
#   KULLANIM:
#     scp -i $KEY deploy_rapor_r2b_portfoy.sh patch_rapor_r2b_portfoy_server.py $H:/opt/krb-assessment/
#     ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_rapor_r2b_portfoy.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_rapor_r2b_portfoy_server.py ] || { echo "HATA: dosya yok"; exit 1; }
# ── view v2 (ritim + recency_ay) — CREATE OR REPLACE (idempotent, salt-DDL) ──
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || { echo "HATA view DDL"; exit 1; }
\set ON_ERROR_STOP on
CREATE OR REPLACE VIEW saha_musteri_kanon AS
SELECT
  m.tenant_id, m.id AS musteri_id, m.musteri_kodu, m.firma, m.il, m.ilce,
  m.tip AS tip, to_jsonb(m)->>'segment' AS segment, m.sorumlu_rep,
  (m.musteri_kodu IS NOT NULL) AS matched,
  COALESCE(c.ciro_12ay, 0)::numeric AS ciro_12ay,
  COALESCE(v.ziyaret_12ay, 0)::int AS ziyaret_12ay,
  v.son_ziyaret,
  CASE WHEN v.son_ziyaret IS NOT NULL THEN (CURRENT_DATE - v.son_ziyaret) END AS son_ziyaret_gun,
  sg.durum AS saglik, sg.guven AS saglik_guven, sg.ritim AS ritim, sg.recency_ay AS recency_ay
FROM saha_musteri m
LEFT JOIN LATERAL (SELECT SUM(f.satir_tutar) AS ciro_12ay FROM bi_satis_faturalari f
   WHERE f.tenant_id::text=m.tenant_id::text AND f.musteri_kodu=m.musteri_kodu AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '365 days') c ON m.musteri_kodu IS NOT NULL
LEFT JOIN LATERAL (SELECT COUNT(*) FILTER (WHERE z.ziyaret_tarihi >= CURRENT_DATE - INTERVAL '365 days') AS ziyaret_12ay, MAX(z.ziyaret_tarihi) AS son_ziyaret
   FROM saha_ziyaret z WHERE z.tenant_id::text=m.tenant_id::text AND z.musteri_id=m.id AND z.durum='TAMAMLANDI') v ON true
LEFT JOIN saha_musteri_saglik sg ON sg.tenant_id::text=m.tenant_id::text AND sg.musteri_kodu=m.musteri_kodu
WHERE m.aktif=true;
SELECT 'kanon v2 (ritim/recency)' AS ddl, count(*) FILTER (WHERE ritim IS NOT NULL) ritimli FROM saha_musteri_kanon WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa';
SQL
echo "[db] view v2 hazır"
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
python3 patch_rapor_r2b_portfoy_server.py "$SRV" || { cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
cp -a "$SRV" _r2bp_esm.mjs && node --check _r2bp_esm.mjs || { echo "HATA node ESM"; rm -f _r2bp_esm.mjs; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
rm -f _r2bp_esm.mjs; echo "[ok] syntax"
docker build -t krb-assessment:secure . >/tmp/r2bp_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -25 /tmp/r2bp_build.log; cp -a "$SRV.bak.$TS" "$SRV"; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[srv] RAPOR_R2B_PORTFOY (1): ";     docker exec "$CID" grep -c RAPOR_R2B_PORTFOY /app/server.mjs || true
echo -n "[srv] portfoy kanon view (1): ";    docker exec "$CID" grep -c 'FROM saha_musteri_kanon m' /app/server.mjs || true
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'RAPOR_R2B_PORTFOY',
 'Ilk kanon migrasyonu (Faz R2b): saha_musteri_kanon view v2 (ritim+recency_ay eklendi) + Portfoy raporu (/api/saha/rapor/portfoy) ciro/son CTE + saha_musteri_saglik join yerine tek view''den okur (alias m; repF/tipF/scope aynen). Sayi degismez (view=ayni hesap) — saf tutarlilik + pattern kanit. Sonraki: Kapsam (dedup), Ozet (tip ekseni+aktif payda), Ciro/Rotam.',
 'derive-rapor-kanon.md R2b. Tek kanonik kaynak; sekmeler-arasi tutarsizligi kokten kapatir.',
 '{"marker":"RAPOR_R2B_PORTFOY","tur":"migrasyon","yuzey":"server","rapor":"portfoy","kaynak":"saha_musteri_kanon"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='RAPOR_R2B_PORTFOY');
SELECT count(*) r2bp FROM bi_insa_gunlugu WHERE adim='RAPOR_R2B_PORTFOY';
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] RAPOR_R2B_PORTFOY CANLI — Portföy artık kanon view'den. Sayı aynı; tutarlılık tabanı kuruldu. (hard-refresh + Portföy'ü aç, sayılar eskisiyle aynı olmalı)"
