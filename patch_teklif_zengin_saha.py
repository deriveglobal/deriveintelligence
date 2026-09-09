# -*- coding: utf-8 -*-
# SON10_ALIS_UI_V1 (mobil saha.js) — teklif panelinde:
#   (1) son 10 alan musteri -> KATLANABILIR "goster" (modal), ekrani sismez (aykiri paterni)
#   (2) bu yil alis min/medyan/max satiri (kaca sattik'in esi)
#   (3) en ucuz/en pahali yanina TARIH
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "SON10_ALIS_UI_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# (A) _kendiSatisHTML basi: dt formatter + son10HTML (katlanabilir) + alisHTML hazirla
OLD_A = '''  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const talep = k.talep_fiyat;'''
NEW_A = r'''  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const dt = v => v ? new Date(v).toLocaleDateString("tr-TR") : "";
  const talep = k.talep_fiyat;
  // SON10_ALIS_UI_V1 — son 10 alan musteri (katlanabilir) + bu yil alis min/medyan/max
  let son10HTML = "";
  if (k.son_alanlar && k.son_alanlar.length) {
    const s10k = "s10_" + (k.kalem_sira || 0) + "_" + String(k.ebat || "").replace(/\W/g, "");
    window._SON10_KAYIT[s10k] = { urun: (k.marka || "") + " " + (k.ebat || ""), liste: k.son_alanlar };
    son10HTML = `
      <div style="margin-top:3px;font-size:11px">
        👥 <b>Son alan ${k.son_alanlar.length} müşteri</b>
        · <a href="#" onclick="event.preventDefault();_son10Goster('${s10k}')" style="color:#2563eb;text-decoration:underline;font-weight:600">göster</a>
      </div>`;
  }
  let alisHTML = "";
  if (k.kendi_alis && k.kendi_alis.medyan != null) {
    const a = k.kendi_alis;
    alisHTML = `
      <div style="margin-top:4px;font-size:11px;color:#0f172a;border-top:1px dashed #e2e8f0;padding-top:3px">
        <span style="color:#065f46;font-weight:700">📥 Bu ürünü bu yıl kaça aldık</span> (${a.alis_adedi} alış):
        <b>${tl(a.min)}</b> — <b>${tl(a.medyan)}</b> — <b>${tl(a.max)}</b>
      </div>`;
  }'''
assert s.count(OLD_A) == 1, "A anchor count=%d" % s.count(OLD_A)
s = s.replace(OLD_A, NEW_A, 1)

# (B) return icindeki en ucuz/pahali blogu: TARIH ekle + alisHTML + son10HTML yerlestir
OLD_B = '''      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)})
      </div>
      ${aykiriHTML}'''
NEW_B = '''      <div style="font-size:11px;color:#64748b;margin-top:2px">
        En ucuz: <b>${esc(ks.en_ucuz.musteri || "—")}</b> (${tl(ks.en_ucuz.fiyat)}${ks.en_ucuz.tarih ? " · " + dt(ks.en_ucuz.tarih) : ""})<br>
        En pahalı: <b>${esc(ks.en_pahali.musteri || "—")}</b> (${tl(ks.en_pahali.fiyat)}${ks.en_pahali.tarih ? " · " + dt(ks.en_pahali.tarih) : ""})
      </div>
      ${alisHTML}${son10HTML}${aykiriHTML}'''
assert s.count(OLD_B) == 1, "B anchor count=%d" % s.count(OLD_B)
s = s.replace(OLD_B, NEW_B, 1)

# (C) _son10Goster modal fonksiyonu + registry — _aykiriGoster'dan once ekle
OLD_C = 'function _aykiriGoster(anahtar) {'
NEW_C = r'''window._SON10_KAYIT = window._SON10_KAYIT || {};
function _son10Goster(anahtar) {
  const d = window._SON10_KAYIT[anahtar];
  if (!d || !d.liste || !d.liste.length) return;
  const tl = v => v != null ? "₺" + Number(v).toLocaleString("tr-TR") : "—";
  const tarih = t => t ? new Date(t).toLocaleDateString("tr-TR") : "—";
  const satirlar = d.liste.map(function (x) {
    return `
      <tr style="border-top:1px solid #f1f5f9">
        <td style="padding:6px 8px;font-size:12px"><b>${esc(x.musteri || "—")}</b></td>
        <td style="padding:6px 8px;font-size:12px;text-align:right;font-weight:700">${tl(x.fiyat)}</td>
        <td style="padding:6px 8px;font-size:12px;color:#64748b">${tarih(x.tarih)}</td>
      </tr>`;
  }).join("");
  modal(`
    <h3>👥 Son alan müşteriler — ${esc(d.urun)}</h3>
    <div style="font-size:12px;color:#475569;margin-bottom:8px">Bu ürünü bu yıl en son alan müşteriler ve ödedikleri birim fiyat.</div>
    <div style="max-height:340px;overflow:auto;border:1px solid #e2e8f0;border-radius:6px">
      <table style="width:100%;border-collapse:collapse">
        <thead><tr style="background:#f8fafc">
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Müşteri</th>
          <th style="padding:6px 8px;text-align:right;font-size:11px;color:#64748b">Birim fiyat</th>
          <th style="padding:6px 8px;text-align:left;font-size:11px;color:#64748b">Tarih</th>
        </tr></thead>
        <tbody>${satirlar}</tbody>
      </table>
    </div>
  `);
}

function _aykiriGoster(anahtar) {'''
assert s.count(OLD_C) == 1, "C anchor count=%d" % s.count(OLD_C)
s = s.replace(OLD_C, NEW_C, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SON10_ALIS_UI_V1 (saha)")
