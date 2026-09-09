#!/usr/bin/env bash
# YETKI_FAZ2A — Org Bölüm/Üyelik modeli + yönetim API'si. server_container.mjs (7 uç) + DDL (2 tablo + seed).
#   "apply" şablon capabilities'ini üyelerin permissions_json.departments[]'ine yazar → mevcut _sahaCap zorlar.
#   Rollback'li (server), tek build, idempotent. UI (Bölümler sekmesi) = Faz 2b (ayrı).
# KULLANIM: scp -i $KEY deploy_yetki_faz2a.sh patch_yetki_faz2a_server.py $H:/opt/krb-assessment/
#           ssh -i $KEY $H 'cd /opt/krb-assessment && bash deploy_yetki_faz2a.sh'
set -euo pipefail
cd /opt/krb-assessment
SRV=server_container.mjs
[ -f "$SRV" ] && [ -f patch_yetki_faz2a_server.py ] || { echo "HATA: dosya yok"; exit 1; }
grep -q "YETKI_FAZ1" "$SRV" || echo "[uyari] server'da YETKI_FAZ1 izi yok — taze canlı mı? yine de devam"
TS=$(date +%s); cp -a "$SRV" "$SRV.bak.$TS"; echo "[yedek] $SRV.bak.$TS"
rollback(){ echo "GERİ AL"; cp -a "$SRV.bak.$TS" "$SRV"; }
python3 patch_yetki_faz2a_server.py "$SRV" || { rollback; exit 1; }
node --check "$SRV" || { echo "HATA node"; rollback; exit 1; }
echo "[ok] syntax"

echo "[DDL] tablolar + seed (build/recreate öncesi)"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || { echo "DDL HATASI"; rollback; exit 1; }
CREATE TABLE IF NOT EXISTS tenant_department (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  key text NOT NULL,
  ad text NOT NULL,
  ikon text DEFAULT '🏷️',
  template_json jsonb NOT NULL DEFAULT '{"capabilities":[],"scope":{"level":"kendi","regions":[],"segments":[]}}'::jsonb,
  aktif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, key)
);
CREATE TABLE IF NOT EXISTS tenant_department_membership (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  department_id uuid NOT NULL REFERENCES tenant_department(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, department_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_dept_mem_user ON tenant_department_membership(tenant_id, user_id);

-- seed (KRB): Satış (rep şablonu, kapsam=kendi) + Yönetim (yönetici şablonu, kapsam=tümü)
INSERT INTO tenant_department (tenant_id, key, ad, ikon, template_json)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','satis','Satış','💼',
 '{"capabilities":["bugun","ziyaretler","plan","musteriler","musterikart","teklif","notlarim","rep-brain","piyasa","rakip","rapor","duyurular","mesajlar","oneriler","rotam"],"scope":{"level":"kendi","regions":[],"segments":[]}}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM tenant_department WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND key='satis');
INSERT INTO tenant_department (tenant_id, key, ad, ikon, template_json)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','yonetim','Yönetim','📊',
 '{"capabilities":["bugun","ziyaretler","plan","musteriler","musterikart","teklif","notlarim","rep-brain","piyasa","rakip","rapor","duyurular","mesajlar","oneriler","harita","kokpit","ceo","ciro","risk","rotam","kapsam"],"scope":{"level":"tumu","regions":[],"segments":[]}}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM tenant_department WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND key='yonetim');
SELECT key, ad, jsonb_array_length(template_json->'capabilities') caps FROM tenant_department WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' ORDER BY ad;
SQL

docker build -t krb-assessment:secure . >/tmp/faz2a_build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI"; tail -20 /tmp/faz2a_build.log; rollback; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
CID="$(docker compose ps -q krb-assessment)"
echo -n "[dogrula] server YETKI_FAZ2A (8): "; docker exec "$CID" grep -c YETKI_FAZ2A /app/server.mjs || true
echo -n "[dogrula] tablolar: "; docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('tenant_department','tenant_department_membership')" || true

docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL' || echo "[uyari] fingerprint"
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'YETKI_FAZ2A',
 'Org Bolum/Uyelik modeli: tablolar tenant_department (key/ad/ikon/template_json{capabilities,scope}/aktif) + tenant_department_membership (bolum<->kullanici, coklu). 7 uc (requireTenantAdmin): departments list/create/patch/delete + :id/members get/post + :id/apply. apply = sablon capabilities uyelerin permissions_json.departments[] icine yazar (push) -> mevcut _sahaCap/_enforceSahaDept zorlar (cekirdek auth degismedi). Seed: Satis (rep sablonu, kapsam=kendi) + Yonetim (kapsam=tumu). Kapsam saklanir, Faz 3 zorlar.',
 'derive-yetki-toparlama.md Faz 2a. Gercek SaaS yetki matrisi: org bolum katmani + toplu uygula. UI (Bolumler sekmesi)=Faz 2b.',
 '{"marker":"YETKI_FAZ2A","tur":"model+uc","tablolar":["tenant_department","tenant_department_membership"],"uc":["/api/tenant/departments","/api/tenant/departments/:id","/api/tenant/departments/:id/members","/api/tenant/departments/:id/apply"],"plan":"derive-yetki-toparlama.md"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2A');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'tenant_departments','uc','Org bolum/uyelik yonetimi: bolum olustur/duzenle/sil, uye ekle-cikar, bolum sablonunu (capabilities+scope) uyelere toplu uygula. Yonetim > Izinler > Bolumler.',
 'GET/POST /api/tenant/departments; PATCH/DELETE /api/tenant/departments/:id; GET/POST /:id/members; POST /:id/apply (requireTenantAdmin)','yetki','canli','taslak',
 '{"marker":"YETKI_FAZ2A"}'::jsonb, true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant_departments');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'tenant_department','tablo','Org bolum tanimi: key/ad/ikon + template_json (bolumun yetenek seti + varsayilan veri kapsami) + aktif.','SELECT * FROM tenant_department','yetki','canli','taslak',true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant_department');
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'tenant_department_membership','tablo','Kullanici<->bolum uyeligi (coklu). apply bu uyelere sablonu push eder.','SELECT * FROM tenant_department_membership','yetki','canli','taslak',true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='tenant_department_membership');
UPDATE bi_yetenek SET ne_ise_yarar=COALESCE(NULLIF(ne_ise_yarar,''),'Org bolum tanimi (template_json: yetenek+kapsam).'), durum='canli', cekmece='yetki', guncellendi_at=now()
 WHERE ad IN ('tenant_department','tenant_department_membership') AND (ne_ise_yarar IS NULL OR ne_ise_yarar='' OR durum='tanimsiz');

SELECT (SELECT count(*) FROM bi_insa_gunlugu WHERE adim='YETKI_FAZ2A') insa,
       (SELECT count(*) FROM bi_yetenek WHERE ad IN ('tenant_departments','tenant_department','tenant_department_membership')) yetenek;
SQL
docker image prune -f >/dev/null 2>&1 || true
echo "[BITTI] YETKI_FAZ2A CANLI — bölüm modeli + API. Test: GET /api/tenant/departments → Satış+Yönetim. UI Faz 2b."
