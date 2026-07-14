#!/usr/bin/env bash
# NET_UI_V1 — ana sayfayi DUZELT. Yanlis tez ekrandan kalkiyor.
#
# ⚠ SILINEN: 'Kar ediyorsun, deger kaybediyorsun' (96M kar vs 203M yuk)
#   YANLISTI. Tedarikci borcunu (403,4M) saymamistim.
#   Gercek: net isletme sermayesi 103,9M · yillik yuk 41,6M · lastik brut kar ~96M
#   -> KRB DEGER YARATIYOR.
#
# ⚠ YERINE GELEN GERCEK SORU:
#   Isletme sermayesini BRISA finanse ediyor: 318,95M borc.
#   Odeme takvimi: 18 Kas · 16 Ara · 22 Oca · 22 Sub.
#   Asil soru 'sermayem neden bagli?' DEGIL — 'Kasim'da 318M'yi odeyecek nakdim var mi?'
#
# ⚠ RISK: brut alacak -> NET POZISYON.
#   MUTAFLAR brut 47,6M ama net 1,0M (limit 1,0M) — YONETILEN MAHSUPLASMA.
#   Sistem yonetilen bir iliski hakkinda her gun bagiriyordu.
#   GERCEK riskler: YEDI OTO net 30,5M (2,0 kat) · TOROS 9,5M (47,5 kat)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SQL ONCE ############"
$PSQL -v ON_ERROR_STOP=1 -c "
SET app.current_tenant_id='$TEN';
SELECT round(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0))/1e6,1) AS borc_M,
       count(*) FILTER (WHERE net_pozisyon > 1e6) AS net_riskli
  FROM bi_cari_bakiye WHERE tenant_id='$TEN'::uuid;" >/dev/null || { echo "❌ SQL"; exit 1; }
echo "  ✅"

echo
echo "############ 2) ENDPOINT ############"
cp server_container.mjs server_container.mjs.bak_netui
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "NET_UI_V1" in s: sys.exit("ZATEN YAMALI")

# sermaye sorgusuna TEDARIKCI BORCU ekle
eski = """          alacak AS (
            SELECT COALESCE(sum(toplam_risk),0)    AS risk,"""
assert eski in s, "alacak CTE anchor yok"
yeni = """          -- ⚠ NET_UI_V1 — TEDARIKCI BORCU. Bunu saymadigim icin 'bagli sermaye 507,3M'
          --   demis, 'deger kaybediyorsun' tezi kurmustum. IKISI DE YANLISTI.
          borc AS (
            SELECT COALESCE(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)),0) AS tutar,
                   COALESCE(abs(min(tedarikci_bakiye)),0) AS en_buyuk,
                   (SELECT tedarikci_adi FROM bi_cari_bakiye
                     WHERE tenant_id=$2::uuid ORDER BY tedarikci_bakiye LIMIT 1) AS en_buyuk_ad
              FROM bi_cari_bakiye WHERE tenant_id=$2::uuid),
          alacak AS (
            SELECT COALESCE(sum(toplam_risk),0)    AS risk,"""
s = s.replace(eski, yeni, 1)

eski2 = """          SELECT s.deger AS stok, s.taahhutlu, s.serbest, s.adet,
                 a.risk AS alacak, a.gecikmis, a.gecikmis_musteri, a.limit_asan,
                 c.gunluk AS gunluk_ciro,
                 (s.deger + a.risk)                                  AS bagli_sermaye,"""
assert eski2 in s, "SELECT anchor yok"
yeni2 = """          SELECT s.deger AS stok, s.taahhutlu, s.serbest, s.adet,
                 a.risk AS alacak, a.gecikmis, a.gecikmis_musteri, a.limit_asan,
                 c.gunluk AS gunluk_ciro,
                 b.tutar AS tedarikci_borcu, b.en_buyuk AS en_buyuk_borc, b.en_buyuk_ad,
                 -- ⚠ NET isletme sermayesi. Brut degil.
                 (s.deger + a.risk - b.tutar)                        AS net_sermaye,
                 (s.deger + a.risk)                                  AS bagli_sermaye,"""
s = s.replace(eski2, yeni2, 1)

eski3 = """                 ROUND((s.deger + a.risk) * 0.40)                    AS sermaye_yuku
            FROM stok s, alacak a, ciro c`, [T])"""
assert eski3 in s, "sermaye_yuku anchor yok"
yeni3 = """                 ROUND((s.deger + a.risk - b.tutar) * 0.40)         AS sermaye_yuku
            FROM stok s, alacak a, ciro c, borc b`, [T, T])"""
s = s.replace(eski3, yeni3, 1)

# ⚠ NET RISK sorgusu ekle
eski4 = """        // 5) VARDIYA_V1"""
assert eski4 in s, "vardiya anchor yok"
yeni4 = """        // 7) NET_UI_V1 — ⚠ RISK, BRUT ALACAGA DEGIL NET POZISYONA gore.
        //   MUTAFLAR brut 47,6M ama net 1,0M (limit 1,0M): YONETILEN MAHSUPLASMA.
        //   alacak 47.556.434 - borc 46.555.721 = 1.000.714. Tesadüf degil.
        //   Sistem yonetilen bir iliski hakkinda HER GUN bagiriyordu.
        query(`
          SELECT b.tedarikci_adi AS musteri, b.musteri_kodu,
                 b.musteri_bakiye   AS brut_alacak,
                 b.tedarikci_bakiye AS krb_borcu,
                 b.net_pozisyon     AS net,
                 r.kredi_limiti,
                 CASE WHEN r.kredi_limiti > 0
                      THEN ROUND(b.net_pozisyon / r.kredi_limiti, 1) END AS net_kat
            FROM bi_cari_bakiye b
            LEFT JOIN bi_musteri_risk r ON r.tenant_id=b.tenant_id AND r.muhatap_kodu=b.musteri_kodu
           WHERE b.tenant_id=$2::uuid AND b.net_pozisyon > 2e6
           ORDER BY b.net_pozisyon DESC LIMIT 6`, [T, T]),

        // 5) VARDIYA_V1"""
s = s.replace(eski4, yeni4, 1)

s = s.replace("const [sermaye, kor, sinyaller, odemeler, marj, vardiya] = await Promise.all([",
              "const [sermaye, kor, sinyaller, odemeler, marj, netrisk, vardiya] = await Promise.all([", 1)

# response'a ekle
eski5 = """          gecikmis     : Number(s.gecikmis||0),"""
assert eski5 in s, "gecikmis anchor yok"
yeni5 = """          gecikmis     : Number(s.gecikmis||0),
          // ⚠ NET_UI_V1
          tedarikci_borcu : Number(s.tedarikci_borcu||0),
          en_buyuk_borc   : Number(s.en_buyuk_borc||0),
          en_buyuk_ad     : s.en_buyuk_ad || '',
          net_sermaye     : Number(s.net_sermaye||0),"""
s = s.replace(eski5, yeni5, 1)

eski6 = """        kararlar : sinyaller.rows,"""
assert eski6 in s, "kararlar anchor yok"
yeni6 = """        net_risk : netrisk.rows,
        kararlar : sinyaller.rows,"""
s = s.replace(eski6, yeni6, 1)

p.write_text(s, encoding="utf-8")
print("  ✅ endpoint: tedarikci borcu + net risk")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_netui server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ON YUZ ############"
cp shells/bi.js shells/bi.js.bak_netui
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "NET_UI_V1" in s: sys.exit("ZATEN YAMALI")

# SERMAYE KARTI -> net
eski = """    h += '<div class="kart dn" data-sor="' + esc('507M bağlı sermayenin kırılımını ver ve nasıl azaltırız?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Bağlı sermaye</div>'
       +   '<div class="n n-buyuk" style="margin:6px 0">' + _M(s.bagli) + '</div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">stok ' + _M(s.stok) + ' · alacak ' + _M(s.alacak) + '</div>'
       + '</div>';"""
assert eski in s, "sermaye kart anchor yok"
yeni = """    /* NET_UI_V1 — ⚠ TEDARIKCI BORCU ARTIK GORUNUYOR. Onceki hali 'bagli sermaye 507,3M'
       diyordu; borcu (403,4M) hic saymamistim. Gercek: NET 103,9M. */
    h += '<div class="kart dn" data-sor="' + esc('Net işletme sermayesi 104M. Brisa 319M borcu Kasım-Şubat ödenecek. Bu nakdi nereden bulacağız?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Net işletme sermayesi</div>'
       +   '<div class="n n-buyuk" style="margin:6px 0">' + _M(s.net_sermaye) + '</div>'
       +   '<div class="satir" style="padding:1px 0"><span>stok</span><span class="n">' + _M(s.stok) + '</span></div>'
       +   '<div class="satir" style="padding:1px 0"><span>alacak</span><span class="n">' + _M(s.alacak) + '</span></div>'
       +   '<div class="satir" style="padding:1px 0"><span>tedarikçi borcu</span><span class="n d-yesil">−' + _M(s.tedarikci_borcu) + '</span></div>'
       + '</div>';"""
s = s.replace(eski, yeni, 1)

# YILLIK YUK kartinin altina aciklama
s = s.replace("""       +   '<div style="font-size:12px;color:var(--tx-2)">%40 / yıl</div>'""",
              """       +   '<div style="font-size:12px;color:var(--tx-2)">%40 / yıl · net üzerinden</div>'""", 1)

# ⚠ YANLIS TEZI SIL, yerine GERCEK SORUYU koy
eski2 = """      // ⚠ ASIL CUMLE: karli ama deger kaybediyor
      const brutToplam = (mj.brut_kar||0) + (mj.prim||0);
      const yuk = Number(s.yillik_yuk||0);
      if (yuk > 0) {
        h += '<div class="kart kart-karar" style="margin-bottom:24px">';
        h += '<div style="font-size:15px;margin-bottom:8px">Kâr ediyorsun, değer kaybediyorsun</div>';"""
assert eski2 in s, "tez anchor yok"
yeni2 = """      // ⚠⚠ NET_UI_V1 — ESKI TEZ SILINDI: 'Kâr ediyorsun, değer kaybediyorsun'.
      //   YANLISTI: tedarikçi borcunu (403,4M) saymamıştım. Gerçek yük 41,6M, kâr ~96M.
      //   KRB DEĞER YARATIYOR. Yerine GERÇEK soru: Brisa'nın finansmanı Kasım'da bitiyor.
      const brutToplam = (mj.brut_kar||0) + (mj.prim||0);
      const yuk = Number(s.yillik_yuk||0);
      const borc = Number(s.tedarikci_borcu||0);
      if (borc > 0) {
        h += '<div class="kart kart-dikkat" style="margin-bottom:24px">';
        h += '<div style="font-size:15px;margin-bottom:8px">İşletme sermayeni Brisa finanse ediyor</div>';
        h += '<div class="satir"><span>' + esc(s.en_buyuk_ad || 'Brisa') + '</span><span class="n d-sari">' + _M(s.en_buyuk_borc) + '</span></div>';
        h += '<div class="satir"><span>diğer tedarikçiler</span><span class="n">' + _M(borc - Number(s.en_buyuk_borc||0)) + '</span></div>';
        h += '<div class="satir" style="border-top:0.5px solid var(--cizgi);margin-top:4px;padding-top:6px"><span>net işletme sermayesi</span><span class="n">' + _M(s.net_sermaye) + '</span></div>';
        h += '<div class="satir"><span>yıllık sermaye yükü</span><span class="n">' + _M(yuk) + '</span></div>';
        h += '<div class="satir"><span>lastik brüt kârı (prim dahil)</span><span class="n d-yesil">' + _M(brutToplam) + '</span></div>';
        h += '<div style="font-size:12px;color:var(--tx-2);margin-top:10px;line-height:1.6">'
           + 'Stoğun büyük kısmını tedarikçi finanse ediyor — ücretsiz, ama süreli. '
           + 'Ödeme takvimi başlayınca (18 Kas · 16 Ara · 22 Oca · 22 Şub) bu finansman biter.<br>'
           + '<span class="d-sari">Asıl soru sermayenin bağlı olması değil — Kasım’da o nakdi nereden bulacağın.</span></div>';
        h += '<div style="margin-top:12px"><button class="dg sor" data-sor="'
           + esc('Brisa borcu ' + Math.round(Number(s.en_buyuk_borc||0)/1e6) + 'M, Kasım-Şubat arası ödenecek. Nakit projeksiyonu çıkar: o tarihlerde ne kadar tahsilat bekleniyor, açık kalır mı?')
           + '" style="min-height:38px;font-size:13px">Nakit projeksiyonu</button></div>';
        h += '</div>';
      }
      if (false) {"""
s = s.replace(eski2, yeni2, 1)

# ⚠ NET RISK BLOGU — karar kuyrugundan ONCE
eski3 = """    // ── KARAR KUYRUGU ─────────────────────────────────────────────────────"""
assert eski3 in s, "karar kuyrugu anchor yok"
yeni3 = """    // ── NET_UI_V1 — ⚠ RISK, NET POZISYONA GORE ───────────────────────────
    //   MUTAFLAR brut 47,6M ama net 1,0M (limit 1,0M): YONETILEN MAHSUPLASMA.
    //   Sistem bunu 'limitin 138 kati' diye BAGIRIYORDU. Yanlisti.
    if ((d.net_risk||[]).length) {
      h += '<div class="etiket" style="margin-bottom:11px">MÜŞTERİ RİSKİ — NET POZİSYON</div>';
      h += '<div class="kart" style="margin-bottom:24px">';
      (d.net_risk||[]).forEach(function(r){
        const kat = r.net_kat ? Number(r.net_kat) : null;
        const renk = (kat && kat > 1.5) ? 'd-kirmizi' : (kat && kat > 1 ? 'd-sari' : 'd-yesil');
        h += '<div style="padding:9px 0;border-bottom:0.5px solid var(--cizgi)">';
        h += '<div style="display:flex;justify-content:space-between;gap:12px;align-items:baseline">';
        h += '<span style="font-size:14px">' + esc(String(r.musteri||'').slice(0,34)) + '</span>';
        h += '<span class="n ' + renk + '" style="font-size:15px">' + _M(r.net) + '</span></div>';
        h += '<div style="font-size:12px;color:var(--tx-3);font-family:var(--mono);margin-top:3px">'
           + 'alacak ' + _M(r.brut_alacak)
           + (Number(r.krb_borcu) < 0 ? ' · KRB borcu ' + _M(r.krb_borcu) : '')
           + (r.kredi_limiti ? ' · limit ' + _M(r.kredi_limiti) + (kat ? ' · ' + kat + ' kat' : '') : ' · limit yok')
           + '</div></div>';
      });
      h += '<div style="font-size:12px;color:var(--tx-2);margin-top:10px;line-height:1.6">'
         + 'Risk artık <span class="d-yesil">net pozisyona</span> göre. Karşılıklı alım yapan müşterilerde brüt alacak yanıltıcı.<br>'
         + 'MUTAFLAR brüt 47,6M görünüyor; KRB’nin ona borcu 46,6M — <span class="d-yesil">net 1,0M, tam limitte.</span> Yönetilen mahsuplaşma.</div>';
      h += '<div style="margin-top:12px"><button class="dg dg-sessiz sor" data-sor="'
         + esc('Net risk sıralamasını aç. YEDİ OTO 30,5M limitin 2 katı, TOROS 9,5M limitin 47 katı. Bunlarda ne yapmalıyım?')
         + '" style="min-height:36px;font-size:13px">Aç</button></div>';
      h += '</div>';
    }

    // ── KARAR KUYRUGU ─────────────────────────────────────────────────────"""
s = s.replace(eski3, yeni3, 1)
s = s.replace("  // ── ANA_UI_V1 + MARJ_GERCEK_V1", "  // ── ANA_UI_V1 + MARJ_GERCEK_V1 + NET_UI_V1", 1)

p.write_text(s, encoding="utf-8")
print("  ✅ on yuz: net sermaye + net risk + yanlis tez SILINDI")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_netui shells/bi.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 20s krb-assessment 2>&1 | grep -i "error\|api/bi/ana" | head -3 || echo "  log temiz"

git add -A
git commit -q -m 'fix(ana): NET_UI_V1 — YANLIS TEZ EKRANDAN KALKTI. (1) Bagli sermaye 507,3M -> NET isletme sermayesi 103,9M (tedarikci borcu 403,4M sayilmamisti). Yillik yuk 202,9M -> 41,6M. (2) Kar ediyorsun deger kaybediyorsun TEZI SILINDI: lastik brut kar ~96M > yuk 41,6M, KRB DEGER YARATIYOR. Yerine GERCEK soru: isletme sermayesini BRISA finanse ediyor (318,95M), ve o finansman Kasim-Subat odemeleriyle BITIYOR. Asil soru sermayenin bagli olmasi degil, Kasimda o nakdi nereden bulacagi. (3) RISK artik NET POZISYONA gore: MUTAFLAR brut 47,6M ama net 1,0M (alacak 47.556.434 - borc 46.555.721 = 1.000.714, limit 1.000.000) — YONETILEN MAHSUPLASMA, tesadüf degil. Sistem yonetilen bir iliski hakkinda her gun bagiriyordu; Fatih Bilen sistemi buyuk ihtimalle bu yuzden birakti. GERCEK riskler: YEDI OTO net 30,5M (2 kat), TOROS 9,5M (47,5 kat).'
echo "  COMMITTED"
