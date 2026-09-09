# -*- coding: utf-8 -*-
# KAPSAM_DK_V1 (saha_desktop.js) — Kapsam & Beyaz Alan yönetici sekmesi:
#   tab + rpKapsam render + RENDER kaydı + rpKontrol bar gizleme.
#   İlet/Ata/Sustur(gerekçe+serbest metin) wired; Tümü toggle + Excel; susturulanlar paneli.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) tab ekle (yalnız yönetici — temsilciler grubu gibi)
o1 = '    ...(isMgr ? [["temsilciler", "👥 Temsilciler"]] : []),'
n1 = '    ...(isMgr ? [["kapsam", "📍 Kapsam"], ["temsilciler", "👥 Temsilciler"]] : []),  /* KAPSAM_DK_V1 */'
assert s.count(o1) == 1, "tabs anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpKontrol — kapsam'da tarih barını gizle (90 gün sabit pencere)
o2 = 'if (bar) bar.style.display = (aktif === "risk" || aktif === "rotam") ? "none" : "";'
n2 = 'if (bar) bar.style.display = (aktif === "risk" || aktif === "rotam" || aktif === "kapsam") ? "none" : "";  /* KAPSAM_DK_V1 */'
assert s.count(o2) == 1, "rpKontrol anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) RENDER kaydı
o3 = 'const RENDER = { ozet: rpOzet, ciro: rpCiro, risk: rpRisk, rotam: rpRotam, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };'
n3 = 'const RENDER = { ozet: rpOzet, ciro: rpCiro, risk: rpRisk, rotam: rpRotam, kapsam: rpKapsam, temsilciler: rpTemsilciler, pipeline: rpPipeline, pazar: rpPazar };  /* KAPSAM_DK_V1 */'
assert s.count(o3) == 1, "RENDER anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) rpKapsam fonksiyonu — RENDER satırından önce ekle
FN = r'''  async function rpKapsam() {  /* KAPSAM_DK_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = load();
    let d; try { d = await api(`/api/saha/rapor/kapsam?gun=90${tipQS()}`); } catch (e) { el.innerHTML = hataH(e); return; }
    const yon = d.rol === "yonetici", o = d.ozet || {};
    const CSS = `<style>
      .kap{--z0:#FBFBFA;--z1:#FFF;--z2:#F4F4F2;--cz:rgba(0,0,0,.09);--t0:#16161A;--t1:#5F5F66;--t2:#85858C;--t3:#A8A8AE;--kr:#C43D28;--krz:#FDF0ED;--sr:#8A5D06;--srz:#FEF6E7;--ys:#106B4A;--ysz:#EAF7F1;--mv:#2563eb;--mvz:#EEF3FE;--mo:#6D5AE0;--moz:#F0EDFB;color-scheme:light;color:var(--t0)}
      .kap *{box-sizing:border-box}
      .kap-kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:11px;margin:2px 0 16px}
      .kap-kpi{background:var(--z1);border:1px solid var(--cz);border-radius:14px;padding:13px 14px;position:relative;overflow:hidden}
      .kap-kpi:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px}
      .kap-kpi.a:before{background:var(--mv)}.kap-kpi.b:before{background:var(--ys)}.kap-kpi.c:before{background:var(--kr)}.kap-kpi.d:before{background:var(--sr)}
      .kap-kpi .n{font-size:23px;font-weight:800;letter-spacing:-.02em;line-height:1}.kap-kpi.c .n{color:var(--kr)}.kap-kpi.d .n{color:var(--sr)}
      .kap-kpi .l{font-size:11px;color:var(--t1);margin-top:6px;font-weight:600}.kap-kpi .sx{font-size:10px;color:var(--t2);margin-top:2px}
      .kap-card{background:var(--z1);border:1px solid var(--cz);border-radius:14px;padding:14px 15px;margin-bottom:14px}
      .kap-h{font-size:13px;font-weight:800;display:flex;align-items:center;gap:7px;margin-bottom:3px}
      .kap-cd{font-size:11px;color:var(--t2);margin-bottom:11px}
      .kap table{width:100%;border-collapse:collapse}
      .kap th{font-size:9.5px;text-transform:uppercase;letter-spacing:.04em;color:var(--t2);font-weight:700;text-align:left;padding:0 8px 8px}
      .kap th.kap-r,.kap td.kap-r{text-align:right}
      .kap td{padding:9px 8px;border-top:1px solid var(--cz);font-size:12.5px;vertical-align:middle}
      .kap-firma{font-weight:600}.kap-sub{font-size:10px;color:var(--t2);margin-top:2px}.kap-mut{color:var(--t2)}.kap-money{font-variant-numeric:tabular-nums;font-weight:700}
      .kap-num{color:var(--t3);font-weight:700;width:26px}
      .kap-bar{height:8px;background:var(--z2);border-radius:99px;overflow:hidden;min-width:64px;display:inline-block;width:120px;vertical-align:middle}
      .kap-bar>i{display:block;height:100%;border-radius:99px}.kap-bar>i.g{background:var(--ys)}.kap-bar>i.a{background:var(--sr)}.kap-bar>i.r{background:var(--kr)}.kap-bar>i.b{background:var(--mv)}
      .kap-pct{font-weight:800;font-variant-numeric:tabular-nums;margin-left:8px;font-size:12px}
      .kap-c{font-size:10px;font-weight:700;padding:1px 7px;border-radius:99px}.kap-c.hic{color:var(--kr);background:var(--krz)}.kap-c.eski{color:var(--sr);background:var(--srz)}
      .kap-d{font-size:9.5px}.kap-d.beyaz{color:var(--kr)}.kap-d.eslesmemis{color:var(--mo)}.kap-d.ulasildi{color:var(--ys)}.kap-d.susturuldu{color:var(--t2)}
      .kap-acts{display:flex;gap:5px;justify-content:flex-end;flex-wrap:wrap}
      .kap-act{font-size:11px;font-weight:700;padding:5px 8px;border-radius:7px;cursor:pointer;border:1px solid var(--cz);background:var(--z1);color:var(--t1)}
      .kap-act.pri{background:var(--t0);color:#fff;border-color:var(--t0)}.kap-act.esles{background:var(--moz);color:var(--mo);border-color:rgba(109,90,224,.25)}.kap-act.dis{background:var(--krz);color:var(--kr);border-color:rgba(196,61,40,.2)}
      .kap-seg2{display:grid;grid-template-columns:1fr 1fr;gap:12px}
      .kap-sb{border:1px solid var(--cz);border-radius:11px;padding:12px 13px}.kap-sb .t{font-size:11px;font-weight:700;color:var(--t1);display:flex;justify-content:space-between}.kap-sb .big{font-size:21px;font-weight:800;margin:5px 0 8px}
      .kap-tool{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap;margin-bottom:10px}
      .kap-tg{display:inline-flex;background:var(--z2);border:1px solid var(--cz);border-radius:8px;padding:2px}
      .kap-tg span{font-size:11px;font-weight:700;padding:5px 10px;border-radius:6px;color:var(--t2);cursor:pointer}.kap-tg span.on{background:var(--z1);color:var(--t0);box-shadow:0 1px 2px rgba(0,0,0,.05)}
      .kap-learn{display:flex;gap:9px;background:var(--mvz);border:1px solid rgba(37,99,235,.16);border-radius:11px;padding:10px 12px;margin-top:11px;font-size:11.5px;color:var(--t1);line-height:1.5}.kap-learn b{color:var(--t0)}
      .kap-reason{margin:8px 0;padding:10px 11px;background:var(--z2);border:1px dashed var(--cz);border-radius:9px}.kap-reason .q{font-size:11px;font-weight:700;color:var(--t1);margin-bottom:7px}
      .kap-opts{display:flex;gap:5px;flex-wrap:wrap}.kap-ropt{font-size:11px;font-weight:700;padding:4px 9px;border-radius:99px;border:1px solid var(--cz);background:var(--z1);color:var(--t1);cursor:pointer}.kap-ropt.sel{background:var(--kr);color:#fff;border-color:var(--kr)}
      .kap-in{margin-top:7px;width:100%;font-size:12px;padding:7px 9px;border:1px solid var(--cz);border-radius:7px;background:var(--z1);color:var(--t0)}
      .kap-sel{font-size:12px;padding:6px 9px;border:1px solid var(--cz);border-radius:7px;background:var(--z1);color:var(--t0)}
      .kap i.ib{cursor:help;color:var(--t3);font-style:normal}
      .kap details{border:1px solid var(--cz);border-radius:11px;background:var(--z1);margin-top:12px;overflow:hidden}
      .kap summary{cursor:pointer;list-style:none;padding:11px 13px;font-size:12.5px;font-weight:800;display:flex;gap:7px;align-items:center}.kap summary::-webkit-details-marker{display:none}.kap summary:after{content:'▾';margin-left:auto;color:var(--t2)}.kap details[open] summary:after{content:'▴'}
      .kap-db{padding:2px 14px 13px;font-size:11.5px;color:var(--t1);line-height:1.6}.kap-db p{margin:0 0 7px}.kap-db b{color:var(--t0)}
      .kap-empty{padding:26px;text-align:center;color:var(--t2);font-size:12.5px}
    </style>`;
    const kisa = (n) => { n = Number(n) || 0; const a = Math.abs(n); if (a >= 1e9) return (n / 1e9).toFixed(1).replace(".", ",") + " Mr ₺"; if (a >= 1e6) return (n / 1e6).toFixed(1).replace(".", ",") + " M ₺"; if (a >= 1e3) return Math.round(n / 1e3) + " B ₺"; return Math.round(n) + " ₺"; };
    const sonTxt = (g) => g == null ? `<span class="kap-c hic">hiç</span>` : g > 45 ? `<span class="kap-c eski">${g} gün</span>` : `${g} gün`;
    const tier = (p) => p >= 60 ? "g" : p >= 35 ? "a" : "r";
    const bar = (pct, cls) => `<span class="kap-bar"><i class="${cls}" style="width:${Math.min(100, pct)}%"></i></span><span class="kap-pct">${pct}%</span>`;
    const reps = (d.temsilci || []).map(t => [t.rep_id, t.rep]);
    const segEt = (t) => t === "TICARI" ? "Ticari" : t === "TUKETICI" ? "Tüketici" : (t || "");
    const list = S._kapAll ? (d.hepsi || []) : (d.beyaz || []);
    const durEt = { ulasildi: "ulaşıldı", beyaz: "beyaz alan", eslesmemis: "eşleşmemiş", susturuldu: "susturuldu" };
    const rowActs = (x) => yon
      ? `<button class="kap-act pri" data-aks="ILET" data-mid="${esc(x.id)}">📌 İlet</button><button class="kap-act" data-aks="ATA" data-mid="${esc(x.id)}">👤 Ata</button><button class="kap-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button>`
      : `<button class="kap-act pri" data-aks="GITTIM" data-mid="${esc(x.id)}">✔️ Gittim</button><button class="kap-act" data-aks="PLANLA" data-mid="${esc(x.id)}">📅 Planla</button><button class="kap-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button>`;
    const listRows = list.map((x, i) => `<tr data-row="${esc(x.id)}"><td class="kap-num">${i + 1}</td><td class="kap-firma">${esc(x.firma)}<div class="kap-sub">${esc(x.il || "—")}${x.tip ? " · " + segEt(x.tip) : ""}${(S._kapAll && x.durum) ? ` · <b class="kap-d ${x.durum}">${durEt[x.durum] || x.durum}</b>` : ""}</div></td><td class="kap-r kap-money">${x.ciro > 0 ? money(x.ciro) : "<span class='kap-mut'>—</span>"}</td><td>${sonTxt(x.gun)}</td>${yon ? `<td class="kap-mut">${esc(x.rep || "—")}</td>` : ""}<td class="kap-r"><div class="kap-acts">${rowActs(x)}</div></td></tr>`).join("");
    const sehirRows = (d.sehir || []).map(c => `<tr><td class="kap-firma">${esc(c.il)}</td><td class="kap-r">${c.portfoy}</td><td class="kap-r">${c.ulasilan}</td><td>${bar(c.kapsam, tier(c.kapsam))}</td><td class="kap-r kap-money" style="color:${c.beyaz_ciro > 0 ? "var(--kr)" : "var(--t2)"}">${kisa(c.beyaz_ciro)}</td></tr>`).join("");
    const repRows = (d.temsilci || []).map(t => `<tr><td class="kap-firma">${esc(t.rep)}</td><td class="kap-r">${t.portfoy}</td><td>${bar(t.kapsam, tier(t.kapsam))}</td><td class="kap-r">${t.beyaz_sayi}</td><td class="kap-r kap-money">${kisa(t.beyaz_ciro)}</td></tr>`).join("");
    const seg = d.segment || [];
    const segBox = (key, ico, ad) => { const g = seg.find(x => x.seg === key) || { portfoy: 0, ulasilan: 0, kapsam: 0, beyaz_ciro: 0 }; return `<div class="kap-sb"><div class="t"><span>${ico} ${ad}</span><span class="kap-mut">${g.portfoy} müşteri</span></div><div class="big">${g.kapsam}%</div>${bar(g.kapsam, tier(g.kapsam)).split('<span class="kap-pct"')[0]}<div class="kap-sub" style="margin-top:7px">${g.ulasilan} ulaşıldı · beyaz alan ${kisa(g.beyaz_ciro)}</div></div>`; };
    const esizRows = (d.eslesmemis || []).map(x => `<tr data-row="${esc(x.id)}"><td class="kap-firma">${esc(x.firma)}<div class="kap-sub">${esc(x.il || "—")}</div></td><td>${sonTxt(x.gun)}</td>${yon ? `<td class="kap-mut">${esc(x.rep || "—")}</td>` : ""}<td class="kap-r"><div class="kap-acts"><button class="kap-act esles" data-esles="${esc(x.id)}">🔗 Eşleştir</button>${yon ? `<button class="kap-act" data-aks="ATA" data-mid="${esc(x.id)}">👤 Ata</button>` : ""}<button class="kap-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button></div></td></tr>`).join("");
    const susList = (d.susturulan || []);
    const susRows = susList.map(x => `<tr data-row="${esc(x.id)}"><td class="kap-firma">${esc(x.firma)}</td><td class="kap-mut">${esc(x.mute_by || "—")}</td><td>${({ KAPANDI: "Kapandı", RAKIP: "Rakibe geçti", SEZON: "Sezon dışı", PAS: "Bilinçli pas", YANLIS: "Yanlış kayıt", DIGER: "Diğer" })[x.gerekce] || x.gerekce || "—"}${x.gerekce_metin ? ` <span class="kap-mut">"${esc(x.gerekce_metin)}"</span>` : ""}</td><td class="kap-r"><button class="kap-act" data-geri="${esc(x.id)}">geri al</button></td></tr>`).join("");

    el.innerHTML = CSS + `<div class="kap">
      <div class="kap-kpis">
        <div class="kap-kpi a" title="Son 90 günde ≥1 TAMAMLANDI ziyaret alan farklı müşteri ÷ aktif portföy."><div class="n">${o.kapsam || 0}%</div><div class="l">Portföy kapsamı ⓘ</div><div class="sx">${o.ulasilan || 0} / ${o.portfoy || 0} · son 90 gün</div></div>
        <div class="kap-kpi b" title="Son 90 günde en az bir tamamlanan ziyaret alan farklı müşteri."><div class="n">${o.ulasilan || 0}</div><div class="l">Ulaşılan müşteri ⓘ</div><div class="sx">son 90 günde ≥1 ziyaret</div></div>
        <div class="kap-kpi c" title="Son 12 ay cirosu>0 olan ve son 90 günde hiç ziyaret edilmeyen eşleşmiş müşteriler."><div class="n">${o.beyaz_sayi || 0}</div><div class="l">Beyaz alan (değerli) ⓘ</div><div class="sx">cirosu var, 90 günde ziyaret yok</div></div>
        <div class="kap-kpi d" title="Yukarıdaki müşterilerin son 12 ay (yuvarlanan) toplam cirosu."><div class="n">${kisa(o.beyaz_ciro || 0)}</div><div class="l">Beyaz alandaki ciro (12 ay) ⓘ</div><div class="sx">dokunulmayan gelir</div></div>
      </div>
      ${yon ? `<div class="kap-card"><div class="kap-h">🗺️ Şehir bazında kapsam</div><div class="kap-cd">En çok dokunulmayan cirosu olan şehir üstte.</div><table><thead><tr><th>Şehir</th><th class="kap-r">Portföy</th><th class="kap-r">Ulaşılan</th><th>Kapsam</th><th class="kap-r">Beyaz alan ₺</th></tr></thead><tbody>${sehirRows || `<tr><td colspan="5" class="kap-empty">—</td></tr>`}</tbody></table></div>` : ""}
      <div class="kap-card"><div class="kap-h">🏷️ Segment kapsamı</div><div class="kap-seg2">${segBox("TICARI", "🔧", "Ticari")}${segBox("TUKETICI", "🚗", "Tüketici")}</div></div>
      ${yon ? `<div class="kap-card"><div class="kap-h">👥 Temsilci bazında kapsam</div><div class="kap-cd">Her temsilci kendi kitabının ne kadarını tarıyor, arkasında ne kadar beyaz alan bırakıyor.</div><table><thead><tr><th>Temsilci</th><th class="kap-r">Portföy</th><th>Kapsam</th><th class="kap-r">Beyaz alan</th><th class="kap-r">Beyaz alan ₺</th></tr></thead><tbody>${repRows || `<tr><td colspan="5" class="kap-empty">—</td></tr>`}</tbody></table></div>` : ""}
      <div class="kap-card">
        <div class="kap-tool"><div class="kap-h" style="margin:0">💰 ${S._kapAll ? "Tüm müşteriler" : "Beyaz alan — dokunulmayan değerli müşteriler"}</div>
          <div style="display:flex;gap:7px;align-items:center"><div class="kap-tg"><span class="${S._kapAll ? "" : "on"}" data-kaptg="beyaz">Beyaz alan</span><span class="${S._kapAll ? "on" : ""}" data-kaptg="tum">Tüm müşteriler</span></div><button class="kap-act" data-xls="1">⬇ Excel</button></div>
        </div>
        <div class="kap-cd"><b>Uygulamada kayıtlı</b> ziyareti olmayan değerli müşteriler; yıllık ciroya (son 12 ay) göre sıralı. Her satırda aksiyon al — <b>loglanır ve öğrenilir</b>.</div>
        <table><thead><tr><th class="kap-num">#</th><th>Müşteri</th><th class="kap-r">Yıllık ciro <i class="ib" title="Son 12 ay yuvarlanan — ERP satış faturaları, musteri_kodu eşleşmeli. YTD DEĞİL.">ⓘ</i></th><th>Son ziyaret <i class="ib" title="En son TAMAMLANDI ziyaret (tüm zamanlar).">ⓘ</i></th>${yon ? "<th>Sorumlu</th>" : ""}<th class="kap-r">Aksiyon</th></tr></thead><tbody id="kap-list">${listRows || `<tr><td colspan="${yon ? 6 : 5}" class="kap-empty">🎉 Bu kırılımda beyaz alan yok.</td></tr>`}</tbody></table>
        <div class="kap-learn">🧠 <div><b>Her aksiyon loglanır — hiçbiri boşa gitmez.</b> ${yon ? "<b>📌 İlet</b> → sorumlu temsilcinin Sabah Rotam'ına düşer. <b>👤 Ata</b> → sorumluyu değiştirir. " : "<b>✔️ Gittim</b> → ziyaret geri-yazılır (kayıtsız temas kapanır). <b>📅 Planla</b> → Sabah Rotam'ına düşer. "}<b>🔇 Sustur</b> → gerekçesiyle listeden çıkar${yon ? "" : ", yönetici görür"}; gerekçeler <b>beyaz alan neden kapanıyor</b> sinyaline döner.</div></div>
        ${(!S._kapAll && d.beyaz_toplam > (d.beyaz || []).length) ? `<div class="kap-sub" style="margin-top:9px">+ ${d.beyaz_toplam - d.beyaz.length} müşteri daha · Excel ile tümü</div>` : ""}
      </div>
      <div class="kap-card" style="border-color:rgba(196,61,40,.3)"><div class="kap-h">⚠️ Eşleşmemiş beyaz alan — kör nokta</div><div class="kap-cd">ERP'ye (<code>musteri_kodu</code>) bağlı değil → cirosu görünmüyor. <b>${o.eslesmemis_sayi || 0}</b> müşteri; önce eşleştir, sonra değerini gör.</div><table><thead><tr><th>Müşteri</th><th>Son ziyaret</th>${yon ? "<th>Sorumlu</th>" : ""}<th class="kap-r">Aksiyon</th></tr></thead><tbody id="kap-esiz">${esizRows || `<tr><td colspan="${yon ? 4 : 3}" class="kap-empty">Eşleşmemiş kör nokta yok.</td></tr>`}</tbody></table>${(d.eslesmemis_toplam > (d.eslesmemis || []).length) ? `<div class="kap-sub" style="margin-top:9px">+ ${d.eslesmemis_toplam - d.eslesmemis.length} müşteri daha</div>` : ""}</div>
      ${yon && susRows ? `<div class="kap-card"><div class="kap-h">🔇 Susturulanlar — gerekçeli</div><div class="kap-cd">Ekibin "hedef değil" dediği müşteriler; gerekçesiyle. Geri alabilirsin.</div><table><thead><tr><th>Müşteri</th><th>Susturan</th><th>Gerekçe</th><th class="kap-r"></th></tr></thead><tbody id="kap-sus">${susRows}</tbody></table></div>` : ""}
      <details><summary>🔍 Bu rapor nasıl hesaplanıyor?</summary><div class="kap-db">
        <p><b>⏱ İki pencere:</b> <b>Kapsam</b> = son 90 gün (tarama). <b>Ciro/değer</b> = son 12 ay yuvarlanan (YTD değil), ERP faturaları <code>musteri_kodu</code> eşleşmeli.</p>
        <p><b>Kapsam</b> = 90 günde ≥1 TAMAMLANDI ziyaretli farklı müşteri ÷ portföy. Yalnız uygulamada kayıtlı ziyaret sayılır.</p>
        <p><b>Beyaz alan</b> = cirosu>0, 90 günde ziyaret yok, eşleşmiş. <b>Eşleşmemiş</b> = kod yok → değeri görünmez, ayrı blok.</p>
        <p><b>Aksiyon & öğrenme:</b> her aksiyon <code>saha_musteri_aksiyon</code>'a loglanır; susturulanlar rapordan düşer ama yönetici görür; gerekçeler sinyale döner. Ölü buton yok.</p>
      </div></details>
    </div>`;

    // ── wiring ──
    const reload = () => rpKapsam();
    const post = async (mid, tur, extra) => { try { await api(`/api/saha/musteri-aksiyon`, { method: "POST", body: JSON.stringify({ musteri_id: mid, tur, ...(extra || {}) }) }); reload(); } catch (e) { alert("Olmadı: " + (e.message || e)); } };
    // toggle
    el.querySelectorAll("[data-kaptg]").forEach(b => b.addEventListener("click", () => { S._kapAll = b.dataset.kaptg === "tum"; reload(); }));
    // Excel
    const xls = el.querySelector("[data-xls]"); if (xls) xls.addEventListener("click", async () => { xls.textContent = "…"; try { const res = await fetch(`/api/saha/rapor/kapsam-export?gun=90${tipQS()}`, { headers: S.headers() }); const blob = await res.blob(); const a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = "kapsam-beyaz-alan.csv"; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 4000); } catch (e) { alert("İndirilemedi: " + (e.message || e)); } finally { xls.textContent = "⬇ Excel"; } });
    // direkt aksiyonlar + inline picker
    el.querySelectorAll("[data-aks]").forEach(b => b.addEventListener("click", () => {
      const mid = b.dataset.mid, tur = b.dataset.aks, tr = b.closest("tr"); if (!tr) return;
      if (tur === "ILET" || tur === "GITTIM" || tur === "PLANLA") { post(mid, tur); return; }
      if (el.querySelector(".kap-picker")) el.querySelectorAll(".kap-picker").forEach(p => p.remove());
      const holder = document.createElement("tr"); holder.className = "kap-picker";
      const span = tr.querySelectorAll("td").length;
      if (tur === "SUSTUR") {
        holder.innerHTML = `<td colspan="${span}"><div class="kap-reason"><div class="q">🔇 Neden susturuluyor? — listeden düşer, ${yon ? "loglanır" : "yönetici görür"}</div><div class="kap-opts">${[["KAPANDI", "Kapandı"], ["RAKIP", "Rakibe geçti"], ["SEZON", "Sezon dışı"], ["PAS", "Bilinçli pas"], ["YANLIS", "Yanlış kayıt"], ["DIGER", "Diğer…"]].map(([v, l]) => `<span class="kap-ropt" data-g="${v}">${l}</span>`).join("")}</div><input class="kap-in" placeholder="Diğer / ek açıklama (opsiyonel) — yönetici görür"><div style="display:flex;gap:6px;margin-top:8px"><button class="kap-act dis" data-ok="1">🔇 Sustur</button><button class="kap-act" data-cancel="1">Vazgeç</button></div></div></td>`;
        tr.after(holder);
        let g = null; holder.querySelectorAll(".kap-ropt").forEach(r => r.addEventListener("click", () => { holder.querySelectorAll(".kap-ropt").forEach(x => x.classList.remove("sel")); r.classList.add("sel"); g = r.dataset.g; }));
        holder.querySelector("[data-cancel]").addEventListener("click", () => holder.remove());
        holder.querySelector("[data-ok]").addEventListener("click", () => { const txt = holder.querySelector(".kap-in").value.trim(); if (!g && !txt) { alert("Gerekçe seç ya da yaz."); return; } post(mid, "SUSTUR", { gerekce: g || "DIGER", gerekce_metin: txt || null }); });
      } else if (tur === "ATA") {
        const opts = reps.map(([id, ad]) => `<option value="${esc(id)}">${esc(ad)}</option>`).join("");
        holder.innerHTML = `<td colspan="${span}"><div class="kap-reason"><div class="q">👤 Sorumlu temsilci ata</div><select class="kap-sel" data-rep>${opts || `<option value="">— temsilci yok —</option>`}</select> <button class="kap-act pri" data-ok="1">Ata</button> <button class="kap-act" data-cancel="1">Vazgeç</button></div></td>`;
        tr.after(holder);
        holder.querySelector("[data-cancel]").addEventListener("click", () => holder.remove());
        holder.querySelector("[data-ok]").addEventListener("click", () => { const rep = holder.querySelector("[data-rep]").value; if (!rep) { alert("Temsilci seç."); return; } post(mid, "ATA", { hedef_rep: rep }); });
      }
    }));
    // Eşleştir → müşteriler
    el.querySelectorAll("[data-esles]").forEach(b => b.addEventListener("click", () => { try { go("musteriler"); } catch (e) {} }));
    // geri al
    el.querySelectorAll("[data-geri]").forEach(b => b.addEventListener("click", () => post(b.dataset.geri, "GERI_AL")));
  }

'''
o4 = '  const RENDER = { ozet: rpOzet,'
assert s.count(o4) == 1, "RENDER insert anchor=%d" % s.count(o4)
s = s.replace(o4, FN + o4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_DK_V1 (saha_desktop.js)")
