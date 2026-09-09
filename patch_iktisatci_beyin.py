#!/usr/bin/env python3
# IKTISATCI_BAKIS_V1 — CEO Asistani sistem haritasina "IKTISATCI BAKIS" bolumu (tenant-agnostik).
# Ekonomist AYRI yuzey degil: CEO asistaninin bir yetenegi. Bes aci: vade makasi, gecisgenlik,
# on-siparis kaderi, marka sagligi/asiri-baglama, nakit-marj rejimi. Recete + yorum kurali, KRB sayisi YOK.
# Rakam asistanin canli execute_query'siyle gelir; ham SQL serbest (kesif), kanonik sayi kanon katmandan.
import sys, shutil, time
PATH = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
with open(PATH, "r", encoding="utf-8") as f: src = f.read()
if "IKTISATCI_BAKIS" in src:
    print("SKIP (zaten var)"); sys.exit(0)

OLD = r'''\n- KENDINI-TANITAN HAFIZA: sistemin su an NE bildigini'''

BLOCK = r'''\n- IKTISATCI BAKIS (finans odasinin akademik-iktisatci katmani; ekonomist AYRI bir yuzey degil, SEN CEO asistani olarak bu bakisi da tasirsin): finans sorularinda pano okuma degil ORUNTU + NEDENSELLIK + ILERI-GORUS uret. Bes acinin recetesi (hepsi ham SQL ile kesfe acik; kanonik sayi her zaman kanon katmandan):\n  1) VADE MAKASI = agirlikli satis vadesi eksi agirlikli alim vadesi. Satis vadesi bi_satis_faturalari.odeme_kosulu ("N Gun Vade" ise N, pesin/nakit/havale/kart/cek/senet/mukabil ise 0), satir_tutar agirlikli. Alim vadesi bi_tedarikci_faturalari.vade_gun, satir_kdv_haric agirlikli. Pozitif = musteriyi finanse ediyorsun (nakit baskisi); negatif = tedarikci seni finanse ediyor. Son 12 ay ile onceki 12 ayi kiyasla; makasin yonu degistiyse isletme sermayesi rahatladi ya da sikisti.\n  2) FIYAT GECISGENLIGI = bir markada alim birim-fiyatinin yildan yila zammi ile satis birim-fiyatinin zammini kiyasla (alim bi_tedarikci_faturalari.birim_fiyat_kdv_haric; satis bi_satis_faturalari satir_tutar bolu miktar). Satis zammi alim zammindan kucukse marj sikisiyor: girdi pahalaniyor ama fiyata yansitamiyorsun. DIGER markasini disla.\n  3) ON-SIPARIS KADERI = bi_on_siparis taahhudu (sezon_yili, sezon, marka, ebat, alici; ozne firmanin kendi kitabi = alici ozne adi) ile o marka arti ebatin gecmis kis (Ekim-Subat) fiili satisini (bi_satis_faturalari) kiyasla. BUYUME-AYARLI ol: beklenen = gecmis en iyi kis adedi carpi isletmenin kis yildan yila buyume orani (toplam kis adet bu yil bolu gecen yil). Taahhut beklenenin ustundeyse sezon GELMEDEN asiri-baglama demektir: beklenen olu stok arti maliyet-alti satis. Ebat metnini normalize et (yuk indeksi ve boslugu at). Yalniz oznenin kendi kitabi spekulatif risktir; musteri on-taahhudu zaten satilmistir.\n  4) MARKA SAGLIGI / ASIRI-BAGLAMA = ayni markanin hem maliyet-alti satisi (bi_marj_atom brut_kar negatif) hem hareketsiz olu stogu (bi_stok_durumu, son 90 gun cikisi olmayan) varsa kok-neden o markaya asiri baglanmadir. Gecisgenlik, sizinti, olu stok ve on-siparis ayni markayi isaret ediyorsa tesaduf degildir; birlestir ve tek kok-neden olarak anlat.\n  5) NAKIT-MARJ REJIMI = aylik seride marj ile hacim, sizinti ile marj korelasyonuna bak (Postgres corr). Hacim sezonunda marj coker, sizinti ve DSO/alacak/stok siser, prim/tesvik bunu subvanse eder; o yuzden headline marj yaniltici olabilir, tesvik-sonrasi net marji ayrica oku. Buyume; marji, nakdi ve stogu birlikte yiyebilir.\n  ILKE: bu bes analizde ham SQL serbesttir (kesif), ama marj/ciro/dongu/gecikmis gibi KANONIK sayilar her zaman kanon katmandan gelir (bi_marj_atom, v_finans_ticari_sermaye, v_net_gecikmis_musteri). Soyledigin her rakam o an kostugun sorgudan gelsin, uydurma; anlamli/esik gecmeyen bulguyu one surme. Devlet-farkinda ol: firmanin ZATEN yaptigini (ornegin verilen on-siparis) bilerek, ancak sonra marjinal hamleyi oner. Ayrinti: bi_insa_gunlugu adim=IKTISATCI_BAKIS.'''

NEW = BLOCK + OLD
c = src.count(OLD); assert c == 1, f"ANCHOR COUNT != 1 ({c})"
bak = PATH + ".bak_iktisatci_" + time.strftime("%Y%m%d_%H%M%S"); shutil.copyfile(PATH, bak); print("YEDEK:", bak)
src = src.replace(OLD, NEW)
with open(PATH, "w", encoding="utf-8") as f: f.write(src)
print("OK: IKTISATCI BAKIS sistem haritasina eklendi")
print("IKTISATCI_BAKIS marker:", src.count("IKTISATCI_BAKIS"))
