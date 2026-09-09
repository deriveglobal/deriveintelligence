#!/usr/bin/env python3
# SMARTFIYAT_UI_V2 — "Son Alimlar" gorunumu duzeltmesi. Genis tablo mobilde tasiyordu (koyu baslik +
# fiyatlar ekran disinda). Tablo yerine kompakt satir dizilimi: sol=urun+tarih, sag=odedigi + onerilen.
# Onerilen (data-fo-oneri) _foRecent tarafindan doldurulur. saha.js. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "SMARTFIYAT_UI_V2" in s:
    print("smartfiyat2: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTFIYAT_UI_V1" in s, "once SMARTFIYAT_UI_V1 uygulanmali"

START = 'h += `<div style="font-size:11px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.3px;margin:8px 0 4px">Son ${d.son_alimlar.length} Alım</div>'
END = '</tbody></table></div>`;'
i = s.find(START)
assert i != -1, "son_alimlar START bulunamadi"
j = s.find(END, i)
assert j != -1, "son_alimlar END bulunamadi"
j += len(END)

NEW = ('h += `<div style="font-size:11px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:.3px;margin:10px 0 4px">Son ${d.son_alimlar.length} Alım'
       '${["manager","admin"].includes(S.role)?\' <span style="color:#94a3b8;font-weight:400;text-transform:none">· ödediği → önerilen</span>\':\'\'}</div>` /* SMARTFIYAT_UI_V2 */'
       ' + d.son_alimlar.map(a => `<div style="display:flex;align-items:center;gap:10px;padding:7px 2px;border-bottom:1px solid #f1f5f9">'
       '<div style="flex:1;min-width:0">'
       '<div style="color:#0f172a;font-weight:600;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc([a.marka, a.ebat].filter(Boolean).join(" ")) || "—"}</div>'
       '<div style="color:#94a3b8;font-size:10px">${dt(a.fatura_tarihi)}${a.miktar != null ? " · " + Number(a.miktar).toLocaleString("tr-TR") + " ad" : ""}</div>'
       '</div>'
       '<div style="flex:0 0 auto;text-align:right">'
       '<div style="color:#475569;font-size:13px;font-weight:600">${a.birim_fiyat != null ? Number(a.birim_fiyat).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺" : "—"}</div>'
       '${["manager","admin"].includes(S.role)?`<div data-fo-oneri="${esc(a.kalem_kodu||\'\')}" style="font-size:11px;color:#94a3b8;font-weight:700">·</div>`:""}'
       '</div>'
       '</div>`).join("");')

s = s[:i] + NEW + s[j:]
write(FP, s)
print("smartfiyat2: son-alim kompakt satir dizilimine gecti (tablo kaldirildi)")
print("marker count:", s.count("SMARTFIYAT_UI_V2"))
print("DONE.")
