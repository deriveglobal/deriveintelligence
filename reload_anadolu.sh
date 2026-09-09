#!/usr/bin/env bash
# Anadolu stok_hareket YENIDEN YUKLE (alim lotlari eklendi) + marj_atom + snapshot.
# Sunucuda calisir. docker cp YASAK -> xlsx stdin pipe ile konteynere aktarilir.
# Idempotent: stok_hareket tarih-araligi replace; marj_atom/marj_fact per-tenant.
set -uo pipefail
TID=42822870-4ea3-424d-a16f-50b91afca32c
KRB=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
HOSTF=/opt/krb-assessment/07_stok_hareket.xlsx
PSQL(){ docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "$1"; }

echo "== 1. xlsx'i konteynere aktar (stdin pipe) =="
cat "$HOSTF" | docker exec -i krb-assessment sh -c "mkdir -p /tmp/anadolu_out && cat > /tmp/anadolu_out/07_stok_hareket.xlsx && wc -c < /tmp/anadolu_out/07_stok_hareket.xlsx"

echo "== 2. --kuru (gercek motor on-dogrulama; yazmaz) =="
docker exec krb-assessment python3 /app/erp_ingest.py --kuru /tmp/anadolu_out/07_stok_hareket.xlsx \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print('  tip=',d.get('tip'),'ok=',d.get('ok'),'satir=',d.get('satir'),'kapi=',[g.get('kapi') for g in (d.get('kapilar') or []) if not g.get('gecti')])"

echo "== 3. YUKLE stok_hareket (turet: maliyet_ay + marj_fact per-tenant) =="
docker exec krb-assessment python3 /app/erp_ingest.py /tmp/anadolu_out/07_stok_hareket.xlsx $TID \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print('  ok=',d.get('ok'),'satir=',d.get('satir'),'turet=',(d.get('turetme') or {}).get('turetilen'),'uyari=',(d.get('turetme') or {}).get('uyari'))"

echo "== 4. marj_atom yeniden kur (kanonik marj — SATIS x alim lotu akis maliyeti) =="
PSQL "SELECT 'atom_uret='||metrik_marj_atom_uret('$TID'::uuid);"

echo "== 5. snapshot al (DSO artik v_finans'tan HESAPLANIR, NULL degil beklenir) =="
if PSQL "SELECT metrik_snapshot_al('$TID'::uuid);" ; then echo "  snapshot OK (hata yok)"; else echo "  !!! snapshot HATA (yukari bak)"; fi

echo "== 6. DOGRULAMA =="
PSQL "SELECT 'ANADOLU marj_atom='||count(*)||'  donem='||count(*) FILTER (WHERE maliyet_kaynak='donem')||'  fallback='||count(*) FILTER (WHERE maliyet_kaynak='fallback') FROM bi_marj_atom WHERE tenant_id::text='$TID';"
PSQL "SELECT 'ANADOLU marj_pct(atom)='||round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) FROM bi_marj_atom WHERE tenant_id::text='$TID';"
PSQL "SELECT 'ANADOLU v_finans: DSO='||round(dso)||' DIO='||round(dio)||' DPO='||round(dpo)||' CCC='||round(ccc)||' marj%='||marj_pct FROM v_finans_ticari_sermaye WHERE tenant_id::text='$TID';"
PSQL "SELECT 'ANADOLU dso(bi_metrik_gecmis)='||coalesce(deger::text,'NULL') FROM bi_metrik_gecmis WHERE tenant_id::text='$TID' AND metrik='dso' ORDER BY donem DESC LIMIT 1;"
PSQL "SELECT 'marj_fact tenant dagilim: '||string_agg(t||'='||c,', ') FROM (SELECT tenant_id::text t, count(*) c FROM bi_marj_fact GROUP BY 1) x;"
PSQL "SELECT 'KRB marj_atom (bozulmadi ~15631 beklenir)='||count(*) FROM bi_marj_atom WHERE tenant_id::text='$KRB';"
echo "== BITTI =="
