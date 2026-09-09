#!/usr/bin/env bash
# OMURGA 60 — KORELASYON AVCISI (hunter): sana söylemeden desen arar, aday önerir.
# "Sen bulmuyorsun, o buluyor; sen onaylıyorsun." Aday → (onaylayınca) yasa/aksiyon.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. korelasyon_avci(tenant) — desen taraması, aday üretir"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION korelasyon_avci(p_tenant uuid) RETURNS jsonb AS $fn$
DECLARE out jsonb := '[]'::jsonb; n int; ornek text[]; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  -- DESEN A: ÇİFT ROL — hem müşteri (bize borçlu) hem de bizim borçlu olduğumuz taraf
  SELECT count(*), (array_agg(ad ORDER BY vg DESC))[1:5] INTO n, ornek FROM (
    SELECT r.muhatap_adi ad, COALESCE(r.vadesi_gecmis,0) vg
    FROM bi_musteri_risk r
    WHERE r.tenant_id=p_tenant AND r.musteri_mi IS TRUE AND COALESCE(r.vadesi_gecmis,0)>1000000
      AND EXISTS (SELECT 1 FROM bi_cari_bakiye cb WHERE cb.tenant_id=p_tenant
                    AND (cb.musteri_kodu=r.muhatap_kodu OR cb.tedarikci_kodu=r.muhatap_kodu)
                    AND COALESCE(cb.tedarikci_bakiye,0)<0)) z;
  IF n>0 THEN out := out || jsonb_build_array(jsonb_build_object(
    'desen','cift_rol','adet',n,'ornekler',to_jsonb(ornek),
    'gozlem',n||' firma hem müşteri hem de borçlu olduğun taraf; vadesi geçmişleri tek başına RİSK sayılmamalı, net pozisyonla değerlendirilmeli',
    'ilgili_yasa','net_pozisyon (zaten var — bu firmaların hepsine uygulanıyor)')); END IF;

  -- DESEN B: ÇELİŞKİ — vadesi geçmiş yüksek AMA hızlı ödüyor (snapshot/veri şüphesi)
  SELECT count(*), (array_agg(ad ORDER BY vg DESC))[1:5] INTO n, ornek FROM (
    SELECT mr.muhatap_adi ad, COALESCE(mr.vadesi_gecmis,0) vg
    FROM bi_musteri_risk mr
    JOIN bi_musteri_risk_odeme ro ON ro.muhatap_kodu=mr.muhatap_kodu AND ro.tenant_id=mr.tenant_id
    WHERE mr.tenant_id=p_tenant AND mr.musteri_mi IS TRUE
      AND COALESCE(mr.vadesi_gecmis,0)>5000000 AND COALESCE(ro.ort_tahsilat_gun,999) < 30) z;
  IF n>0 THEN out := out || jsonb_build_array(jsonb_build_object(
    'desen','celiski_vade_vs_odeme','adet',n,'ornekler',to_jsonb(ornek),
    'gozlem',n||' firmanın vadesi geçmişi yüksek AMA ortalama tahsilatı <30 gün — çelişkili; snapshot bakiye anlık olabilir ya da veri şüpheli',
    'ilgili_yasa','ADAY: "vadesi geçmiş yüksek + hızlı ödeme = anlık bakiye, kalıcı risk değil" — onaylar mısın?')); END IF;

  -- DESEN C: ZARARINA HACİM — negatif marjlı ama hacimli satılan SKU (atomdan)
  SELECT count(*), (array_agg(e ORDER BY ad DESC))[1:5] INTO n, ornek FROM (
    SELECT max(ebat) e, sum(adet) ad, round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
    FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay>=m0-interval '6 month'
    GROUP BY kalem_kodu HAVING round(100*sum(brut_kar)/nullif(sum(ciro),0),1) < 0 AND sum(adet) > 100) z;
  IF n>0 THEN out := out || jsonb_build_array(jsonb_build_object(
    'desen','zararina_hacim','adet',n,'ornekler',to_jsonb(ornek),
    'gozlem',n||' SKU son 6 ayda NEGATİF marjla ve 100+ adet satıldı — hacim büyüdükçe zarar büyüyor',
    'ilgili_yasa','ADAY: "negatif marj + artan hacim = acil fiyat/çekme kararı" — onaylar mısın?')); END IF;

  RETURN out;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ korelasyon_avci"

hr "2. AVI ÇALIŞTIR — sistem hangi desenleri KENDİ buldu"
$PSQL -c "SELECT jsonb_pretty(korelasyon_avci('$T'::uuid));" 2>&1 | sed 's/^/  /'

hr "BITTI — hunter söylemeden buldu. ADAY olanlar → senin evet/hayır'ın → yeni yasa/aksiyon."
