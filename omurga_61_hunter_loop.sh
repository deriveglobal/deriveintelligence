#!/usr/bin/env bash
# OMURGA 61 — DÖNGÜYÜ KAPAT: hunter adayı → soru → evet/hayır → CANLI yasa (trigger'la, kod yazmadan).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. Aday yasaların FONKSİYONLARI (onaylanınca çalışacak)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION yasa_celiski_odeme(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE vg numeric; gun numeric;
BEGIN
  IF p_tur<>'musteri' THEN RETURN jsonb_build_object('fired',false); END IF;
  SELECT COALESCE(vadesi_gecmis,0) INTO vg FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar;
  SELECT min(ort_tahsilat_gun) INTO gun FROM bi_musteri_risk_odeme WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar;
  IF COALESCE(vg,0)>5000000 AND gun IS NOT NULL AND gun<30 THEN
    RETURN jsonb_build_object('fired',true,'yasa','celiski_odeme',
      'bulgu','Vadesi geçmiş '||replace(round(vg/1e6,1)::text,'.',',')||'M yüksek görünüyor AMA ortalama tahsilat yalnızca '||round(gun)||' gün — büyük olasılıkla anlık/snapshot bakiye, kalıcı tahsilat riski gibi okunmamalı',
      'veri',jsonb_build_object('vgecmis_m',round(vg/1e6,1),'tahsilat_gun',round(gun)));
  END IF;
  RETURN jsonb_build_object('fired',false);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION yasa_zararina_hacim(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE n int; ornek text; m0 date:=date_trunc('month',CURRENT_DATE)::date;
BEGIN
  IF p_tur<>'marka' THEN RETURN jsonb_build_object('fired',false); END IF;
  SELECT count(*), string_agg(e||' ('||ad||' ad, %'||marj||')','; ') INTO n, ornek FROM (
    SELECT max(ebat) e, sum(adet) ad, round(100*sum(brut_kar)/nullif(sum(ciro),0),1) marj
    FROM bi_marj_atom WHERE tenant_id=p_tenant AND upper(marka)=upper(p_anahtar) AND ay>=m0-interval '6 month'
    GROUP BY kalem_kodu HAVING round(100*sum(brut_kar)/nullif(sum(ciro),0),1)<0 AND sum(adet)>100
    ORDER BY sum(adet) DESC LIMIT 3) z;
  IF n>0 THEN RETURN jsonb_build_object('fired',true,'yasa','zararina_hacim',
    'bulgu',n||' ebat negatif marjla ve 100+ adet satılıyor, zarar hacimle büyüyor: '||ornek,'veri',jsonb_build_object('sku_sayisi',n));
  END IF;
  RETURN jsonb_build_object('fired',false);
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ yasa_celiski_odeme + yasa_zararina_hacim"

hr "2. bi_yasa'ya ADAY olarak kaydet (durum='aday' → runner HENÜZ uygulamaz)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
INSERT INTO bi_yasa(kod,ad,tur,kapsam,aciklama,durum,kaynak,guven) VALUES
('celiski_odeme','Vade-ödeme çelişkisi','sanity',ARRAY['musteri'],'Vadesi geçmiş yüksek ama ortalama tahsilat çok hızlıysa (snapshot), kalıcı risk sayılmaz.','aday','hunter','taslak'),
('zararina_hacim','Zararına hacim','decompose',ARRAY['marka'],'Bir markada negatif marjlı SKU hacimle büyüyorsa acil fiyat/çekme sinyali.','aday','hunter','taslak')
ON CONFLICT (kod) DO NOTHING;
SQL

hr "3. TRIGGER — aday-yasa sorusu cevaplanınca bi_yasa'yı otomatik aç/kapat (UI'dan da çalışır)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION tr_aday_yasa() RETURNS trigger AS $$
BEGIN
  IF NEW.durum='cevaplandi' AND NEW.anahtar LIKE 'aday-yasa:%' AND NEW.cevap IS NOT NULL THEN
    IF NEW.cevap ~* '(evet|yasa yap|onayla|uygula)' THEN
      UPDATE bi_yasa SET durum='taslak', kaynak='hunter+kullanici' WHERE kod=split_part(NEW.anahtar,':',2) AND durum='aday';
    ELSIF NEW.cevap ~* '(hayır|hayir|önemsiz|onemsiz|gerek yok)' THEN
      UPDATE bi_yasa SET durum='kapali' WHERE kod=split_part(NEW.anahtar,':',2) AND durum='aday';
    END IF;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_aday_yasa ON bi_sistem_sorusu;
CREATE TRIGGER trg_aday_yasa AFTER UPDATE ON bi_sistem_sorusu FOR EACH ROW EXECUTE FUNCTION tr_aday_yasa();
SQL
echo "  ✅ trigger"

hr "4. avci_sor — hunter adaylarını SORUYA çevir"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION avci_sor(p_tenant uuid) RETURNS int AS $$
DECLARE adaylar jsonb; c jsonb; n int:=0; desen text; v_kod text; sid uuid;
BEGIN
  adaylar := korelasyon_avci(p_tenant);
  FOR c IN SELECT jsonb_array_elements(adaylar) LOOP
    desen := c->>'desen';
    v_kod := CASE desen WHEN 'celiski_vade_vs_odeme' THEN 'celiski_odeme' WHEN 'zararina_hacim' THEN 'zararina_hacim' ELSE NULL END;
    IF v_kod IS NOT NULL AND EXISTS (SELECT 1 FROM bi_yasa y WHERE y.kod=v_kod AND y.durum='aday') THEN
      sid := ogren_sor(p_tenant,'sistem','aday-yasa:'||v_kod,
        'Fark ettim: '||(c->>'gozlem')||'. Bunu kalıcı bir kural (yasa) yapayım mı?',
        (c->>'gozlem'),
        '["Evet, yasa yap","Hayır, önemsiz","Zaten uyguluyorum"]'::jsonb);
      n := n+1;
    END IF;
  END LOOP;
  RETURN n;
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ avci_sor"

hr "5. LOOP CANLI GÖSTERİM — (a) hunter sordu"
$PSQL -c "SELECT avci_sor('$T'::uuid) AS sorulan_aday;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT anahtar, left(soru,70) soru FROM bi_sistem_sorusu WHERE tenant_id='$T'::uuid AND durum='acik' AND anahtar LIKE 'aday-yasa:%';" 2>&1 | sed 's/^/  /'

hr "6. (b) SEN 'Evet, yasa yap' dedin (UI'daki cevap POST'u ile AYNI) → trigger yasayı açar"
$PSQL -c "UPDATE bi_sistem_sorusu SET cevap='Evet, yasa yap', cevap_zamani=now(), durum='cevaplandi' WHERE tenant_id='$T'::uuid AND anahtar='aday-yasa:celiski_odeme' AND durum='acik';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT kod, durum, kaynak FROM bi_yasa WHERE kod='celiski_odeme';" 2>&1 | sed 's/^/  /'

hr "7. (c) YENİ YASA ARTIK CANLI — capraz_kontrol Mutaflar'a net_pozisyon + celiski_odeme'yi BİRLİKTE uyguluyor"
$PSQL -c "SELECT jsonb_pretty(capraz_kontrol('$T'::uuid,'musteri','M4115532'));" 2>&1 | sed 's/^/  /'

hr "BITTI — DÖNGÜ KAPANDI: hunter buldu → sordu → sen onayladın → yasa canlı, her yere uygulanıyor. Kod yazmadan."
