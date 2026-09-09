#!/usr/bin/env python3
# ODEME_VADELERI_MOBIL_V1 — vKokpitMobil()'e "Vade Analizi · Müşteri vs Tedarikçi" bölümü ekler.
# /api/bi/odeme-vadeleri'den kova bazlı dağılım + ağırlıklı ortalama gün + finansman farkı.
# Gruplu yatay bar (müşteri mavi #0284c7 / tedarikçi turuncu #f59e0b). Idempotent.
# saha.js baked-in image; docker build + up gerekir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "saha.js"
s = read(FP)
if "ODEME_VADELERI_MOBIL_V1" in s:
    print("ov-mobil: already present, skip"); print("DONE."); raise SystemExit

# (1) kokpit-data fetch'inden hemen sonra odeme-vadeleri'ni çek (hata olsa da kokpit çalışsın)
a1 = '    const d = await api("/api/bi/kokpit-data");'
n1 = ('    const d = await api("/api/bi/kokpit-data");\n'
      '    let _ov = null; try { _ov = await api("/api/bi/odeme-vadeleri"); } catch (e) { _ov = null; } // ODEME_VADELERI_MOBIL_V1')
assert s.count(a1) == 1, "kokpit-data anchor"
s = s.replace(a1, n1, 1)

# (2) render: </div> kapanışından ÖNCE vade bölümü
a2 = ('    }\n'
      '    h += `</div>`;\n'
      '    m.innerHTML = h;')
ov = r'''    }
    // ODEME_VADELERI_MOBIL_V1 — Müşteri vade vs Tedarikçi vade (gruplu yatay bar)
    if (_ov && _ov.musteri && _ov.tedarikci) {
      const mg = _ov.musteri.ort_gun, tg = _ov.tedarikci.ort_gun, fk = _ov.fark_gun;
      const farkTxt = fk > 0
        ? `Müşteriler <b>${Math.abs(fk)} gün</b> daha geç ödüyor — aradaki farkı sen finanse ediyorsun.`
        : fk < 0
          ? `Tedarikçiler seni <b>${Math.abs(fk)} gün</b> finanse ediyor — nakit lehine.`
          : `Vadeler dengeli.`;
      const farkRenk = fk > 0 ? "#dc2626" : fk < 0 ? "#16a34a" : "#64748b";
      const kv = _ov.kovalar || [];
      const bar = (arr, renk) => kv.map((k, i) => {
        const p = (arr[i] && arr[i].pct) || 0;
        return `<div style="display:flex;align-items:center;gap:6px;margin:2px 0">
          <div style="width:52px;font-size:11px;color:#64748b;text-align:right">${esc(k)}</div>
          <div style="flex:1;background:#f1f5f9;border-radius:3px;height:14px;position:relative;overflow:hidden">
            <div style="width:${Math.min(p,100)}%;background:${renk};height:100%;border-radius:3px"></div>
          </div>
          <div style="width:40px;font-size:11px;color:#0f172a;font-weight:600">${pct(p)}</div>
        </div>`;
      }).join("");
      h += `<div class="kok-sec">
        <div class="kok-sb">💳 Vade Analizi · Müşteri vs Tedarikçi</div>
        <div style="display:flex;gap:8px;margin-bottom:8px">
          <div style="flex:1;background:#f0f9ff;border-radius:8px;padding:8px 10px">
            <div style="font-size:11px;color:#0284c7;font-weight:700">● MÜŞTERİ</div>
            <div style="font-size:18px;font-weight:800;color:#0f172a">${Math.round(mg)} gün</div>
            <div style="font-size:10px;color:#94a3b8">ort. tahsilat vadesi</div>
          </div>
          <div style="flex:1;background:#fffbeb;border-radius:8px;padding:8px 10px">
            <div style="font-size:11px;color:#d97706;font-weight:700">● TEDARİKÇİ</div>
            <div style="font-size:18px;font-weight:800;color:#0f172a">${Math.round(tg)} gün</div>
            <div style="font-size:10px;color:#94a3b8">ort. ödeme vadesi</div>
          </div>
        </div>
        <div style="font-size:12px;color:${farkRenk};line-height:1.5;margin-bottom:10px;padding:6px 8px;background:#f8fafc;border-radius:6px">${farkTxt}</div>
        <div style="font-size:11px;color:#0284c7;font-weight:700;margin:6px 0 2px">Müşteri tahsilat dağılımı</div>
        ${bar(_ov.musteri.dagilim, "#0284c7")}
        <div style="font-size:11px;color:#d97706;font-weight:700;margin:8px 0 2px">Tedarikçi ödeme dağılımı</div>
        ${bar(_ov.tedarikci.dagilim, "#f59e0b")}
      </div>`;
    }
    h += `</div>`;
    m.innerHTML = h;'''
assert s.count(a2) == 1, "render-close anchor"
s = s.replace(a2, ov, 1)

write(FP, s)
print("ov-mobil: fetch + vade bölümü eklendi")
print("DONE.")
