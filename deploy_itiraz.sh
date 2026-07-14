#!/usr/bin/env bash
# ITIRAZ_V1 — her sayinin KOKENI + ITIRAZ mekanizmasi.
#
# ⚠ BUGUNUN DERSI: her buyuk hata bir ITIRAZLA bulundu, sorguyla degil.
#   "Kumho'dan memnun"                    -> marj kubu maliyeti yanlisti
#   "Otomotiv Lastikleri Tevzi = Continental" -> prim dagitimi cozuldu
#   "Mutaflar'a borcumuz da var"          -> 1 numarali alarm CURUDU,
#                                            'deger kaybediyorsun' tezi COKTU
#   Ucu de bir SQL sorgusuyla bulunamazdi.
#
# ⚠ ILKE: kullanici "bu yanlis" dediginde sistem sayiyi SAVUNMAZ.
#   Kaynagini acar, varsayimini gosterir, sinirini yazar, ve OGRENIR.
#
# ⚠ ITIRAZ EDILEN SAYI ISARETLENIR ve cozulene kadar ekranda "itiraz edildi"
#   etiketi tasir. Bir sayinin itiraz altinda oldugunu gizlemek, yalanin devami olur.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA — koken kaydi + itiraz ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
-- ⚠ KOKEN KAYDI: her sayinin nereden geldigi. KODDA DEGIL, VERIDE —
--   cunku degisecek, ve degistiginde kod dagitmak gerekmemeli.
CREATE TABLE IF NOT EXISTS bi_sayi_koken (
  anahtar     text PRIMARY KEY,          -- 'net_sermaye', 'brut_marj', 'stok_gun'...
  baslik      text NOT NULL,
  kaynak      text NOT NULL,             -- hangi tablo/dosya
  formul      text,                      -- nasil hesaplandi
  varsayim    text,                      -- neye dayaniyor
  sinir       text,                      -- ⚠ NE ICERMIYOR / nerede yanilir
  guven       text NOT NULL DEFAULT 'orta' CHECK (guven IN ('yuksek','orta','dusuk','yok')),
  guncelleme  timestamptz NOT NULL DEFAULT now()
);

-- ⚠ ITIRAZ: sayi savunulmaz, kaydedilir.
CREATE TABLE IF NOT EXISTS bi_itiraz (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL,
  anahtar      text NOT NULL,
  gosterilen   numeric,                  -- itiraz aninda ekranda ne yaziyordu
  kullanici    text,
  gerekce      text,                     -- kullanici NE dedi (en degerli alan)
  durum        text NOT NULL DEFAULT 'acik' CHECK (durum IN ('acik','dogrulandi','reddedildi','cozuldu')),
  olusma       timestamptz NOT NULL DEFAULT now(),
  cozum        text,
  cozum_zamani timestamptz
);
CREATE INDEX IF NOT EXISTS idx_itiraz_acik ON bi_itiraz(tenant_id, anahtar) WHERE durum='acik';
SQL
echo "  ✅ bi_sayi_koken + bi_itiraz"

echo
echo "############ 2) KOKEN KAYITLARI — bugun ogrendiklerimiz ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO bi_sayi_koken (anahtar, baslik, kaynak, formul, varsayim, sinir, guven) VALUES

('net_sermaye', 'Net işletme sermayesi',
 'bi_stok_anlik × son alış · bi_musteri_risk · bi_cari_bakiye',
 'stok + alacak − tedarikçi borcu',
 'Sermaye maliyeti %40/yıl. Stok, son alış faturasıyla değerlendi.',
 '⚠ Bu sayı 13 Temmuz''e kadar YANLIŞTI: tedarikçi borcu (403,4M) hiç sayılmıyordu, "bağlı sermaye 507,3M" gösteriliyordu. Düzeltildi.',
 'yuksek'),

('tedarikci_borcu', 'Tedarikçi borcu',
 'bi_cari_bakiye (account balance dosyası)',
 'Account Balance kolonunun negatif toplamı',
 'ERP''nin cari bakiyesi doğru.',
 '⚠ Bu dosya AYLARDIR yüklenmemişti. Brisa tek başına 318,95M — ödeme takvimi 18 Kas · 16 Ara · 22 Oca · 22 Şub. Finansman süreli.',
 'yuksek'),

('brut_marj', 'Lastik ticareti brüt marjı',
 'bi_satis_faturalari (ciro) · bi_stok_hareket.birim_maliyet (SMM)',
 'ciro − SMM, satış hareketlerinden (SATIS_SEVK + SATIS_FATURA)',
 'ERP''nin kaydettiği birim maliyet doğru. Adet mutabakatı %102.',
 '⚠ ALT SINIR: ERP maliyeti = FATURA maliyeti = prim ÖNCESİ. Prim (40,5M) ciro olarak faturalanıyor.
⚠ SADECE lastik ticareti. Kaplama ve servis HARİÇ — maliyet yapısı farklı.
⚠⚠ MARKA BAZINDA GÜVENİLMEZ: ERP maliyeti alış faturasından markadan markaya −%40 ile +%48 sapıyor (Sailun −%40, Dayton +%48, Continental %1). Marka kırılımı EKRANDA YOK, çünkü yanlış olurdu.',
 'orta'),

('musteri_risk', 'Müşteri riski',
 'bi_cari_bakiye.net_pozisyon',
 'müşteri bakiyesi + tedarikçi bakiyesi (karşılıklı mahsup)',
 'ERP''nin "Bağlı Müşteri Kodu" eşlemesi doğru.',
 '⚠ Bu sayı BRÜT alacağa bakıyordu ve YANILTICIYDI. MUTAFLAR brüt 47,6M görünüyordu; KRB''nin ona borcu 46,6M — NET 1,0M, tam limitte. Yönetilen mahsuplaşma. Sistem yönetilen bir ilişki hakkında her gün bağırıyordu.',
 'yuksek'),

('stok_gun', 'Stok devir günü',
 'bi_stok_anlik × son alış ÷ günlük SMM',
 'stok değeri / (yıllık SMM ÷ 365)',
 'SMM, satış hareketlerinden. İç akış (KRB şube transferleri) elendi.',
 '⚠ Önce ciro üzerinden hesaplanıyordu (131 gün) — yaklaşıktı. Şimdi maliyet üzerinden (muhasebe standardı).',
 'yuksek'),

('dso_gun', 'Tahsilat süresi',
 'bi_musteri_risk.toplam_risk ÷ günlük ciro',
 'alacak / (yıllık ciro ÷ 365)',
 'Tahsil edilmemiş alacağı da içerir.',
 '⚠ Tahsilat tablosu 26,9 gün gösteriyordu — YALANDI: sadece ÖDEYENLERİ ölçüyordu. 145,4M ödemeyen o ortalamada hiç yoktu (hayatta kalan yanlılığı).',
 'yuksek'),

('olu_stok', 'Ölü stok',
 'bi_stok_anlik + bi_satis_faturalari',
 '1 yıldır hiç satılmamış SKU''ların stok değeri',
 'Satış kaydı yoksa gerçekten satılmamıştır.',
 '⚠ Sezonluk ürünler yanlış işaretlenebilir. Ağustosta kış lastiği "satılmıyor" görünür ama normaldir.',
 'orta')

ON CONFLICT (anahtar) DO UPDATE SET
  kaynak=EXCLUDED.kaynak, formul=EXCLUDED.formul, varsayim=EXCLUDED.varsayim,
  sinir=EXCLUDED.sinir, guven=EXCLUDED.guven, guncelleme=now();

SELECT anahtar, baslik, guven, left(sinir, 50) AS sinir_ozet FROM bi_sayi_koken ORDER BY anahtar;
SQL
echo "  ✅ 7 sayinin kokeni kayitli"

echo
echo "############ 3) ENDPOINT ############"
cp server_container.mjs server_container.mjs.bak_itiraz
python3 - <<'PY' || exit 1
import pathlib, sys, re
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "ITIRAZ_V1" in s: sys.exit("ZATEN YAMALI")

EP = r'''
  // ── ITIRAZ_V1 ─────────────────────────────────────────────────────────────
  // ⚠ Kullanici "bu yanlis" dediginde sistem sayiyi SAVUNMAZ.
  //   Kaynagini acar, varsayimini gosterir, SINIRINI yazar, ve ogrenir.
  //   Bugunun her buyuk hatasi bir ITIRAZLA bulundu, sorguyla degil.

  // GET /api/bi/koken?anahtar=net_sermaye
  if (request.method === 'GET' && url.pathname === '/api/bi/koken') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const anahtar = url.searchParams.get('anahtar') || '';
      const [k, it] = await Promise.all([
        query(`SELECT * FROM bi_sayi_koken WHERE anahtar=$1`, [anahtar]),
        // ⚠ ACIK ITIRAZ VARSA GOSTER. Gizlemek yalanin devami olur.
        query(`SELECT gerekce, kullanici, olusma, durum FROM bi_itiraz
                WHERE tenant_id=$1::uuid AND anahtar=$2 AND durum='acik'
                ORDER BY olusma DESC LIMIT 3`, [session.tenantId, anahtar])
      ]);
      sendJson(response, 200, {
        koken: k.rows[0] || null,
        acik_itiraz: it.rows,
        // ⚠ Kaynagi olmayan sayi = uydurulmus sayi.
        uyari: k.rows[0] ? null : 'Bu sayının kökeni kayıtlı değil. Güvenilirliği bilinmiyor.'
      });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }

  // POST /api/bi/itiraz  { anahtar, gosterilen, gerekce }
  if (request.method === 'POST' && url.pathname === '/api/bi/itiraz') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const body = await readJson(request);
      if (!body.anahtar || !String(body.gerekce||'').trim()) {
        sendJson(response, 400, { error: 'anahtar ve gerekçe zorunlu' }); return;
      }
      const r = await query(`
        INSERT INTO bi_itiraz (tenant_id, anahtar, gosterilen, kullanici, gerekce)
        VALUES ($1::uuid, $2, $3, $4, $5) RETURNING id, olusma`,
        [session.tenantId, body.anahtar, body.gosterilen || null,
         session.email || session.userId || 'bilinmiyor', String(body.gerekce).trim()]);

      // ⚠ Itiraz Veri Sagligi'na da dusuyor — kaybolmasin.
      await query(`
        INSERT INTO bi_sinyal (tenant_id, tur, anahtar, baslik, ozet, tutar_tl, oda, eylem_var, durum)
        VALUES ($1::uuid, 'itiraz', $2, $3, $4, 0, 'veri', true, 'acik')
        ON CONFLICT DO NOTHING`,
        [session.tenantId, 'itiraz:' + body.anahtar,
         'İtiraz: ' + body.anahtar,
         String(body.gerekce).slice(0,200)]).catch(()=>{});

      sendJson(response, 200, {
        ok: true, id: r.rows[0].id,
        // ⚠ SAVUNMA YOK. Kabul ve eylem.
        mesaj: 'Not aldım. Bu sayının kaynağını işaretledim — Veri Sağlığı odasına düştü. Neyin yanlış olduğunu anlayana kadar yanında "itiraz edildi" yazacak.'
      });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }

  // GET /api/bi/itiraz/acik — hangi sayilara itiraz var (ekranda etiket icin)
  if (request.method === 'GET' && url.pathname === '/api/bi/itiraz/acik') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const r = await query(`
        SELECT anahtar, count(*)::int AS adet, max(olusma) AS son
          FROM bi_itiraz WHERE tenant_id=$1::uuid AND durum='acik'
         GROUP BY anahtar`, [session.tenantId]);
      sendJson(response, 200, { itirazlar: r.rows });
    } catch(e) { sendJson(response, 500, { error: e.message }); }
  }
'''

anc = re.search(r"\n\s*//\s*ANA_API_V1", s)
assert anc, "ANA_API_V1 anchor yok"
i = anc.start()
s = s[:i] + "\n" + EP + s[i:]
p.write_text(s, encoding="utf-8")
print("  ✅ /api/bi/koken · /api/bi/itiraz · /api/bi/itiraz/acik")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_itiraz server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
for E in /api/bi/koken /api/bi/itiraz/acik; do
  printf "  %-24s -> HTTP %s\n" "$E" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080$E)"
done
echo "  (401 = yasiyor, oturum gerekiyor · 404 = YOK)"

git add -A
git commit -q -m 'feat(itiraz): ITIRAZ_V1 — her sayinin KOKENI + itiraz mekanizmasi. BUGUNUN DERSI: her buyuk hata bir ITIRAZLA bulundu, sorguyla degil. "Kumho dan memnun" -> marj kubu maliyeti yanlisti. "Otomotiv Lastikleri Tevzi = Continental" -> prim dagitimi cozuldu. "Mutaflar a borcumuz da var" -> 1 numarali alarm curudu ve deger kaybediyorsun tezi cokti. Ucu de bir SQL sorgusuyla bulunamazdi. ILKE: kullanici "bu yanlis" dediginde sistem sayiyi SAVUNMAZ; kaynagini acar, varsayimini gosterir, SINIRINI yazar, ogrenir. bi_sayi_koken: her sayinin kaynagi/formulu/varsayimi/SINIRI ve guven seviyesi — kodda degil VERIDE, degistiginde kod dagitmak gerekmesin. bi_itiraz: itiraz kaydi + gerekce (en degerli alan). Itiraz edilen sayi ISARETLENIR ve cozulene kadar ekranda "itiraz edildi" etiketi tasir — bir sayinin itiraz altinda oldugunu gizlemek yalanin devami olur. 7 sayinin kokeni kayitli, ve her birinin SINIRI bugun ogrendiklerimizle yazildi (net_sermaye: 13 Temmuz e kadar tedarikci borcu sayilmiyordu; musteri_risk: brut alacaga bakiyordu, Mutaflar mahsuplasmasini kaciriyordu; brut_marj: marka bazinda GUVENILMEZ, ERP maliyeti alis faturasindan -%40 ile +%48 sapiyor).'
echo "  COMMITTED"
