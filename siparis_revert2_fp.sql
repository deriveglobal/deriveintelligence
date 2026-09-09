INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_SIPARIS_REVERT_V2',
 'Finans oda "Sipariş bekleyen" kartinin UI kalintilari temizlendi: (1) ekranda gorunen kod yorumu "/* FINANS_SIPARIS_REVERT_V1 */" -> HTML yorumu (kullaniciya sizmaz), (2) body''den ic tablo.kolon jargonu (bi_stok_durumu.siparis_miktar) kaldirildi, (3) meta "Nasil: siparis_miktar·bi_stok_durumu" -> "kaynak dogrulaniyor" ve "Donem: baglanacak" -> "—" (vaat yok), (4) olu client cagrisi _setSmall(gSiparis) kaldirildi.',
 'Fatih ekran goruntusu: V1 revert''inde kod yorumu musteri ekranina sizmisti + meta satirlari hala ham kolon adini ve "baglanacak" vaadini gosteriyordu -> urun sesine aykiri (vaat yok, jargon yok). Kart artik: "—" [dogrulaniyor] + "kaynagin ERP anlami dogrulanana kadar baglanmadi" + Nasil: kaynak dogrulaniyor + Donem: — + Neden: Gelen stok ek sermaye baglar.',
 '{"kart":"siparis_bekleyen","aksiyon":"UI temizlik","fix":["gorunur_marker->html_yorum","tablo.kolon_jargonu_kaldirildi","vaat_baglanacak->tire","olu_gSiparis_cagrisi_kaldirildi"],"marker":"FINANS_SIPARIS_REVERT_V2"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_SIPARIS_REVERT_V2');
SELECT adim, ts::timestamptz(0) FROM bi_insa_gunlugu WHERE adim='FINANS_SIPARIS_REVERT_V2';
