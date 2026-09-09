#!/usr/bin/env bash
# deploy_stok_bind_v1.sh — Stok degerini KANONA (v_stok_deger_kanon, LASTIK%) bagla. 6 yuzey.
#   Ham ~413,8M (yardimci malzeme dahil) yerine gercek lastik ~278,7M. AI dahil.
#   View okumalari tenant_id::text=$1 (uuid=text param tuzagi — olay dersi).
# ONKOSUL: v_stok_deger_kanon CANLI (kanon_stok_view.sql calismis).
# SUNUCUDA:  cd /opt/krb-assessment && bash deploy_stok_bind_v1.sh
# node --check + PARAM'li dogrulama (PREPARE, ::text) + COKME testi + OTOMATIK ROLLBACK. Yedek: *.bak_stok_<ts>
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

echo "== [0] onkosul: v_stok_deger_kanon + PARAM'li dogrulama (endpoint sorgusunun BIREBIR formu) =="
VOK=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "SELECT count(*) FROM pg_views WHERE viewname='v_stok_deger_kanon';")
if [ "$VOK" != "1" ]; then echo "  !!! v_stok_deger_kanon YOK — once kanon_stok_view.sql calistir. DURDU."; exit 1; fi
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "PREPARE _st(text) AS SELECT sku_sayisi, round(stok_deger/1e6,1) deger_M, kritik_stok FROM v_stok_deger_kanon WHERE tenant_id::text = \$1; EXECUTE _st('$T'); DEALLOCATE _st;" || { echo "  !!! PARAM sorgu HATASI — bind YAPMA. DURDU."; exit 1; }
echo "  PREPARE(::text) param testi GECTI"

echo "== [1] yedek =="
cp server_container.mjs "server_container.mjs.bak_stok_$TS"

echo "== [2] patch =="
cat > /opt/krb-assessment/_patch_stok_bind.py <<'PY_EOF'
import sys
F=sys.argv[1] if len(sys.argv)>1 else "/opt/krb-assessment/server_container.mjs"
s=open(F,encoding="utf-8").read()
GUARD="v_stok_deger_kanon"
if s.count(GUARD)>0:
    print("[stok-bind] ZATEN BAGLI (v_stok_deger_kanon gecuyor) — atlaniyor"); sys.exit(0)

reps=[
 # 1) warehouse/kpis result -> view
 ("warehouse_result",
  """    const result = await query(`
      SELECT
        COUNT(DISTINCT kalem_kodu)                                          AS sku_sayisi,
        SUM(toplam_deger)                                                   AS stok_degeri,
        COUNT(*) FILTER (WHERE eldeki_miktar <= min_stok AND min_stok > 0) AS kritik_stok_sayisi,
        COUNT(*) FILTER (WHERE eldeki_miktar = 0)                          AS sifir_stok_sayisi
      FROM bi_stok_durumu
      WHERE tenant_id = $1 AND export_date = $2`, [session.tenantId, date]);""",
  """    const result = await query(`
      SELECT sku_sayisi, stok_deger AS stok_degeri, kritik_stok AS kritik_stok_sayisi, sifir_stok AS sifir_stok_sayisi
      FROM v_stok_deger_kanon WHERE tenant_id::text = $1`, [session.tenantId]); /* STOK_KANON: lastik-kapsamli */"""),
 # 2) warehouse dead_stock -> LASTIK% filtre (deger sıralaması dogru; donuk-tablo ayri hijyen)
 ("dead_stock_filter",
  "WHERE bsd.tenant_id = $1 AND bsd.export_date = $2 AND bsd.eldeki_miktar > 0",
  "WHERE bsd.tenant_id = $1 AND bsd.export_date = $2 AND bsd.grup_adi ILIKE 'LASTIK%' AND bsd.eldeki_miktar > 0"),
 # 3) morning-briefing stok -> view
 ("morning_stok",
  """query(`SELECT COALESCE(SUM(toplam_deger), 0) AS stok_degeri,
                  COUNT(*) FILTER (WHERE eldeki_miktar <= min_stok AND min_stok > 0) AS kritik_stok
           FROM bi_stok_durumu WHERE tenant_id = $1 AND export_date = (
             SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1)`,""",
  """query(`SELECT COALESCE(stok_deger,0) AS stok_degeri, kritik_stok
           FROM v_stok_deger_kanon WHERE tenant_id::text = $1`, /* STOK_KANON */"""),
 # 4) dept-context pricing -> view
 ("dept_pricing",
  """    pricing: `SELECT 'Son 90 gün stok değeri: ' || COALESCE(SUM(toplam_deger)::text, 'Veri yok') || ' TL' AS ozet
              FROM bi_stok_durumu WHERE tenant_id = $1 AND export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1)`,""",
  """    pricing: `SELECT 'Stok değeri (lastik, güncel): ' || COALESCE(stok_deger::text, 'Veri yok') || ' TL' AS ozet
              FROM v_stok_deger_kanon WHERE tenant_id::text = $1`,"""),
 # 5) dept-context warehouse -> view
 ("dept_warehouse",
  """    warehouse: `SELECT 'Toplam SKU: ' || COUNT(DISTINCT kalem_kodu) || ', Stok değeri: ' || COALESCE(SUM(toplam_deger)::text, 'Veri yok') || ' TL' AS ozet
                FROM bi_stok_durumu WHERE tenant_id = $1 AND export_date = (SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id = $1)`,""",
  """    warehouse: `SELECT 'Toplam SKU (lastik): ' || sku_sayisi || ', Stok değeri: ' || COALESCE(stok_deger::text, 'Veri yok') || ' TL' AS ozet
                FROM v_stok_deger_kanon WHERE tenant_id::text = $1`,"""),
 # 6) AI prompt "Stok değer" ornegi -> LASTIK% scope
 ("ai_prompt_stok",
  "'  Stok değer: SELECT marka, SUM(eldeki_miktar) adet, SUM(eldeki_miktar*birim_maliyet) deger FROM bi_stok_durumu WHERE tenant_id=$1 AND birim_maliyet>0 GROUP BY marka ORDER BY deger DESC\\n' +",
  "'  Stok değer (lastik): SELECT marka, SUM(eldeki_miktar) adet, SUM(eldeki_miktar*birim_maliyet) deger FROM bi_stok_durumu WHERE tenant_id=$1 AND grup_adi ILIKE \\'LASTIK%\\' AND birim_maliyet>0 GROUP BY marka ORDER BY deger DESC\\n' +"),
]

bad=0
for ad,o,n in reps:
    c=s.count(o)
    if c!=1:
        print("[stok-bind] %-18s eslesme=%d (1 olmali)"%(ad,c)); bad=1
if bad: print("[stok-bind] DURDU — dokunulmadi"); sys.exit(2)
for ad,o,n in reps: s=s.replace(o,n,1)
open(F,"w",encoding="utf-8").write(s)
print("[stok-bind] OK — 6 stok yuzeyi kanona (v_stok_deger_kanon / LASTIK%) baglandi")
PY_EOF
python3 /opt/krb-assessment/_patch_stok_bind.py || { echo "patch DURDU — rollback"; cp "server_container.mjs.bak_stok_$TS" server_container.mjs; exit 1; }

echo "== [3] node --check =="
node --check server_container.mjs || { echo "FAIL — rollback"; cp "server_container.mjs.bak_stok_$TS" server_container.mjs; exit 1; }
echo "  v_stok_deger_kanon ref: $(grep -c v_stok_deger_kanon server_container.mjs)"

echo "== [4] build + restart =="
docker build -t krb-assessment:secure . >/dev/null
docker compose up -d --force-recreate krb-assessment

echo "== [5] 8sn bekle + log hata taramasi =="
sleep 8
ERR=$(docker logs --since 60s krb-assessment 2>&1 | grep -ciE 'error|does not exist|hata' || true)
echo "  son 60sn hata satiri: $ERR · container: $(docker ps --filter name=krb-assessment --format '{{.Status}}')"
if docker logs --since 60s krb-assessment 2>&1 | grep -qE 'does not exist'; then echo "  !!! SQL HATASI — ROLLBACK"; cp "server_container.mjs.bak_stok_$TS" server_container.mjs; docker build -t krb-assessment:secure . >/dev/null 2>&1 && docker compose up -d --force-recreate krb-assessment; echo "geri alindi"; exit 1; fi

echo "== [6] canli deger (kanon lastik ~278,7M) =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT round(stok_deger/1e6,1) kanon_lastik_M, sku_sayisi, kritik_stok, sifir_stok FROM v_stok_deger_kanon WHERE tenant_id::text='$T';"

echo "== [7] fingerprint =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL_EOF'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'STOK_KANON_V1',
 'Stok degeri KANONU: v_stok_deger_kanon (bi_stok_durumu son export + grup_adi ILIKE LASTIK%). 6 yuzey baglandi: warehouse/kpis, dead_stock(LASTIK%), morning-briefing AI, dept-context pricing+warehouse AI, AI prompt ornegi. Kanon lastik ~278,7M; ham ~413,8M (fark ~135M lastik-disi). Eski 730,9M bayatti. View okumalari tenant_id::text=$1 (uuid=text param tuzagi olay dersi).',
 'Finans disinda her yer ham toplam_deger gosteriyordu; AI ham sayiyi stok diye anlatiyordu. Fatih: tek kaynak/tek tanim. Kanon = 278,7M.',
 '{"marker":"STOK_KANON_V1","kaynak":"v_stok_deger_kanon","deger_M":278.7,"ham_M":413.8,"baglanan":["warehouse/kpis","dead_stock","morning-briefing","dept-pricing","dept-warehouse","ai-prompt"],"acik":["donuk bi_stok_hareketleri hijyen","analytics DIO/CCC ayri"]}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='STOK_KANON_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'v_stok_deger_kanon','view','Lastik stok degeri — TEK kanonik kaynak (deger+sku+kritik+sifir). Ekranlar+AI buradan okur.','bi_stok_durumu son export + grup_adi ILIKE LASTIK%; ham ~413,8M yerine gercek lastik ~278,7M.','stok','canli','kanitli','{"marker":"STOK_KANON_V1","deger_M":278.7}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='v_stok_deger_kanon');
SQL_EOF
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT adim FROM bi_insa_gunlugu WHERE adim='STOK_KANON_V1'; SELECT ad,durum FROM bi_yetenek WHERE ad='v_stok_deger_kanon';"
echo "== BITTI — Stok KANON (v_stok_deger_kanon). Warehouse + AI dahil ~278,7M. Sayfalari yenile. =="
