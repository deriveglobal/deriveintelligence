# -*- coding: utf-8 -*-
# MUSTERI_OLAYLAR_V1 (server) — müşteri zaman çizelgesi (union) + not/takip yazma.
#   GET  /api/saha/musteriler/:id/olaylar  — tüm kaynakları harmanlar (ziyaret+sinyal+aksiyon+alım+teklif+rakip)
#        + kural-tabanlı özet cümlesi + EKG verisi + sayaçlar + açık takipler + ritim-türevi durum.
#   POST /api/saha/musteriler/:id/not      — saha_sinyal'e not/takip yazar (+ saha_musteri_aksiyon log).
#   Yeni tablo YOK — mevcut saha_sinyal/saha_musteri_aksiyon/saha_teklif/saha_rakip_teklif/bi_satis_faturalari
#   + kanonik saha_musteri_saglik view. requireSahaAccess (her rep her müşteriyi görür — Fatih kuralı).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MUSTERI_OLAYLAR_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

anchor = "    // ── Müşteri oluştur (ERP seçiminden veya sıfırdan) ──"
assert s.count(anchor) == 1, "anchor=%d" % s.count(anchor)

BLOCK = r'''    // ── MUSTERI_OLAYLAR_V1 — müşteri zaman çizelgesi (union) ──
    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})/olaylar$`)))) {
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, mid = m[1];
      const cr = await query(`SELECT m.id, m.firma, m.tip, m.musteri_kodu kod, m.sorumlu_rep::text rid,
               sg.durum, sg.ritim, sg.recency_ay, sg.guven
          FROM saha_musteri m
          LEFT JOIN saha_musteri_saglik sg ON sg.tenant_id=$1::text AND sg.musteri_kodu=m.musteri_kodu
         WHERE m.tenant_id=$1 AND m.id=$2 AND m.aktif=true`, [tid, mid]);
      if (!cr.rowCount) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }
      const M = cr.rows[0], kod = M.kod;
      const ev = [];
      const push = (ts, tip, ikon, baslik, alt, kim) => { if (ts) ev.push({ ts: (ts instanceof Date ? ts.toISOString() : ts), tip, ikon, baslik, alt: alt || null, kim: kim || null }); };
      const idSet = new Set(); if (M.rid) idSet.add(M.rid);
      const q = async (sql, p) => { try { return (await query(sql, p)).rows; } catch (e) { console.error("[olaylar]", e && e.message); return []; } };
      // ziyaret
      const ziy = await q(`SELECT ziyaret_tarihi ts, notlar, rep_id::text rid, lokasyon_adi, foto_sayisi
          FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum='TAMAMLANDI' ORDER BY ziyaret_tarihi DESC LIMIT 25`, [tid, mid]);
      ziy.forEach(z => { if (z.rid) idSet.add(z.rid); push(z.ts, "ziyaret", "🚗", z.notlar ? ("Ziyaret — " + String(z.notlar).slice(0, 120)) : "Ziyaret", (z.lokasyon_adi ? "📍" + z.lokasyon_adi : "") + (Number(z.foto_sayisi) ? " · 📷" + z.foto_sayisi : ""), z.rid); });
      // sinyal / not
      const sig = await q(`SELECT created_at ts, tip, onem, ozet, rep_id::text rid, detay FROM saha_sinyal
          WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY created_at DESC LIMIT 25`, [tid, mid]);
      sig.forEach(x => { if (x.rid) idSet.add(x.rid);
        const isNot = (x.tip === "not" || x.tip === "takip" || !x.tip);
        const ik = x.tip === "rakip" ? "🏷️" : x.tip === "risk" ? "⚠️" : x.tip === "firsat" ? "✨" : x.tip === "teklif_talep" ? "📩" : "📝";
        const takip = x.detay && (x.detay.takip_tarihi || x.tip === "takip");
        push(x.ts, isNot ? "not" : x.tip, ik, (isNot ? "Not — " : (x.tip + " — ")) + String(x.ozet || "").slice(0, 130), takip ? "· takip" : null, x.rid); });
      // aksiyon
      const AKS = { GITTIM: "Gidildi olarak işaretlendi", PLANLA: "Ziyaret planlandı", ILET: "İletildi", ATA: "Sorumlu atandı", SUSTUR: "Susturuldu", GERI_AL: "Geri alındı" };
      const aks = await q(`SELECT olusturma_ts ts, rapor, tur, aktor_id::text aid, gerekce_metin, hedef_rep::text hr, eski_rep::text er
          FROM saha_musteri_aksiyon WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY olusturma_ts DESC LIMIT 20`, [tid, mid]);
      aks.forEach(a => { if (a.aid) idSet.add(a.aid); if (a.hr) idSet.add(a.hr); if (a.er) idSet.add(a.er);
        push(a.ts, "aksiyon", "⚙️", AKS[a.tur] || a.tur, a.gerekce_metin ? String(a.gerekce_metin).slice(0, 100) : (a.rapor || null), a.aid); });
      // teklif
      const tek = await q(`SELECT created_at ts, marka, ebat, adet, toplam_tutar, durum FROM saha_teklif
          WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY created_at DESC LIMIT 15`, [tid, mid]);
      tek.forEach(t => push(t.ts, "teklif", "📄", "Teklif — " + [t.marka, t.ebat].filter(Boolean).join(" ") + (t.adet ? " ×" + t.adet : ""), (t.toplam_tutar != null ? Number(t.toplam_tutar).toLocaleString("tr-TR") + " ₺" : "") + (t.durum ? " · " + t.durum : ""), null));
      // rakip fiyatı
      const rak = await q(`SELECT created_at ts, rakip_marka, ebat, rakip_fiyat, rep_id::text rid FROM saha_rakip_teklif
          WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY created_at DESC LIMIT 12`, [tid, mid]);
      rak.forEach(r => { if (r.rid) idSet.add(r.rid); push(r.ts, "rakip", "🏷️", "Rakip fiyatı — " + [r.rakip_marka, r.ebat].filter(Boolean).join(" ") + (r.rakip_fiyat != null ? " " + Number(r.rakip_fiyat).toLocaleString("tr-TR") + " ₺" : ""), "sahadan", r.rid); });
      // alım (son 15; kodla)
      let alim = [];
      if (kod) alim = await q(`SELECT fatura_tarihi ts, marka, ebat, miktar, satir_tutar FROM bi_satis_faturalari
          WHERE tenant_id::text=$1::text AND musteri_kodu=$2 ORDER BY fatura_tarihi DESC LIMIT 15`, [tid, kod]);
      alim.forEach(a => push(a.ts, "alim", "💰", "Alım — " + [a.marka, a.ebat].filter(Boolean).join(" ") + (a.miktar != null ? " ×" + a.miktar : ""), (a.satir_tutar != null ? Number(a.satir_tutar).toLocaleString("tr-TR") + " ₺" : null), null));
      // isim çözümü
      const nameMap = {};
      const ids = [...idSet].filter(Boolean);
      if (ids.length) { const u = await q(`SELECT id::text id, COALESCE(full_name,email,'—') ad FROM users WHERE id::text = ANY($1)`, [ids]); u.forEach(x => nameMap[x.id] = x.ad); }
      ev.forEach(e => { if (e.kim) e.kim = nameMap[e.kim] || null; });
      // sayaçlar (gerçek toplam)
      const cnt = async (sql, p) => { const r = await q(sql, p); return r[0] ? Number(r[0].n) : 0; };
      const sayac = {
        ziyaret: await cnt(`SELECT COUNT(*) n FROM saha_ziyaret WHERE tenant_id=$1 AND musteri_id=$2 AND durum='TAMAMLANDI'`, [tid, mid]),
        not: await cnt(`SELECT COUNT(*) n FROM saha_sinyal WHERE tenant_id=$1 AND musteri_id=$2`, [tid, mid]),
        teklif: await cnt(`SELECT COUNT(*) n FROM saha_teklif WHERE tenant_id=$1 AND musteri_id=$2`, [tid, mid]),
        rakip: await cnt(`SELECT COUNT(*) n FROM saha_rakip_teklif WHERE tenant_id=$1 AND musteri_id=$2`, [tid, mid]),
        alim: kod ? await cnt(`SELECT COUNT(*) n FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND musteri_kodu=$2`, [tid, kod]) : 0
      };
      // açık takipler (saha_sinyal tip=takip veya detay.takip_tarihi, kapanmamış)
      const tkp = await q(`SELECT created_at ts, ozet, rep_id::text rid, detay FROM saha_sinyal
          WHERE tenant_id=$1 AND musteri_id=$2 AND (tip='takip' OR detay ? 'takip_tarihi')
            AND COALESCE((detay->>'kapandi')::boolean, false) = false ORDER BY created_at DESC LIMIT 10`, [tid, mid]);
      const takip = tkp.map(x => ({ ts: (x.ts instanceof Date ? x.ts.toISOString() : x.ts), ozet: x.ozet, kim: x.rid ? (nameMap[x.rid] || null) : null, takip_tarihi: x.detay && x.detay.takip_tarihi || null }));
      // EKG (12 ay): aylık ciro + ziyaret/not günleri + slip ayı
      let ekgAy = [];
      if (kod) ekgAy = await q(`SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay, SUM(satir_tutar)::numeric ciro
          FROM bi_satis_faturalari WHERE tenant_id::text=$1::text AND musteri_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months') GROUP BY 1 ORDER BY 1`, [tid, kod]);
      const ekg = {
        aylar: ekgAy.map(x => ({ ay: x.ay, ciro: Number(x.ciro) || 0 })),
        ziyaret: ziy.filter(z => z.ts).map(z => (z.ts instanceof Date ? z.ts.toISOString() : z.ts)).slice(0, 30),
        isaret: ev.filter(e => (e.tip === "not" || e.tip === "rakip")).map(e => ({ ts: e.ts, tip: e.tip })).slice(0, 20)
      };
      // ── kural-tabanlı özet cümlesi ──
      const tipAd = M.tip === "TICARI" ? "filo" : M.tip === "TUKETICI" ? "toptan" : "";
      const durAd = { aktif: "kendi temposunda alıyor", soguyor: "soğuyor", pasif: "pasifleşti" }[M.durum] || null;
      const sonAlim = alim[0];
      const sonZiy = ziy[0];
      const acikTakip = takip.length;
      const sonRakip = rak[0];
      const ay = (d) => { if (!d) return null; const dd = new Date(d); return isNaN(dd) ? null : ["Oca","Şub","Mar","Nis","May","Haz","Tem","Ağu","Eyl","Eki","Kas","Ara"][dd.getMonth()]; };
      const gunFark = (d) => { if (!d) return null; const dd = new Date(d); return isNaN(dd) ? null : Math.floor((Date.now() - dd.getTime()) / 86400000); };
      let cumle = [];
      const rit = M.ritim != null ? Number(M.ritim) : null;
      if (kod && sonAlim) {
        if (rit != null && M.guven === "yuksek") cumle.push(`Yaklaşık ${rit % 1 ? rit.toFixed(1) : rit} ayda bir alan bir ${tipAd || "müşteri"}.`);
        else cumle.push(`${tipAd ? tipAd[0].toUpperCase() + tipAd.slice(1) : "Müşteri"}.`);
        if (M.durum === "soguyor" || M.durum === "pasif") {
          cumle.push(`Son alım ${ay(sonAlim.ts) || "?"}'da — kendi temposunu aştı, ${durAd}.`);
        } else if (M.durum === "aktif") {
          cumle.push(`Düzenli alıyor, son alım ${ay(sonAlim.ts) || "?"}.`);
        }
      } else if (kod && !sonAlim) {
        cumle.push(`ERP'ye bağlı ama son 12 ayda alım görünmüyor.`);
      } else {
        cumle.push(`ERP eşleşmesi yok — alım/ciro verisi yok.`);
      }
      if (acikTakip) cumle.push(`${acikTakip} açık takip var.`);
      else if (sonRakip && gunFark(sonRakip.ts) != null && gunFark(sonRakip.ts) <= 120) cumle.push(`Sahada rakip fiyatı görülmüş (${ay(sonRakip.ts)}).`);
      if (sayac.ziyaret === 0 && kod && sonAlim) cumle.push(`Uygulamada hiç ziyaret kaydı yok.`);
      else if (sonZiy) cumle.push(`Son ziyaret ${gunFark(sonZiy.ts) != null ? gunFark(sonZiy.ts) + " gün önce" : "—"}.`);
      const ozet = cumle.join(" ");

      ev.sort((a, b) => (b.ts || "").localeCompare(a.ts || ""));
      sayac.toplam = sayac.ziyaret + sayac.not + sayac.teklif + sayac.rakip + sayac.alim;
      sendJson(response, 200, {
        musteri: { id: M.id, firma: M.firma, tip: M.tip, kod: kod || null, sorumlu: M.rid ? (nameMap[M.rid] || null) : null,
                   durum: M.durum || null, ritim: rit, recency_ay: M.recency_ay != null ? Number(M.recency_ay) : null, guven: M.guven || null },
        ozet, sayac, takip, ekg, olaylar: ev.slice(0, 50)
      });
      return;
    }

    // ── MUSTERI_OLAYLAR_V1 — not / takip yaz ──
    if (method === "POST" && (m = path.match(new RegExp(`^/api/saha/musteriler/(${SAHA_UUID_RE})/not$`)))) {
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, mid = m[1];
      const b = await readJson(request);
      const metin = (b.metin || b.ozet || "").toString().trim();
      if (!metin) { sendJson(response, 400, { error: "Not metni gerekli." }); return; }
      const neden = (b.neden || "").toString().slice(0, 40) || null;              // rakip/fiyat/stok/tahsilat/ilişki/mevsim
      const takipTarihi = (b.takip_tarihi || "").toString().slice(0, 10) || null;  // YYYY-MM-DD opsiyonel
      const cr = await query(`SELECT id FROM saha_musteri WHERE tenant_id=$1 AND id=$2 AND aktif=true`, [tid, mid]);
      if (!cr.rowCount) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }
      const tip = takipTarihi ? "takip" : "not";
      const detay = {}; if (neden) detay.neden = neden; if (takipTarihi) detay.takip_tarihi = takipTarihi;
      const onem = neden === "rakip" || neden === "tahsilat" ? 2 : 1;
      const ins = await query(`INSERT INTO saha_sinyal (tenant_id,tip,onem,ozet,detay,kaynak_tip,rep_id,musteri_id,ham_metin)
          VALUES ($1,$2,$3,$4,$5::jsonb,'saha_not',$6,$7,$8) RETURNING id`,
        [tid, tip, onem, metin.slice(0, 400), JSON.stringify(detay), uid, mid, metin]);
      try {
        await query(`INSERT INTO saha_musteri_aksiyon (tenant_id,musteri_id,rapor,tur,aktor_id,aktor_rol,gerekce_metin)
            VALUES ($1,$2,'not','NOT',$3,$4,$5)`, [tid, mid, uid, session.sahaRole || "rep", metin.slice(0, 200)]);
      } catch (e) { console.error("[not aksiyon]", e && e.message); }
      sendJson(response, 200, { ok: true, id: ins.rows[0] && ins.rows[0].id, tip });
      return;
    }

'''
s = s.replace(anchor, BLOCK + anchor, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_OLAYLAR_V1 (server) — olaylar union + not/takip yazma")
