#!/usr/bin/env python3
# FINANSAL_ICGORU_V1 — AI finansal içgörü (trend + ₺ etki). Günlük üretilir + cache.
# Modül-seviyesi yardımcılar + saatlik scheduler (setInterval anchor'dan sonra) ve
# GET /api/bi/finansal-icgoru endpoint'i (finans-marka-detay anchor'dan önce). Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "FINANSAL_ICGORU_V1" in s:
    print("fin-icgoru: already present, skip"); print("DONE."); raise SystemExit

# ---- (A) Modül-seviyesi yardımcılar + scheduler: setInterval(apiRateMap) anchor'dan sonra ----
a1 = "setInterval(() => _apiRateMap.clear(), 60 * 1000);"
helpers = r'''
// ===== FINANSAL_ICGORU_V1 — AI finansal içgörü (trend + ₺ etki). Günlük cache + saatlik scheduler. =====
const FIN_YILLIK_MALIYET = parseFloat(process.env.FIN_YILLIK_MALIYET || "0.50"); // yıllık TL finansman maliyeti (ayarlanabilir)

function _finTrend(seri) {
  if (!seri || !seri.length) return null;
  const son = seri[seri.length - 1];
  const at = (n) => seri[seri.length - 1 - n] || null;
  const p1 = at(1), p3 = at(3), p12 = at(12);
  const chg = (a, b) => (a && b && b.deger) ? Math.round((a.deger - b.deger) / Math.abs(b.deger) * 1000) / 10 : null;
  return { son: son.deger, son_ay: son.ay, mom_pct: chg(son, p1), q_pct: chg(son, p3), yoy_pct: chg(son, p12),
           p3_deger: p3 ? p3.deger : null, p12_deger: p12 ? p12.deger : null };
}

async function _finIcgoruContext(T, q) {
  q = q || query;
  const ms = (await q(`SELECT metrik, to_char(donem,'YYYY-MM') ay, deger::float8 deger
      FROM bi_metrik_gecmis WHERE tenant_id::text=$1 AND boyut_tipi='sirket' AND periyot='ay'
        AND metrik IN ('dso','alacak','ciro_lastik','stok_deger') AND donem >= (CURRENT_DATE - INTERVAL '15 months')
      ORDER BY metrik, donem`, [T])).rows;
  const seri = {};
  for (const r of ms) (seri[r.metrik] = seri[r.metrik] || []).push({ ay: r.ay, deger: r.deger });
  const trend = {};
  for (const k of Object.keys(seri)) trend[k] = _finTrend(seri[k]);

  const br = (await q(`WITH rev AS (
        SELECT SUM(satir_tutar) FILTER (WHERE fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months') rev12
        FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND satir_tutar>0),
      risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, hesap_bakiyesi, vadesi_gecmis, musteri_mi
        FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC),
      ragg AS (SELECT SUM(GREATEST(hesap_bakiyesi,0)) bakiye, SUM(GREATEST(vadesi_gecmis,0)) gecikmis
        FROM risk WHERE musteri_mi)
      SELECT COALESCE(rev12,0)::float8 rev12, COALESCE(bakiye,0)::float8 bakiye,
             COALESCE(gecikmis,0)::float8 gecikmis, COALESCE(rev12,0)::float8/365.0 gunluk FROM rev, ragg`, [T])).rows[0] || {};

  const kar = (await q(`SELECT COALESCE(SUM(ciro),0)::float8 ciro, COALESCE(SUM(brut_kar),0)::float8 brut_kar
      FROM bi_marj_atom WHERE tenant_id::text=$1 AND ay >= (CURRENT_DATE - INTERVAL '12 months')`, [T])).rows[0] || {};

  const _mv = (await q(`SELECT COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') k, SUM(satir_tutar)::float8 t
      FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND satir_tutar>0 AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' GROUP BY 1`, [T])).rows;
  const _tv = (await q(`SELECT COALESCE(NULLIF(TRIM(vade_turu),''),'—') k, SUM(satir_kdv_haric)::float8 t
      FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND satir_kdv_haric>0 AND fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' GROUP BY 1`, [T])).rows;
  const _gun = (l) => { const x = String(l || "").toLocaleLowerCase("tr"); if (/(peşin|pesin|nakit|havale|kredi kart|çek|cek|senet)/.test(x)) return 0; const m = x.match(/(\d+)\s*g[üu]n/); return m ? parseInt(m[1], 10) : null; };
  const _ortGun = (rows) => { let ag = 0, tt = 0; for (const r of rows) { const d = _gun(r.k); const t = Number(r.t) || 0; if (d != null && t > 0) { ag += d * t; tt += t; } } return tt > 0 ? Math.round(ag / tt * 10) / 10 : 0; };
  const musteri_vade = _ortGun(_mv), tedarikci_vade = _ortGun(_tv);

  const gecikmis = Number(br.gecikmis) || 0, bakiye = Number(br.bakiye) || 0, rev12 = Number(br.rev12) || 0, gunluk = Number(br.gunluk) || 0;
  const brut_kar = Number(kar.brut_kar) || 0, ciro_marj = Number(kar.ciro) || 0;
  const finans_yil = gecikmis * FIN_YILLIK_MALIYET;
  const etki = {
    overdue: Math.round(gecikmis), overdue_pct_alacak: bakiye > 0 ? Math.round(gecikmis / bakiye * 1000) / 10 : null,
    finans_maliyeti_yil: Math.round(finans_yil), finans_maliyeti_ay: Math.round(finans_yil / 12),
    finans_pct_ciro: rev12 > 0 ? Math.round(finans_yil / rev12 * 1000) / 10 : null,
    finans_pct_brutkar: brut_kar > 0 ? Math.round(finans_yil / brut_kar * 1000) / 10 : null,
    brut_kar_yil: Math.round(brut_kar), brut_marj_pct: ciro_marj > 0 ? Math.round(brut_kar / ciro_marj * 1000) / 10 : null,
    ima_dso_toplam: gunluk > 0 ? Math.round(bakiye / gunluk * 10) / 10 : null,
    ima_dso_vadesinde: gunluk > 0 ? Math.round((bakiye - gecikmis) / gunluk * 10) / 10 : null,
    yillik_maliyet_oran: FIN_YILLIK_MALIYET
  };
  // 6) KÖKEN (kim / nereden): en büyük gecikmiş hesaplar + temsilci + vade kırılımı
  const _topRows = (await q(`SELECT muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad,
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
      WHERE musteri_mi AND vg>0 GROUP BY vade ORDER BY tut DESC LIMIT 8`, [T])).rows;
  const _pctOv = (v) => gecikmis > 0 ? Math.round(v / gecikmis * 1000) / 10 : null;
  const _sumVg = (a) => a.reduce((x, y) => x + (Number(y.vg) || 0), 0);
  const top5 = _sumVg(_topRows.slice(0, 5)), top10 = _sumVg(_topRows.slice(0, 10));
  const koken = {
    top: _topRows.map(r => ({ kod: r.kod, ad: r.ad, rep: r.rep, vade: r.vade, overdue: Math.round(r.vg), pct: _pctOv(r.vg) })),
    top5_pct: _pctOv(top5), top10_pct: _pctOv(top10),
    by_rep: _repRows.map(r => ({ rep: r.rep, overdue: Math.round(r.tut), adet: r.adet, pct: _pctOv(r.tut) })),
    by_vade: _vadeRows.map(r => ({ vade: r.vade, overdue: Math.round(r.tut), pct: _pctOv(r.tut) }))
  };

  // 7) SİMÜLASYON (aksiyon → sayı etkisi). DSO alacak/günlük-ciro bazlı.
  const _sim = (tahsil, ad) => {
    const t = Math.max(0, Math.min(tahsil, gecikmis));
    const yeniBakiye = Math.max(0, bakiye - t);
    return { ad, tahsil: Math.round(t), yeni_overdue: Math.round(gecikmis - t),
      yeni_dso: gunluk > 0 ? Math.round(yeniBakiye / gunluk * 10) / 10 : null,
      tasarruf_yil: Math.round(t * FIN_YILLIK_MALIYET), tasarruf_ay: Math.round(t * FIN_YILLIK_MALIYET / 12),
      brutkar_geri_pct: brut_kar > 0 ? Math.round(t * FIN_YILLIK_MALIYET / brut_kar * 1000) / 10 : null };
  };
  const simulasyon = [
    _sim(top5, "En büyük 5 gecikmiş hesap tahsil edilse"),
    _sim(top10, "En büyük 10 gecikmiş hesap tahsil edilse"),
    _sim(gecikmis * 0.5, "Gecikmişin %50'si tahsil edilse")
  ];

  return { trend, kopru: { rev12: Math.round(rev12), bakiye: Math.round(bakiye), gecikmis: Math.round(gecikmis), gunluk: Math.round(gunluk) },
           kar: { ciro: Math.round(ciro_marj), brut_kar: Math.round(brut_kar) },
           vade: { musteri_vade, tedarikci_vade, fark: Math.round((musteri_vade - tedarikci_vade) * 10) / 10 },
           etki, koken, simulasyon };
}

const _FIN_SYS = `Sen KRB adlı Türk lastik+jant toptancısının kıdemli finans analistisin (CFO gözüyle).
Sana şirketin CANLI finansal metrik serileri, trendleri ve ₺ etki hesapları JSON olarak verilir. Görevin: en önemli 3-5 finansal içgörüyü çıkarmak.
KURALLAR:
- SADECE verilen JSON'daki sayıları kullan. Sayı UYDURMA. Her içgörüyü mümkünse bir ₺ etkiyle bağla (etki_tl).
- Trend'i yorumla (MoM/YoY yön, kırılma noktası). Öneri uygulanabilir ve KISA olsun.
- "koken" verisi KİM/NEREDEN sorusunu yanıtlar: en büyük gecikmiş hesaplar (top), temsilci kırılımı (by_rep), vade kırılımı (by_vade). En az bir içgörü gecikmenin KAYNAĞINI (hangi müşteri/temsilci/vade tipi en çok pay alıyor) somut isim/rakamla göstersin.
- "simulasyon" verisi AKSİYON→ETKİ senaryolarıdır (tahsilat → DSO/finansman tasarrufu). Önerilerini bu senaryolardaki gerçek tasarruf rakamlarıyla destekle.
- Türkçe, net, yönetim diliyle. Abartma yok; ama riski açıkça söyle. Rakamları M₺ olarak yaz.
- Çıktı SADECE şu şemada GEÇERLİ JSON dizisi olsun, başka hiçbir metin YOK:
[{"baslik":"kısa başlık","ozet":"tek cümle","anlati":"2-3 cümle, sayılarla","oneri":"tek cümle aksiyon","etki_tl":<sayı ₺/yıl veya null>,"etki_aciklama":"etki_tl neyi ölçüyor","siddet":"yuksek|orta|dusuk","metrik":"dso|alacak|vade|marj|stok|ciro"}]`;

async function _finIcgoruUret(T, q) {
  const ctx = await _finIcgoruContext(T, q);
  const msg = await anthropic.messages.create({
    model: "claude-sonnet-4-6", max_tokens: 1500, system: _FIN_SYS,
    messages: [{ role: "user", content: "CANLI FİNANSAL VERİ (JSON):\n" + JSON.stringify(ctx) + "\n\nEn önemli 3-5 finansal içgörüyü yukarıdaki şemada JSON dizisi olarak ver. Sadece JSON." }]
  });
  let txt = (msg.content || []).filter(x => x.type === "text").map(x => x.text).join("").trim();
  const i = txt.indexOf("["), j = txt.lastIndexOf("]");
  let arr = [];
  if (i >= 0 && j > i) { try { arr = JSON.parse(txt.slice(i, j + 1)); } catch (e) { arr = []; } }
  if (!Array.isArray(arr)) arr = [];
  return { icgoruler: arr, baglam: ctx };
}

async function _finIcgoruGunluk(T, zorla, q) {
  q = q || query;
  const gun = new Date().toISOString().slice(0, 10);
  if (!zorla) {
    const c = (await q(`SELECT to_char(gun,'YYYY-MM-DD') gun, icgoruler, baglam, uretildi_at FROM bi_finansal_icgoru WHERE tenant_id::text=$1 AND gun=$2`, [T, gun])).rows[0];
    if (c) return { cache: true, gun: c.gun, icgoruler: c.icgoruler, baglam: c.baglam, uretildi_at: c.uretildi_at };
  }
  const out = await _finIcgoruUret(T, q);
  await q(`INSERT INTO bi_finansal_icgoru (tenant_id, gun, icgoruler, baglam, uretildi_at)
      VALUES ($1::uuid, $2, $3::jsonb, $4::jsonb, now())
      ON CONFLICT (tenant_id, gun) DO UPDATE SET icgoruler=EXCLUDED.icgoruler, baglam=EXCLUDED.baglam, uretildi_at=now()`,
    [T, gun, JSON.stringify(out.icgoruler), JSON.stringify(out.baglam)]);
  return { cache: false, gun, icgoruler: out.icgoruler, baglam: out.baglam };
}

let _finBusy = false;
async function _finIcgoruScheduler() {
  if (_finBusy) return; _finBusy = true;
  try {
    const gun = new Date().toISOString().slice(0, 10);
    const tenants = (await query(`SELECT DISTINCT tenant_id::text t FROM bi_metrik_gecmis WHERE boyut_tipi='sirket' AND metrik='dso'`)).rows;
    for (const row of tenants) {
      const T = row.t; if (!T) continue;
      const q = (sql, params) => queryAsTenant(T, sql, params);
      try {
        const has = (await q(`SELECT 1 FROM bi_finansal_icgoru WHERE tenant_id::text=$1 AND gun=$2`, [T, gun])).rowCount;
        if (has) continue;
        await _finIcgoruGunluk(T, false, q);
        console.log("[fin-icgoru] uretildi", T, gun);
      } catch (e) { console.error("[fin-icgoru] uretim hata", T, e && e.message); }
    }
  } catch (e) { console.error("[fin-icgoru scheduler]", e && e.message); }
  finally { _finBusy = false; }
}
setInterval(() => { _finIcgoruScheduler().catch(() => {}); }, 60 * 60 * 1000); // saatte bir: bugünkü yoksa üret
setTimeout(() => { _finIcgoruScheduler().catch(() => {}); }, 45 * 1000);       // açılıştan sonra ilk deneme
'''
assert s.count(a1) == 1, "setInterval anchor"
s = s.replace(a1, a1 + "\n" + helpers, 1)

# ---- (B) Endpoint: finans-marka-detay anchor'dan önce ----
a2 = "    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-detay') {"
ep = r'''    // FINANSAL_ICGORU_V1 — AI finansal içgörü (trend + ₺ etki). Günlük cache. Desktop + mobil. Çift erişim.
    if (request.method === 'GET' && url.pathname === '/api/bi/finansal-icgoru') {
      try {
        let session = await requireModuleAccess(request, "intelligence").catch(() => null);
        if (!session) {
          const _ss = await requireSahaAccess(request).catch(() => null);
          if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss;
        }
        if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
        const zorla = url.searchParams.get("yenile") === "1";
        const out = await _finIcgoruGunluk(String(session.tenantId), zorla);
        sendJson(response, 200, out);
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
assert s.count(a2) == 1, "finans-marka-detay anchor"
s = s.replace(a2, ep + a2, 1)

write(FP, s)
print("fin-icgoru: helpers + scheduler + endpoint eklendi")
print("DONE.")
