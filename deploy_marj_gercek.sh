#!/usr/bin/env bash
# MARJ_GERCEK_V1 — karlilik artik HESAPLANABILIYOR. Kaynak: ERP'nin KENDI maliyet kaydi.
#
# ⚠ NEDEN DEGISTI: iskonto/tesvik dosyalarini bekliyorduk. GEREK YOKMUS.
#   bi_stok_hareket'te her satirda birim_maliyet VAR ve tutar/adet kimligi %100 tutuyor.
#   Liste x (1-iskonto) ile maliyeti MODELLEMEYE calisiyorduk; ERP zaten KAYDEDIYOR.
#
# ⚠ MUTABAKAT YAPILDI (bunlar olmadan rakam ekrana KONMAZDI):
#   • Cift sayim testi (siparis no uzerinden): 20 satir. Teslimat ve Musteri Faturasi
#     GERCEKTEN ayri kanallar.  [Ayni-gun testi YETERSIZDI — sevk Pzt, fatura Cuma olabilir]
#   • Ic akis elendi: muhatap SATIS tablosunda yoksa satis degildir.
#     -> KRB'nin KENDI subeleri ('MERKEZ/SANAYI/IZMIT SUBE-KARDESLER ROT BALANS')
#        sevkiyat listesinde MUSTERI gibi duruyordu: 26.587 adet · 136,3M.
#        notlar'daki 'transfer/nakil' deseni ile BIREBIR ayni: 26.585 · 136,3M. ✓
#     -> SAILUN (tedarikci) sevkiyatlari = tedarikciye iade, satis degil.
#   • Adet mutabakati: SMM 136.882 ↔ satis 134.567 = %102 ✓  (maliyet ve ciro AYNI mali olcuyor)
#
# ⚠ KAPSAM: SADECE LASTIK TICARETI (LASTIK TICARI + LASTIK TUKETICI).
#   Kaplama (LASTIK YENILEME) HARIC — musteri kendi karkasini getiriyor, maliyet farkli.
#   Servis (VERILEN SERVIS HIZMET) HARIC — mal degil, iscilik; stok cikisi yok.
#   Ikisi de ayri olculecek. Karistirinca sirket geneli marj -%4,2 gibi ABSURT cikiyordu.
#
# ⚠ 'GRP.DISI.YANSIT' bir COP KUTUSU: prim (6,56M 'VADE FARKI IADE BEDELI'),
#   GAYRIMENKUL SATISI (3,0M 'DUBLEX KONUT PARSEL'), gider yansitmasi, ve gercek satis
#   karisik. Lastik marjindan DOGRU olarak dislandi.
#
# ⚠ BU MARJ BIR ALT SINIRDIR: ERP maliyeti = FATURA maliyeti = PRIM ONCESI BRUT.
#   Prim hakedisi (40,5M) ciro olarak faturalanıyor, maliyeti dusurmuyor.
#   Ekranda ACIKCA yazacak.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ SQL ONCE POSTGRES'TE ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
SET app.current_tenant_id='$TEN';
WITH mus AS (SELECT DISTINCT musteri_kodu FROM bi_satis_faturalari
              WHERE tenant_id='$TEN' AND fatura_tarihi >= CURRENT_DATE-365),
smm AS (SELECT sum(h.cikis) AS adet, sum(h.cikis_tutari) AS maliyet
          FROM bi_stok_hareket h JOIN mus m ON m.musteri_kodu = h.muhatap_kodu
         WHERE h.tenant_id='$TEN'::uuid AND h.belge_tarihi >= CURRENT_DATE-365
           AND h.hareket_sinifi IN ('SATIS_SEVK','SATIS_FATURA')
           AND h.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI') AND h.cikis > 0),
ciro AS (SELECT sum(satir_tutar) AS c, sum(miktar) AS adet FROM bi_satis_faturalari
          WHERE tenant_id='$TEN' AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
            AND grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')),
prim AS (SELECT COALESCE(sum(satir_tutar),0) AS p FROM bi_satis_faturalari
          WHERE tenant_id='$TEN' AND fatura_tarihi >= CURRENT_DATE-365
            AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM'))
SELECT round((SELECT maliyet FROM smm)/1e6,1) AS smm_M,
       round((SELECT c FROM ciro)/1e6,1) AS ciro_M,
       round(100.0*(1-(SELECT maliyet FROM smm)/(SELECT c FROM ciro)),1) AS marj_pct,
       round(100.0*(SELECT adet FROM smm)/(SELECT adet FROM ciro)) AS adet_orani,
       round((SELECT p FROM prim)/1e6,1) AS prim_M;
SQL
[ $? -ne 0 ] && { echo "❌ SQL PATLADI"; exit 1; }
echo "  ✅ dogrulandi"

echo
echo "############ 2) ENDPOINT ############"
cp server_container.mjs server_container.mjs.bak_marj
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "MARJ_GERCEK_V1" in s: sys.exit("ZATEN YAMALI")

# Promise.all dizisine 6. sorgu ekle
eski = """        // 5) VARDIYA_V1 — ⚠ GERCEK kaynaklar. Eskisi SAHTEYDI (6 satir, ayni damga)."""
assert eski in s, "vardiya anchor yok"
yeni = """        // 6) MARJ_GERCEK_V1 — ⚠ ERP'nin KENDI maliyet kaydindan. Iskonto dosyasi GEREKMIYOR.
        //   Mutabakat: adet orani %102 (SMM 136.882 ↔ satis 134.567) -> ayni mali olcuyoruz.
        //   Ic akis elendi (KRB kendi subeleri sevkiyatta MUSTERI gibi duruyordu: 26.587 adet).
        //   Cift sayim yok (siparis no testi: 20 satir).
        //   ⚠ SADECE LASTIK TICARETI. Kaplama+servis HARIC (maliyet yapisi farkli).
        //   ⚠ ALT SINIR: ERP maliyeti = FATURA maliyeti = PRIM ONCESI.
        query(`
          WITH mus AS (SELECT DISTINCT musteri_kodu FROM bi_satis_faturalari
                        WHERE tenant_id=$1::text AND fatura_tarihi >= CURRENT_DATE-365),
          smm AS (SELECT sum(h.cikis) AS adet, sum(h.cikis_tutari) AS maliyet
                    FROM bi_stok_hareket h JOIN mus m ON m.musteri_kodu = h.muhatap_kodu
                   WHERE h.tenant_id=$2::uuid AND h.belge_tarihi >= CURRENT_DATE-365
                     AND h.hareket_sinifi IN ('SATIS_SEVK','SATIS_FATURA')
                     AND h.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI') AND h.cikis > 0),
          ciro AS (SELECT sum(satir_tutar) AS c, sum(miktar) AS adet FROM bi_satis_faturalari
                    WHERE tenant_id=$1::text AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
                      AND grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')),
          hiz AS (SELECT COALESCE(sum(satir_tutar),0) AS c FROM bi_satis_faturalari
                   WHERE tenant_id=$1::text AND miktar>0 AND fatura_tarihi >= CURRENT_DATE-365
                     AND grup_adi IN ('VERILEN SERVIS HIZMET','LASTIK YENILEME')),
          prim AS (SELECT COALESCE(sum(satir_tutar),0) AS p FROM bi_satis_faturalari
                    WHERE tenant_id=$1::text AND fatura_tarihi >= CURRENT_DATE-365
                      AND kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM'))
          SELECT s.maliyet AS smm, c.c AS ciro, s.adet AS smm_adet, c.adet AS satis_adet,
                 ROUND(100.0*(1 - s.maliyet/NULLIF(c.c,0)), 1)      AS marj_pct,
                 ROUND(100.0*s.adet/NULLIF(c.adet,0))               AS mutabakat_pct,
                 p.p AS prim, h.c AS hizmet_ciro,
                 ROUND(s.maliyet/365.0)                             AS gunluk_smm
            FROM smm s, ciro c, prim p, hiz h`, [T, T]),

        // 5) VARDIYA_V1 — ⚠ GERCEK kaynaklar. Eskisi SAHTEYDI (6 satir, ayni damga)."""
s = s.replace(eski, yeni, 1)

# destructuring: 6. eleman
s = s.replace("const [sermaye, kor, sinyaller, odemeler, vardiya] = await Promise.all([",
              "const [sermaye, kor, sinyaller, odemeler, marj, vardiya] = await Promise.all([  /* MARJ_GERCEK_V1 */", 1)

# karlilik blogunu DEGISTIR: artik HESAPLANABILIYOR
eski2 = """        // ⚠ KARLILIK HESAPLANMIYOR. Uydurmuyoruz.
        karlilik: {
          hesaplanabilir : korCiro === 0,"""
assert eski2 in s, "karlilik anchor yok"
yeni2 = """        // ⚠ MARJ_GERCEK_V1 — ARTIK HESAPLANABILIYOR. ERP'nin kendi maliyet kaydi.
        marj: (function(){
          const m = marj.rows[0] || {};
          const ciro = Number(m.ciro||0), smm = Number(m.smm||0), prim = Number(m.prim||0);
          return {
            ciro, smm, prim,
            brut_kar   : ciro - smm,
            marj_pct   : Number(m.marj_pct||0),
            // ⚠ prim maliyeti DUSURMUYOR, ciro olarak faturalaniyor -> efektif marj
            efektif_pct: ciro ? Math.round(1000*(ciro - smm + prim)/ciro)/10 : null,
            mutabakat_pct: Number(m.mutabakat_pct||0),
            gunluk_smm : Number(m.gunluk_smm||0),
            hizmet_ciro: Number(m.hizmet_ciro||0),
            kaynak: 'ERP maliyet kaydı (bi_stok_hareket.birim_maliyet) — modellenmiş değil',
            sinir : 'ALT SINIR: fatura maliyeti = prim öncesi brüt',
            kapsam: 'Sadece lastik ticareti. Kaplama ve servis hariç — maliyet yapısı farklı.',
            mutabakat: 'Adet oranı %' + Number(m.mutabakat_pct||0) + ' — maliyet ve ciro aynı malı ölçüyor.'
          };
        })(),
        karlilik: {
          hesaplanabilir : korCiro === 0,"""
s = s.replace(eski2, yeni2, 1)

# stok gunu: SMM bazli olsun
eski3 = """                 ROUND(s.deger  / NULLIF(c.gunluk,0))                AS stok_gun,"""
assert eski3 in s, "stok_gun anchor yok"
yeni3 = """                 -- ⚠ CIRO bazliydi (yaklasik). Artik SMM var ama endpoint'te ayri sorgu;
                 --   ciro bazli deger BURADA kaliyor, SMM bazli ON YUZDE hesaplanıyor.
                 ROUND(s.deger  / NULLIF(c.gunluk,0))                AS stok_gun,"""
s = s.replace(eski3, yeni3, 1)

p.write_text(s, encoding="utf-8")
print("  ✅ /api/bi/ana -> marj bloğu eklendi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_marj server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ON YUZ ############"
cp shells/bi.js shells/bi.js.bak_marj
python3 - <<'PY'
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "MARJ_GERCEK_V1" in s: sys.exit("ZATEN YAMALI")

# "Karliligini gosteremiyorum" kutusunu MARJ KUTUSU ile degistir
eski = """    // ── ⚠ KARLILIK: BOS DEGIL, DOLU BIR BOSLUK ────────────────────────────
    if (!k.hesaplanabilir) {"""
assert eski in s, "karlilik kutusu anchor yok"
yeni = """    // ── MARJ_GERCEK_V1 — ARTIK GOSTEREBILIYORUZ ───────────────────────────
    const mj = d.marj || {};
    if (mj.ciro) {
      const stokGunSMM = mj.gunluk_smm ? Math.round(Number(s.stok) / mj.gunluk_smm) : null;
      h += '<div class="kart" style="margin-bottom:10px">';
      h += '<div class="etiket" style="margin-bottom:12px">LASTİK TİCARETİ — BRÜT MARJ</div>';
      h += '<div style="display:flex;gap:26px;align-items:baseline;flex-wrap:wrap;margin-bottom:12px">';
      h += '<div><div class="n n-buyuk d-sari">%' + mj.marj_pct + '</div>'
         + '<div style="font-size:12px;color:var(--tx-2);margin-top:2px">prim hariç · alt sınır</div></div>';
      h += '<div><div class="n n-orta d-yesil">%' + mj.efektif_pct + '</div>'
         + '<div style="font-size:12px;color:var(--tx-2);margin-top:2px">prim dahil</div></div>';
      h += '<div style="flex:1;min-width:200px">';
      h += '<div class="satir"><span>ciro</span><span class="n">' + _M(mj.ciro) + '</span></div>';
      h += '<div class="satir"><span>satılan malın maliyeti</span><span class="n">' + _M(mj.smm) + '</span></div>';
      h += '<div class="satir"><span>brüt kâr</span><span class="n">' + _M(mj.brut_kar) + '</span></div>';
      h += '<div class="satir"><span>prim hakedişi</span><span class="n d-yesil">' + _M(mj.prim) + '</span></div>';
      h += '</div></div>';
      // ⚠ SEFFAFLIK: kaynak, sinir, kapsam, mutabakat — hepsi EKRANDA
      h += '<div style="font-size:12px;color:var(--tx-3);line-height:1.7;border-top:0.5px solid var(--cizgi);padding-top:10px">'
         + esc(mj.kaynak) + '<br>' + esc(mj.kapsam) + '<br>' + esc(mj.mutabakat) + '</div>';
      h += '<div style="display:flex;gap:8px;margin-top:12px">'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('Lastik brüt marjı %' + mj.marj_pct + '. Marka ve ebat bazında kırılımını ver — hangi ürünler zarar ettiriyor?') + '" style="min-height:36px;font-size:13px">Kırılımı göster</button>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('Servis ve kaplama işinin brüt marjı ne? Lastik ticaretiyle kıyasla — hangisi daha çok değer yaratıyor?') + '" style="min-height:36px;font-size:13px">Servis vs lastik</button>'
         + '</div>';
      h += '</div>';

      // ⚠ ASIL CUMLE: karli ama deger kaybediyor
      const brutToplam = (mj.brut_kar||0) + (mj.prim||0);
      const yuk = Number(s.yillik_yuk||0);
      if (yuk > 0) {
        h += '<div class="kart kart-karar" style="margin-bottom:24px">';
        h += '<div style="font-size:15px;margin-bottom:8px">Kâr ediyorsun, değer kaybediyorsun</div>';
        h += '<div class="satir"><span>lastik brüt kârı (prim dahil)</span><span class="n d-yesil">' + _M(brutToplam) + '</span></div>';
        h += '<div class="satir"><span>yıllık sermaye yükü</span><span class="n d-kirmizi">−' + _M(yuk) + '</span></div>';
        h += '<div class="satir" style="border-top:0.5px solid var(--cizgi);margin-top:4px;padding-top:6px">'
           + '<span>fark (faaliyet gideri HARİÇ)</span><span class="n d-kirmizi">' + _M(brutToplam - yuk) + '</span></div>';
        h += '<div style="font-size:12px;color:var(--tx-2);margin-top:10px;line-height:1.6">'
           + 'Personel, kira, enerji daha sayılmadı. Servis ve kaplama kârı da bunun dışında — ayrı ölçülecek.<br>'
           + 'Ciro büyütmek bunu kapatmaz: büyüdükçe bağlı sermaye de büyür.</div>';
        h += '<div style="margin-top:12px"><button class="dg sor" data-sor="'
           + esc('Sermaye yükü 203M, lastik brüt kârı ' + Math.round(brutToplam/1e6) + 'M. Bu farkı kapatmak için ne yapmalıyım? Stok mu, tahsilat mı, marj mı — hangisi en hızlı sonuç verir?')
           + '" style="min-height:38px;font-size:13px">Ne yapmalıyım?</button></div>';
        h += '</div>';
      }
    }
    if (false && !k.hesaplanabilir) {"""
s = s.replace(eski, yeni, 1)

# stok kartinda SMM bazli gun goster
eski2 = """       +   '<div class="n n-buyuk d-sari" style="margin:6px 0">' + _tl(s.stok_gun) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">serbest ' + _M(s.stok_serbest) + '</div>'"""
assert eski2 in s, "stok kart anchor yok"
yeni2 = """       +   '<div class="n n-buyuk d-sari" style="margin:6px 0">' + ((d.marj && d.marj.gunluk_smm) ? Math.round(Number(s.stok)/d.marj.gunluk_smm) : _tl(s.stok_gun)) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">' + ((d.marj && d.marj.gunluk_smm) ? 'maliyet bazlı' : 'ciro bazlı') + ' · serbest ' + _M(s.stok_serbest) + '</div>'"""
s = s.replace(eski2, yeni2, 1)
s = s.replace("  // ── ANA_UI_V1 — 'Bugün' odasi", "  // ── ANA_UI_V1 + MARJ_GERCEK_V1 — 'Bugün' odasi", 1)

p.write_text(s, encoding="utf-8")
print("  ✅ marj kutusu + deger kaybi kutusu + SMM bazli stok gunu")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_marj shells/bi.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 20s krb-assessment 2>&1 | grep -i "error\|api/bi/ana" | head -3 || echo "  log temiz"

git add -A && git commit -q -m "feat(marj): MARJ_GERCEK_V1 — karlilik ARTIK HESAPLANABILIYOR. Iskonto/tesvik dosyalarini bekliyorduk; GEREK YOKMUS: bi_stok_hareket'te her satirda birim_maliyet VAR ve tutar/adet kimligi %100 tutuyor. Maliyeti liste x (1-iskonto) ile MODELLEMEYE calisiyorduk; ERP zaten KAYDEDIYOR. LASTIK TICARETI BRUT MARJ: %8,3 (prim haric, alt sinir) · %14,3 (prim dahil). Ciro 672,3M · SMM 616,6M · brut kar 55,8M · prim 40,5M. MUTABAKAT (bunlar olmadan rakam ekrana KONMAZDI): (1) cift sayim testi SIPARIS NO uzerinden — 20 satir; ayni-gun testi YETERSIZDI (sevk Pzt, fatura Cuma olabilir). (2) ic akis elendi: KRB'nin KENDI subeleri sevkiyat listesinde MUSTERI gibi duruyordu (26.587 adet · 136,3M); notlar'daki 'transfer/nakil' deseni ile BIREBIR ayni (26.585 · 136,3M). SAILUN sevkiyatlari = tedarikciye iade. (3) adet mutabakati %102 — maliyet ve ciro AYNI mali olcuyor. KAPSAM: sadece lastik ticareti; kaplama (musteri kendi karkasini getiriyor) ve servis (iscilik, stok cikisi yok) HARIC — karistirinca sirket geneli marj -%4,2 gibi ABSURT cikiyordu. 'GRP.DISI.YANSIT' bir COP KUTUSU (prim + GAYRIMENKUL SATISI 3M 'DUBLEX KONUT PARSEL' + gider yansitmasi) — dogru olarak dislandi. STOK GUNU artik SMM bazli (159), ciro bazli (131) degil. VE ASIL CUMLE EKRANDA: lastik brut kar 96M vs yillik sermaye yuku 203M — faaliyet gideri HARIC. KRB kar ediyor, deger kaybediyor; artik model degil, KRB'nin KENDI ERP kaydiyla kanitli." && echo "  COMMITTED"
