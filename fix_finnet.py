#!/usr/bin/env python3
# FINNET_FIX_V1 — gecikmiş alacağı NET pozisyona taşı: bi_cari_bakiye ile her muhatabın
# KRB borcunu (tedarikci_bakiye) mahsup et. Köken net'e göre sıralanır; her hesapta brut/krb_borc/net.
# etki NET bazlı finansman maliyeti + overdue_brut + mahsup. Prompt: brüt'ü gerçek risk gibi sunma.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "FINNET_FIX_V1" in s:
    print("finnet: already present, skip"); print("DONE."); raise SystemExit

# (A) br sorgusu: net-farkındalı (cb + j + gecikmis_brut/net)
oldA = ('''      risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, vadesi_gecmis, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),
      ragg AS (SELECT SUM(GREATEST(hesap_bakiyesi,0)) bakiye, SUM(GREATEST(vadesi_gecmis,0)) gecikmis
        FROM risk WHERE musteri_mi)
      SELECT COALESCE(rev12,0)::float8 rev12, COALESCE(bakiye,0)::float8 bakiye,
             COALESCE(gecikmis,0)::float8 gecikmis, COALESCE(rev12,0)::float8/365.0 gunluk FROM rev, ragg`, [T])).rows[0] || {};''')
newA = ('''      risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, GREATEST(vadesi_gecmis,0) vg, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), /* FINNET_FIX_V1 */
      cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu),
      j AS (SELECT r.hesap_bakiyesi, r.vg, COALESCE(cb.borc,0) borc FROM risk r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.musteri_mi),
      ragg AS (SELECT SUM(GREATEST(hesap_bakiyesi,0)) bakiye, SUM(vg) gecikmis_brut, SUM(GREATEST(vg+borc,0)) gecikmis_net FROM j)
      SELECT COALESCE(rev12,0)::float8 rev12, COALESCE(bakiye,0)::float8 bakiye,
             COALESCE(gecikmis_brut,0)::float8 gecikmis_brut, COALESCE(gecikmis_net,0)::float8 gecikmis_net,
             COALESCE(rev12,0)::float8/365.0 gunluk FROM rev, ragg`, [T])).rows[0] || {};''')
assert s.count(oldA) == 1, "br query anchor"
s = s.replace(oldA, newA, 1)

# (B) gecikmis çıkarımı: net ana ölçü
oldB = '  const gecikmis = Number(br.gecikmis) || 0, bakiye = Number(br.bakiye) || 0, rev12 = Number(br.rev12) || 0, gunluk = Number(br.gunluk) || 0;'
newB = '  const gecikmis_brut = Number(br.gecikmis_brut) || 0, gecikmis = Number(br.gecikmis_net) || 0, bakiye = Number(br.bakiye) || 0, rev12 = Number(br.rev12) || 0, gunluk = Number(br.gunluk) || 0;'
assert s.count(oldB) == 1, "gecikmis extract anchor"
s = s.replace(oldB, newB, 1)

# (C) etki: overdue_brut + mahsup ekle
oldC = '    overdue: Math.round(gecikmis), overdue_pct_alacak: bakiye > 0 ? Math.round(gecikmis / bakiye * 1000) / 10 : null,'
newC = '    overdue: Math.round(gecikmis), overdue_brut: Math.round(gecikmis_brut), mahsup: Math.round(gecikmis_brut - gecikmis), overdue_pct_alacak: bakiye > 0 ? Math.round(gecikmis / bakiye * 1000) / 10 : null,'
assert s.count(oldC) == 1, "etki anchor"
s = s.replace(oldC, newC, 1)

# (D) köken sorguları: net-farkındalı
oldD = ('''  const _topRows = (await q(`SELECT muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad,
        COALESCE(NULLIF(TRIM(satis_calisani),''),'—') rep, COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') vade, vg::float8 vg
      FROM (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, satis_calisani, odeme_kosulu,
              GREATEST(vadesi_gecmis,0) vg, musteri_mi
            FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC) r
      WHERE musteri_mi AND vg>0 ORDER BY vg DESC LIMIT 12`, [T])).rows;
  const _repRows = (await q(`SELECT rep, SUM(vg)::float8 tut, COUNT(*)::int adet FROM (
        SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(satis_calisani),''),'—') rep,
          GREATEST(vadesi_gecmis,0) vg, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC) r
      WHERE musteri_mi AND vg>0 GROUP BY rep ORDER BY tut DESC LIMIT 8`, [T])).rows;
  const _vadeRows = (await q(`SELECT vade, SUM(vg)::float8 tut FROM (
        SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') vade,
          GREATEST(vadesi_gecmis,0) vg, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC) r
      WHERE musteri_mi AND vg>0 GROUP BY vade ORDER BY tut DESC LIMIT 8`, [T])).rows;''')
newD = ('''  const _CB = "cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu)"; /* FINNET_FIX_V1 */
  const _topRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, satis_calisani, odeme_kosulu,
              GREATEST(vadesi_gecmis,0) vg, musteri_mi
            FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),
        ${_CB}
      SELECT r.muhatap_kodu kod, COALESCE(NULLIF(TRIM(r.muhatap_adi),''),r.muhatap_kodu) ad,
        COALESCE(NULLIF(TRIM(r.satis_calisani),''),'—') rep, COALESCE(NULLIF(TRIM(r.odeme_kosulu),''),'—') vade,
        r.vg::float8 brut, COALESCE(cb.borc,0)::float8 borc, GREATEST(r.vg+COALESCE(cb.borc,0),0)::float8 net
      FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu
      WHERE r.musteri_mi AND GREATEST(r.vg+COALESCE(cb.borc,0),0)>0 ORDER BY net DESC LIMIT 12`, [T])).rows;
  const _repRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(satis_calisani),''),'—') rep,
          GREATEST(vadesi_gecmis,0) vg, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),
        ${_CB}
      SELECT r.rep, SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))::float8 tut,
        COUNT(*) FILTER (WHERE GREATEST(r.vg+COALESCE(cb.borc,0),0)>0)::int adet
      FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu
      WHERE r.musteri_mi GROUP BY r.rep HAVING SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))>0 ORDER BY tut DESC LIMIT 8`, [T])).rows;
  const _vadeRows = (await q(`WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') vade,
          GREATEST(vadesi_gecmis,0) vg, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),
        ${_CB}
      SELECT r.vade, SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))::float8 tut
      FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu
      WHERE r.musteri_mi GROUP BY r.vade HAVING SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0))>0 ORDER BY tut DESC LIMIT 8`, [T])).rows;''')
assert s.count(oldD) == 1, "koken queries anchor"
s = s.replace(oldD, newD, 1)

# (E) _sumVg net; koken.top brut/krb_borc ekle
oldE1 = '  const _sumVg = (a) => a.reduce((x, y) => x + (Number(y.vg) || 0), 0);'
newE1 = '  const _sumVg = (a) => a.reduce((x, y) => x + (Number(y.net) || 0), 0);'
assert s.count(oldE1) == 1, "_sumVg anchor"
s = s.replace(oldE1, newE1, 1)

oldE2 = "    top: _topRows.map(r => ({ kod: r.kod, ad: r.ad, rep: r.rep, vade: r.vade, overdue: Math.round(r.vg), pct: _pctOv(r.vg) })),"
newE2 = "    top: _topRows.map(r => ({ kod: r.kod, ad: r.ad, rep: r.rep, vade: r.vade, overdue: Math.round(r.net), brut: Math.round(r.brut), krb_borc: Math.round(r.borc), pct: _pctOv(r.net) })),"
assert s.count(oldE2) == 1, "koken.top anchor"
s = s.replace(oldE2, newE2, 1)

# (F) prompt: NET uyarısı
oldF = '- "koken" verisi KİM/NEREDEN sorusunu yanıtlar: en büyük gecikmiş hesaplar (top), temsilci kırılımı (by_rep), vade kırılımı (by_vade). En az bir içgörü gecikmenin KAYNAĞINI (hangi müşteri/temsilci/vade tipi en çok pay alıyor) somut isim/rakamla göstersin.'
newF = ('- "koken" verisi KİM/NEREDEN sorusunu yanıtlar: en büyük gecikmiş hesaplar (top), temsilci kırılımı (by_rep), vade kırılımı (by_vade). En az bir içgörü gecikmenin KAYNAĞINI (hangi müşteri/temsilci/vade tipi en çok pay alıyor) somut isim/rakamla göstersin.\n'
        '- ÖNEMLİ (NET): gecikmiş alacak NET bazlıdır — aynı muhataba KRB\'nin borcu (tedarikçi bakiyesi) mahsup edilir. koken.top\'ta her hesabın brut/krb_borc/net değeri ayrı. MUTAFLAR gibi hesaplar brütte büyük görünür ama KRB borcuyla netleşir; ASLA brüt gecikmişi gerçek risk gibi sunma, NET kullan. etki.overdue=net, etki.overdue_brut=brüt, etki.mahsup=fark.')
assert s.count(oldF) == 1, "prompt koken rule anchor"
s = s.replace(oldF, newF, 1)

write(FP, s)
print("finnet: br+koken NET pozisyon, etki.overdue net + brut + mahsup, prompt NET uyarısı")
print("DONE.")
