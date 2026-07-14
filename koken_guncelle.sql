BEGIN;

\echo '--- ONCE'
SELECT anahtar, (kaynak ~ '[0-9]') AS kaynakta, (varsayim ~ '[0-9]') AS varsayimda, (sinir ~ '[0-9]') AS sinirda
  FROM bi_sayi_koken ORDER BY anahtar;

-- 1. dso_gun — 14 Tem duzeltmesi buraya ISLENMEMISTI (SQL hesap_bakiyesi cekiyor, koken toplam_risk diyor)
UPDATE bi_sayi_koken SET
  kaynak = 'bi_musteri_risk.hesap_bakiyesi ÷ günlük ciro (bi_satis_faturalari, son 365 gün)',
  formul = 'alacak ÷ (yıllık ciro ÷ 365)',
  sinir  = '⚠ ALACAK BACAĞI hesap_bakiyesi''dir — toplam_risk DEĞİL. Bekleyen sipariş ve çek/senet DIŞARIDA: henüz para değiller.' || E'\n' ||
           '⚠ Tahsilat tablosu çok daha kısa bir süre gösteriyordu — YALANDI: sadece ÖDEYENLERİ ölçüyordu. Ödemeyenler o ortalamada hiç yoktu (hayatta kalan yanlılığı).' || E'\n' ||
           '⚠ Bu DSO tahsil EDİLMEYENİ de içerir. Yüksek olması, doğru olduğu anlamına gelir.',
  guncelleme = now()
WHERE anahtar = 'dso_gun';

-- 2. alacak_bakiye — "12 Tem, 38.403 müşteri" curur
UPDATE bi_sayi_koken SET
  kaynak = 'bi_musteri_risk.hesap_bakiyesi — kaynak dosya: accountriskreport. Müşteri sayısı ve dosya tarihi SORGUDAN gelir, burada yazılı değildir.',
  guncelleme = now()
WHERE anahtar = 'alacak_bakiye';

-- 3. tedarikci_borcu — "Brisa 318,95M" bugunku durumu iddia ediyor
UPDATE bi_sayi_koken SET
  sinir = '⚠ Bu dosya AYLARDIR yüklenmemişti. Yüklenme tarihini kontrol et.' || E'\n' ||
          '⚠ Borç TEK BİR TEDARİKÇİDE yoğunlaşmıştır. Tutar ve payı için bi_cari_bakiye''den sorgula — burada yazılı değildir.' || E'\n' ||
          '⚠ Ödeme takvimi SÜRELİDİR ve ELLE girilmiştir: bkz. köken anahtarı ''brisa_takvim''. ERP''den türetilmiyor.' || E'\n' ||
          '⚠ Tedarikçi borcu, net işletme sermayesinden BÜYÜKTÜR. Bu bir oran değil, bir DURUM.',
  guncelleme = now()
WHERE anahtar = 'tedarikci_borcu';

-- 4. brut_marj — "%102" curur
UPDATE bi_sayi_koken SET
  varsayim = 'ERP''nin kaydettiği birim maliyet. Adet mutabakat oranı SORGU ANINDA hesaplanır (maliyet ve ciro aynı malı ölçmeli).',
  sinir = '⚠ ALT SINIR: ERP maliyeti FATURA maliyetidir, tedarikçi primi ÖNCESİDİR. Prim dahil edilirse efektif marj daha yüksektir.' || E'\n' ||
          '⚠ MARKA BAZINDA GÜVENİLMEZ: ERP''nin hareketli ortalama maliyeti markadan markaya sapıyor. Toplamda tutuyor, marka kırılımında tutmuyor — bu yüzden marka bazlı marj GÖSTERİLMEZ.' || E'\n' ||
          '⚠ Küp her ERP yüklemesinde yeniden kurulur. Mutabakat kapısı yeni küpü MEVCUT küple karşılaştırır (sabit eşikle değil) — ani sıçrama kurulumu DURDURUR.',
  guncelleme = now()
WHERE anahtar = 'brut_marj';

-- 5. musteri_risk — MUTAFLAR DERSI kalir, TUTARLARI gider
UPDATE bi_sayi_koken SET
  sinir = '⚠ Bu sayı önce BRÜT alacağa bakıyordu ve YANILTICIYDI.' || E'\n' ||
          '⚠ KARŞILIKLI MAHSUPLAŞMA: KRB''nin kendisinin de borçlu olduğu müşterilerde (ör. MUTAFLAR) brüt alacak limitin katları görünür, ama NET pozisyon limit içinde olabilir. Sistem yönetilen bir ilişki hakkında her gün bağırıyordu — yanlış alarm, gerçek alarmı boğar.' || E'\n' ||
          '⚠ Güncel brüt/net tutarlar için bi_cari_bakiye.net_pozisyon''a bak. Burada yazılı DEĞİLDİR.' || E'\n' ||
          '⚠ ERP net pozisyonu ZATEN hesaplıyor. Yeniden hesaplama — tedarikci_bakiye NEGATİFTİR; işareti kaçırırsan borcu alacağa eklersin.',
  guncelleme = now()
WHERE anahtar = 'musteri_risk';

-- 6. net_sermaye — %40 bi_ayar'da yasiyor, kokende sabit yazmasin
UPDATE bi_sayi_koken SET
  varsayim = 'Sermaye maliyeti bi_ayar.sermaye_maliyeti_pct''ten okunur — ölçülmüş bir gerçek DEĞİL, bir VARSAYIMDIR. Stok, son alış faturasıyla değerlendi.',
  sinir = '⚠ SERMAYE MALİYETİ ÖLÇÜLMEMİŞTİR. KRB''nin gerçek borçlanma maliyeti sorulmadı. Ayardan değiştirilebilir; ekranda "varsayım" etiketiyle gösterilir.' || E'\n' ||
          '⚠ ALACAK BACAĞI hesap_bakiyesi''dir, toplam_risk değil — bekleyen sipariş henüz para değil.' || E'\n' ||
          '⚠ Bu sayı tedarikçi borcu hiç sayılmadan hesaplanıyordu ve "değer kaybediyorsun" tezi onun üstüne kurulmuştu. İkisi de yanlıştı.',
  guncelleme = now()
WHERE anahtar = 'net_sermaye';

-- brisa_takvim / stok_gun / olu_stok / vadesi_gecmis / limitsiz_alacak: DOKUNULMADI.
--   brisa_takvim -> rakamlari elle girilmis AMA bunu kendi sinirinde ILAN EDIYOR. Yalan degil, sinir.
--   stok_gun     -> "(131 gun)" gecmis bir hatayi anlatiyor: DERS, kalir.

\echo '--- SONRA'
SELECT anahtar, (kaynak ~ '[0-9]') AS kaynakta, (varsayim ~ '[0-9]') AS varsayimda, (sinir ~ '[0-9]') AS sinirda
  FROM bi_sayi_koken ORDER BY anahtar;

\echo '--- KALAN IDDIA RAKAMI (brisa_takvim haric — o ilan edilmis)'
SELECT anahtar FROM bi_sayi_koken
 WHERE anahtar <> 'brisa_takvim'
   AND (kaynak ~ '[0-9]{2,}[.,][0-9]' OR sinir ~ '[0-9]{2,}[.,][0-9]'
        OR varsayim ~ '[0-9]{2,}[.,][0-9]' OR formul ~ '[0-9]{2,}[.,][0-9]');

COMMIT;
