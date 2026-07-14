import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const DOSYA = 'server_container.mjs';
const YAZ   = process.argv.includes('--yaz');

if (!existsSync(DOSYA)) { console.error(`!! ${DOSYA} yok. cwd: ${process.cwd()}`); process.exit(1); }

let tuketen = '';
try {
  tuketen = execSync(
    `grep -rn "sermaye\\.kaynak\\|kaynak\\.alacak\\|kaynak\\.dso\\|kaynak\\.oran\\|dso_not" shells/ 2>/dev/null || true`,
    { encoding: 'utf8' }
  ).trim();
} catch { tuketen = ''; }

if (tuketen) {
  console.error('!! DUR. Frontend sermaye.kaynak nesnesini okuyor:\n' + tuketen);
  process.exit(1);
}
console.log('✓ On kosul: frontend sermaye.kaynak nesnesini tuketmiyor — silinebilir.\n');

const EDITS = [
{
  ad: '1. IKINCI KOKEN DEPOSU siliniyor',
  bul: String.raw`          // ⚠ SEFFAFLIK: her sayi kaynagini soylesin. Kullanici itiraz edebilmeli.
          kaynak: {
            stok   : 'bi_stok_anlik × son alış (bi_tedarikci_faturalari)',
            alacak : 'bi_musteri_risk.toplam_risk',
            dso    : 'alacak ÷ günlük ciro — tahsil EDİLMEYENİ de içerir',
            dso_not: '⚠ Tahsilat tablosundaki 26,9 gün SADECE ödeyenleri ölçüyor. 145,4M ödemeyen o ortalamada yok.',
            oran   : 'sermaye maliyeti %40/yıl'
          }`,
  koy: String.raw`          // ⚠ SEFFAFLIK: koken TEK yerden gelir -> GET /api/bi/koken?anahtar=...
          //   Burada elle yazilmis bir kaynak nesnesi VARDI. Alacak icin 'toplam_risk'
          //   diyordu; sorgu ise 14 Tem'den beri hesap_bakiyesi cekiyor. Ikinci bir koken
          //   deposu tutmak, duzeltmenin birini yakalayip otekini kacirmasi demektir —
          //   bu tam olarak oldu. Depo silindi; anahtarlar kaliyor, metin DB'de.
          koken: ['net_sermaye','alacak_bakiye','tedarikci_borcu','dso_gun','stok_gun','vadesi_gecmis']`
},
{
  ad: '2. 38.604 muhatap (koken tablosu 38.403 diyordu)',
  bul: String.raw`        risk: "bi_musteri_risk (38.604 muhatap)"`,
  koy: String.raw`        risk: "bi_musteri_risk — muhatap sayısı sorgu anında sayılır, sabit değildir"`
},
{
  ad: '3. DSO ~59-87 "gercek deger"',
  bul: String.raw`- Ödeme: Genellikle 30–90 gün vade (DSO ~59-87 gün gerçek değer); erken ödeme iskontosu mevcut`,
  koy: String.raw`- Ödeme: Genellikle 30–90 gün vade; erken ödeme iskontosu mevcut
- ⚠ DSO BU PROMPT'TA YAZILI DEĞİLDİR. Sorulursa sorgudan oku. Hafızandan DSO söyleme —
  burada bir DSO sayısı görürsen o sayı yanlıştır.`
},
{
  ad: '4. CCC araligi + uydurulmus hedef',
  bul: String.raw`   - Mevcut CCC aralığı: 19–119 gün (Haziran 2025–Mayıs 2026)
   - Hedef: CCC < 30 gün (veya negatif = nakit avantajlı)`,
  koy: String.raw`   - ⚠ CCC değeri ve aralığı BU PROMPT'TA YAZILI DEĞİLDİR — canlı hesaplanır, sorgudan oku
   - ⚠ KRB'nin TANIMLANMIŞ BİR CCC HEDEFİ YOKTUR. Hedef uydurma; sorulursa "tanımlanmamış" de.
     (Genel ilke: CCC düştükçe nakit serbestleşir. Ama bu genel bir ilkedir, KRB'nin hedefi değil.)`
},
{
  ad: '5. Makro sabitler + "DPO DSO-yu karsiliyor" SONUCU',
  bul: String.raw`- TCMB politika faizi: ~%42.5 (2026 itibarıyla yüksek faiz dönemi)
- TÜFE (yıllık): ~%32-38 (2025-2026 aralığı; gerçek değer bi_ekonomik_parametreler'den çekilir)
- Kur: USD ~₺46, EUR ~₺53 — ithal lastik maliyet belirsizliği yüksek
- Yüksek faiz ortamında stok tutmanın fırsat maliyeti = günlük faiz × stok değeri
- Vadeli satışlarda DSO artışı, yüksek faizde ciddi finansman maliyeti demektir
- KRB'nin DPO (~68-84 gün) genellikle DSO'yu (~59-87 gün) karşılamaktadır`,
  koy: String.raw`- ⚠ FAİZ, TÜFE, KUR: BU PROMPT'TA SAYI YOKTUR. Canlı değerler bi_ekonomik_parametreler
  tablosunda (görünüm: v_ekonomik_guncel). Sorulursa oradan oku; hafızandan oran/kur söyleme.
- Yüksek faiz ortamında stok tutmanın fırsat maliyeti = günlük faiz × stok değeri
- Vadeli satışlarda DSO artışı, yüksek faizde ciddi finansman maliyeti demektir
- ⚠ "DPO, DSO'yu karşılıyor" DİYE BİR BULGU YOKTUR. Bu prompt eskiden öyle diyordu ve YANLIŞTI.
  Nakit döngüsü hakkında hazır hüküm kurma. Bilinen: tedarikçi borcu net işletme sermayesinden
  BÜYÜKTÜR ve ödeme takvimi süreli. Konuşmadan önce DSO'yu, DPO'yu ve ödeme takvimini sorgudan çek.`
},
{
  ad: '6. Haziran 2026 = 121,76M (SAP iddiasi) + ISCILIK 16.996 satir',
  bul: String.raw`      '    Aksi halde \'İŞÇİLİK\' (16.996 satır, servis işçiliği) en çok satan MARKA, boş ebat da en çok satan EBAT görünür.\n' +
      '    Doğrulama: Haziran 2026 toplam ciro = 121,76 M TL (GM\'in SAP rakamıyla birebir).\n' +`,
  koy: String.raw`      '    Aksi halde \'İŞÇİLİK\' (servis işçiliği) en çok satan MARKA, boş ebat da en çok satan EBAT görünür.\n' +
      '    ⚠ CİRO DOĞRULAMASI İÇİN BU PROMPT\'TA SAYI YOKTUR. Bir dönemin cirosu sorulduğunda\n' +
      '    bi_satis_faturalari\'ndan O DÖNEMİ sorgula. Hafızandan ay cirosu söyleme.\n' +`
},
];

let metin = readFileSync(DOSYA, 'utf8');
const asil = metin;
const hata = [];

for (const e of EDITS) {
  const n = metin.split(e.bul).length - 1;
  if (n !== 1) { hata.push(`✗ ${e.ad}  — capa ${n} kez bulundu (1 olmali)`); continue; }
  metin = metin.replace(e.bul, e.koy);
  console.log(`✓ ${e.ad}`);
}

if (hata.length) {
  console.error('\n!! CAPALAR TUTMADI — DOSYAYA DOKUNULMADI:\n' + hata.join('\n'));
  process.exit(1);
}
if (metin === asil) { console.error('!! Hicbir sey degismedi.'); process.exit(1); }

if (!YAZ) { console.log('\n— DENEME. 6/6 capa tuttu. Yazmak icin: node yama_sabit_sayilar.mjs --yaz'); process.exit(0); }

const yedek = `${DOSYA}.yedek_${new Date().toISOString().replace(/[-:T]/g,'').slice(0,14)}`;
writeFileSync(yedek, asil);
writeFileSync(DOSYA, metin);
console.log(`\n✓ Yazildi. Yedek: ${yedek}`);
