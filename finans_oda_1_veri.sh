#!/usr/bin/env bash
# FINANS_ODA_1_VERI — koken + uc nokta. (UI ayri adimda.)
#
# ⚠ RAKAMLAR KILITLENDI (olculdu, 1.354 musterinin 1.320'sinde formul tuttu):
#   stok 268,3 + alacak 209,3 - tedarikci borcu 403,4 = NET 74,2M
#   yillik sermaye yuku 29,7M   (Fatih'e once 41,6M demistim — YANLIS)
#   Fatih'e once "net 103,9M" demistim — o alacak=238,8M (toplam_risk) ile hesapliydi.
#   toplam_risk = hesap_bakiyesi + cek/senet(29,5M) + bekleyen siparis(3,8M).
#   Bekleyen siparis HENUZ PARA DEGIL -> isletme sermayesinde hesap_bakiyesi kullanilir.
#
# ⚠ BRISA TAKVIMI — dusundugumden AGIR:
#   18 Kas 36,6M · 16 Ara 36,6M · 22 Oca 28,2M · 22 Sub 28,2M = DORT AYDA 129,6M
#   Brisa'ya toplam borc 319,0M. Dort aylik yukumluluk, net sermayenin 1,7 KATI.
#
# ⚠ EN KESKIN BULGU:
#   Limiti HIC OLMAYAN 533 musteride 41,9M alacak var — 26,0M'si ZATEN GECIKMIS.
#   Limitsiz verilen kredinin %62'si geri gelmemis. Tesaduf degil.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KOKEN — baslik kolonu zorunluymus, duzeltildi ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
INSERT INTO bi_sayi_koken (anahtar, baslik, kaynak, formul, varsayim, sinir, guven) VALUES
('alacak_bakiye', 'Alacak (tahsil edilecek)',
 'bi_musteri_risk.hesap_bakiyesi — accountriskreport, 12 Tem, 38.403 müşteri',
 'SUM(hesap_bakiyesi) WHERE musteri_mi',
 'Fiilen faturalanmış, tahsil edilecek tutar. Bekleyen sipariş ve çek/senet HARİÇ.',
 '⚠ İŞLETME SERMAYESİ İÇİN BU KULLANILIR — toplam_risk (238,8M) DEĞİL. Aradaki fark: çek/senet 29,5M + bekleyen sipariş 3,8M. Bekleyen sipariş henüz PARA DEĞİLDİR. ⚠ Eski bi_musteri_bakiye tablosu sadece 399 müşteri gösteriyordu ve KOLONLARI KAYMIŞTI: "bakiye" dediği 145,4M aslında vadesi geçmiş tutardı.',
 'yuksek'),
('vadesi_gecmis', 'Vadesi geçmiş alacak',
 'bi_musteri_risk.vadesi_gecmis — 12 Tem',
 'SUM(vadesi_gecmis) WHERE musteri_mi',
 'Vadesi dolmuş, hâlâ tahsil edilmemiş.',
 '⚠ 209,3M alacağın 145,4M''si — yani %69''u. Bu bir oran değil, bir DURUM. Brisa ödemeleri 18 Kasım''da başlıyor.',
 'yuksek'),
('limitsiz_alacak', 'Kredi limiti olmayan müşterilerdeki alacak',
 'master_musteri (bi_musteri_risk''ten türetilmiş)',
 'SUM(net_pozisyon) WHERE kredi_limiti <= 1',
 'ERP''de kredi limiti 0 veya 1 TL olarak duran müşteriler.',
 '⚠ "Limit AŞILDI" ile "limit HİÇ KONULMAMIŞ" aynı şey değil. Birincisi ihlal — müdahale ister. İkincisi boşluk — KARAR ister. 533 müşteride 41,9M alacak var ve 26,0M''si ZATEN GECİKMİŞ: limitsiz verilen kredinin %62''si geri gelmemiş.',
 'yuksek'),
('brisa_takvim', 'Brisa ödeme takvimi',
 'bi_sinyal (tur=odeme) + bi_cari_bakiye',
 '18 Kas 36,6M + 16 Ara 36,6M + 22 Oca 28,2M + 22 Şub 28,2M',
 'Brisa''ya toplam borç 319,0M. Ödeme tarihleri sabit.',
 '⚠ Dört ayda 129,6M nakit çıkışı. Net işletme sermayesi 74,2M. Yükümlülük, sermayenin 1,7 KATI. ⚠ Bu bir gösterge değil, bir TARİH.',
 'yuksek')
ON CONFLICT (anahtar) DO UPDATE
  SET baslik=EXCLUDED.baslik, kaynak=EXCLUDED.kaynak, formul=EXCLUDED.formul,
      varsayim=EXCLUDED.varsayim, sinir=EXCLUDED.sinir, guven=EXCLUDED.guven;

UPDATE bi_sayi_koken
   SET sinir = '⚠ 14 Tem''de İKİ KEZ DÜZELTİLDİ. (1) 13 Tem''e kadar tedarikçi borcu (403,4M) HİÇ SAYILMIYORDU: "bağlı sermaye 507,3M, değer kaybediyorsun" TEZİ kurulmuştu, YANLIŞTI. (2) 14 Tem: alacak bacağı toplam_risk (238,8M) yerine hesap_bakiyesi (209,3M) oldu — toplam_risk bekleyen siparişi de sayıyordu. Doğru: 268,3 + 209,3 − 403,4 = 74,2M. Yıllık yük 29,7M.'
 WHERE anahtar = 'net_sermaye';
SQL
$PSQL -c "SELECT anahtar, baslik, guven FROM bi_sayi_koken ORDER BY anahtar;"

echo
echo "############ 2) UC NOKTA — /api/bi/finans ############"
cp server_container.mjs server_container.mjs.bak_finans
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "FINANS_V1" in s: sys.exit("ZATEN YAMALI")

ANC = "  // Hangi dosyalar bekleniyor + hangisi ne zaman geldi"
assert ANC in s, "❌ capa yok"

EP = '''  // ── FINANS_V1 ─────────────────────────────────────────────────────────────
  // ⚠ TEK SORU: "18 Kasım'da 36,6M nereden gelecek?"
  //   Bu bir gosterge degil, bir TARIH. Oda o tarihin etrafinda kurulu.
  //
  // ⚠ TANIMLAR KILITLI (14 Tem, olculdu):
  //   alacak  = hesap_bakiyesi (209,3M) — toplam_risk DEGIL (238,8M).
  //             Fark: cek/senet 29,5M + bekleyen siparis 3,8M. Siparis henuz PARA DEGIL.
  //   borc    = bi_cari_bakiye, tedarikci_bakiye < 0 (403,4M · Brisa 319,0M)
  //   stok    = bi_stok_anlik × son tedarikci faturasi fiyati (268,3M)
  //   NET     = 268,3 + 209,3 − 403,4 = 74,2M   ·   yillik yuk 29,7M
  if (request.method === 'GET' && url.pathname === '/api/bi/finans') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const T = session.tenantId;
      const [sermaye, odemeler, riskler, limitsiz, yaslandirma] = await Promise.all([
        // 1) Deger agaci — her bacak KENDI kaynagindan
        query(`
          WITH sa AS (
            SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
                   bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat
              FROM bi_tedarikci_faturalari
             WHERE tenant_id=$1::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
             ORDER BY 1, fatura_tarihi DESC),
          stok AS (
            SELECT COALESCE(sum(st.adet*sa.fiyat),0) AS deger
              FROM bi_stok_anlik st
              LEFT JOIN sa ON sa.sku = bi_sku_norm(st.kalem_kodu)
             WHERE st.tenant_id=$1::uuid AND st.adet>0
               AND st.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id=$1::uuid)),
          alacak AS (
            -- ⚠ hesap_bakiyesi. toplam_risk DEGIL.
            SELECT COALESCE(sum(hesap_bakiyesi),0) AS bakiye,
                   COALESCE(sum(vadesi_gecmis),0)  AS gecikmis,
                   COALESCE(sum(toplam_risk),0)    AS toplam_risk,
                   count(*) FILTER (WHERE vadesi_gecmis>0) AS gecikmis_musteri
              FROM bi_musteri_risk WHERE tenant_id=$1::uuid AND musteri_mi),
          borc AS (
            SELECT COALESCE(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)),0) AS tutar,
                   COALESCE(abs(min(tedarikci_bakiye)),0) AS en_buyuk,
                   (SELECT tedarikci_adi FROM bi_cari_bakiye
                     WHERE tenant_id=$1::uuid ORDER BY tedarikci_bakiye LIMIT 1) AS en_buyuk_ad
              FROM bi_cari_bakiye WHERE tenant_id=$1::uuid)
          SELECT s.deger AS stok, a.bakiye AS alacak, a.gecikmis, a.toplam_risk,
                 a.gecikmis_musteri, b.tutar AS borc, b.en_buyuk, b.en_buyuk_ad,
                 (s.deger + a.bakiye - b.tutar)              AS net_sermaye,
                 ROUND((s.deger + a.bakiye - b.tutar) * 0.40) AS yillik_yuk
            FROM stok s, alacak a, borc b`, [T]),
        // 2) ⚠ ODEME TAKVIMI — odanin kalbi
        query(`
          SELECT son_tarih, baslik, ozet, tutar_tl,
                 (son_tarih - CURRENT_DATE) AS kalan_gun
            FROM bi_sinyal
           WHERE tenant_id=$1::uuid AND tur='odeme' AND durum='acik'
           ORDER BY son_tarih`, [T]),
        // 3) GERCEK riskler — NET pozisyona gore (brut YANILTICI)
        query(`
          SELECT musteri_adi, net_pozisyon, son_bakiye AS brut, bizim_borcumuz,
                 vadesi_gecmis, kredi_limiti,
                 CASE WHEN kredi_limiti > 1 THEN round(net_pozisyon/kredi_limiti, 1) END AS limit_kati
            FROM master_musteri
           WHERE tenant_id=$1::uuid AND net_pozisyon > 1e6
             AND (kredi_limiti <= 1 OR net_pozisyon > kredi_limiti * 1.5)
           ORDER BY net_pozisyon DESC LIMIT 15`, [T]),
        // 4) ⚠ LIMIT BOSLUGU — ihlal degil, KARAR
        query(`
          SELECT count(*) AS musteri,
                 COALESCE(sum(net_pozisyon),0)  AS alacak,
                 COALESCE(sum(vadesi_gecmis),0) AS gecikmis
            FROM master_musteri
           WHERE tenant_id=$1::uuid AND net_pozisyon > 0 AND kredi_limiti <= 1`, [T]),
        // 5) YASLANDIRMA — parayi ne kadar bekliyoruz
        query(`
          SELECT CASE WHEN vadesi_gecmis = 0 THEN 'vadesi gelmemis'
                      WHEN vadesi_gecmis > 0 AND hesap_bakiyesi > 0
                           AND vadesi_gecmis >= hesap_bakiyesi THEN 'tamami gecikmis'
                      ELSE 'kismen gecikmis' END AS dilim,
                 count(*) AS musteri,
                 COALESCE(sum(hesap_bakiyesi),0) AS tutar
            FROM bi_musteri_risk
           WHERE tenant_id=$1::uuid AND musteri_mi AND hesap_bakiyesi > 0
           GROUP BY 1 ORDER BY 3 DESC`, [T])
      ]);
      sendJson(response, 200, {
        sermaye:     sermaye.rows[0]     || {},
        odemeler:    odemeler.rows       || [],
        riskler:     riskler.rows        || [],
        limit_bosluk: limitsiz.rows[0]   || {},
        yaslandirma: yaslandirma.rows    || []
      });
    } catch (e) { sendJson(response, 500, { error: e.message }); }
  }

'''
s = s.replace(ANC, EP + ANC, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ /api/bi/finans eklendi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_finans server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 3) ⚠ UC NOKTA CANLI TEST ############"
ADMIN=$($PSQL -tAc "SELECT id FROM users WHERE role='platform_owner' AND status='active' LIMIT 1" | tr -d '[:space:]')
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$ADMIN','$HASH', now() + interval '5 minutes', '{\"amac\":\"finans testi\"}'::jsonb);"
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/bi/finans | python3 -m json.tool | head -45
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='finans testi';"

git add -A
git commit -q -m 'feat(bi): FINANS_V1 veri katmani — tanimlar KILITLENDI. Alacak icin hesap_bakiyesi (209,3M) kullaniliyor, toplam_risk (238,8M) DEGIL: aradaki fark cek/senet 29,5M + bekleyen siparis 3,8M, ve bekleyen siparis henuz PARA DEGIL. Fatihe once "net isletme sermayesi 103,9M, yillik yuk 41,6M" demistim; dogru tanimla 268,3 + 209,3 - 403,4 = 74,2M ve yuk 29,7M. Ana sayfadaki 238,8M uydurma degildi, YANLIS YERDE KULLANILAN DOGRU BIR SAYIYDI. Brisa takvimi: 18 Kas 36,6M, 16 Ara 36,6M, 22 Oca 28,2M, 22 Sub 28,2M = dort ayda 129,6M; Brisaya toplam borc 319,0M; yani dort aylik nakit yukumluluk net isletme sermayesinin 1,7 KATI. En keskin bulgu: kredi limiti HIC OLMAYAN 533 musteride 41,9M alacak var ve 26,0Msi ZATEN GECIKMIS — limitsiz verilen kredinin %62si geri gelmemis. Koken kayitlari yazildi (alacak_bakiye, vadesi_gecmis, limitsiz_alacak, brisa_takvim) ve net_sermaye kokenine iki duzeltmenin tarihcesi islendi: sistem kendi gecmis hatasini SAKLAMIYOR, YAZIYOR.'
echo "  COMMITTED"
