-- ROLLBACK YEDEĞİ — metrik_snapshot_al ORİJİNAL (DONGU_KANON_SNAPSHOT_V1 öncesi). 2026-08-06 teşhisten alındı.
-- Geri almak için bu dosyayı psql'e ver.
CREATE OR REPLACE FUNCTION public.metrik_snapshot_al(p_tenant uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- A. CIRO (akış, son 3 ay)
  WITH t_sinir AS (SELECT tenant_id, date_trunc('month',max(fatura_tarihi))::date son_ay, date_trunc('month',min(fatura_tarihi))::date ilk_ay
                     FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text GROUP BY tenant_id),
  aylar AS (SELECT generate_series(date_trunc('month',CURRENT_DATE)::date - interval '2 month', date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date ay)
  INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
  SELECT ts.tenant_id::uuid, m.metrik,'sirket','','ay',a.ay,
         metrik_ciro(ts.tenant_id::uuid,a.ay,m.lastik),'TL','kesin','bi_satis_faturalari', jsonb_build_object('tam', a.ay < ts.son_ay)
    FROM t_sinir ts CROSS JOIN aylar a CROSS JOIN (VALUES ('ciro_lastik',true),('ciro_tum',false)) AS m(metrik,lastik)
   WHERE a.ay >= ts.ilk_ay
  ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();

  -- B. DSO + alacak + gunluk_kredili
  WITH comp AS (SELECT r.tenant_id, sum(r.hesap_bakiyesi) FILTER (WHERE COALESCE(r.musteri_mi,true)) AS alacak,
                       metrik_gunluk_kredili(r.tenant_id, CURRENT_DATE) AS gunluk
                  FROM bi_musteri_risk r WHERE r.tenant_id::text=p_tenant::text GROUP BY r.tenant_id)
  INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
  SELECT * FROM (
    SELECT tenant_id,'dso','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, CASE WHEN gunluk>0 THEN round(alacak/gunluk) END,'gun','snapshot','bi_musteri_risk',jsonb_build_object('tam',false) FROM comp
    UNION ALL SELECT tenant_id,'alacak','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(alacak),'TL','snapshot','bi_musteri_risk',jsonb_build_object('tam',false) FROM comp
    UNION ALL SELECT tenant_id,'gunluk_kredili_satis','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(gunluk),'TL','kesin','bi_satis_faturalari',jsonb_build_object('tam',false) FROM comp
  ) x
  ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

  -- C. STOK DEĞERİ
  WITH km AS (SELECT tenant_id, kalem_kodu, sum(giris_tutari) gt, sum(giris) g FROM bi_stok_hareket WHERE giris>0 AND tenant_id::text=p_tenant::text GROUP BY tenant_id, kalem_kodu),
  sd AS (SELECT a.tenant_id, sum(a.adet*(km.gt/km.g)) deger FROM bi_stok_anlik a JOIN km ON km.tenant_id=a.tenant_id AND km.kalem_kodu=a.kalem_kodu WHERE a.adet>0 AND a.tenant_id::text=p_tenant::text GROUP BY a.tenant_id)
  INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
  SELECT tenant_id,'stok_deger','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(deger),'TL','snapshot','bi_stok_anlik',jsonb_build_object('tam',false) FROM sd
  ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

  -- D. TEDARİKÇİ BORCU (snapshot-only)
  INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
  SELECT tenant_id,'tedarikci_borcu','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, round(sum(abs(tedarikci_bakiye)) FILTER (WHERE tedarikci_bakiye<0)),'TL','snapshot','bi_cari_bakiye', jsonb_build_object('tam',false,'not','snapshot-only')
    FROM bi_cari_bakiye WHERE tenant_id::text=p_tenant::text GROUP BY tenant_id
  ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

  -- E. NET İŞLETME SERMAYESİ (türev)
  INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
  SELECT s.tenant_id,'net_isletme_sermayesi','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, s.deger+a.deger-b.deger,'TL','snapshot','turev',jsonb_build_object('tam',false,'formul','stok+alacak-borc')
    FROM (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='stok_deger' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date AND tenant_id=p_tenant) s
    JOIN (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='alacak' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date AND tenant_id=p_tenant) a USING(tenant_id)
    JOIN (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='tedarikci_borcu' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date AND tenant_id=p_tenant) b USING(tenant_id)
  ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, meta=EXCLUDED.meta, hesaplanma_at=now();
END;
$function$;
