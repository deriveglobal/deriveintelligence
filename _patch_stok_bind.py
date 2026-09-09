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
