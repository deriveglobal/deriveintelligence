#!/usr/bin/env python3
# TEKLIF_REVIZE_V1 (client) — teklifDetayModal:
#   - "🔄 Revize et" butonu (ONAY_BEKLIYOR/ONAYLANDI/SUNULDU/KAYBEDILDI) → PUT action:revize
#   - Yanlis yonlendiren "✏ Düzenle" artik yalniz TASLAK'ta (ONAYLANDI/SUNULDU'da 400 veriyordu)
#   - Basliga "Rev.N" rozeti (revizyon_no>1)
#   Idempotent (marker: td-revize).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src

if "td-revize" in src:
    print("[=] td-revize zaten mevcut (idempotent)")
    sys.exit(0)

# ── 1) Baslik: Rev.N rozeti ──
h3_old = '      <h3 style="margin:0">${esc(t.firma)}</h3>'
h3_new = ('      <h3 style="margin:0">${esc(t.firma)}'
          '${t.revizyon_no > 1 ? ` <span style="font-size:12px;color:#7c3aed;font-weight:700;vertical-align:middle">Rev.${t.revizyon_no}</span>` : ""}'
          '</h3>')
if h3_old not in src:
    print("HATA: h3 firma anchor bulunamadi"); sys.exit(1)
src = src.replace(h3_old, h3_new, 1)
print("[+] Rev.N rozeti eklendi")

# ── 2) Butonlar: revize ekle + duzenle'yi TASLAK ile sinirla ──
btn_old = ('      ${!["KAZANILDI","KAYBEDILDI","IPTAL","ONAY_BEKLIYOR"].includes(t.durum) ? `\n'
           '        <button class="btn" id="td-duzenle">✏ Düzenle</button>` : ""}')
btn_new = ('      ${["ONAY_BEKLIYOR","ONAYLANDI","SUNULDU","KAYBEDILDI"].includes(t.durum) ? `\n'
           '        <button class="btn kucuk" id="td-revize" title="Yeni sürüm (taslak) oluştur">🔄 Revize et</button>` : ""}\n'
           '      ${t.durum === "TASLAK" ? `\n'
           '        <button class="btn" id="td-duzenle">✏ Düzenle</button>` : ""}')
if btn_old not in src:
    print("HATA: duzenle buton anchor bulunamadi"); sys.exit(1)
src = src.replace(btn_old, btn_new, 1)
print("[+] Revize butonu eklendi; Düzenle TASLAK ile sinirlandi")

# ── 3) Handler ──
h_anchor = ('  document.getElementById("td-duzenle")?.addEventListener("click", () => {\n'
            '    kapatModal(); teklifDuzenleModal(t);\n'
            '  });')
h_new = h_anchor + '''
  document.getElementById("td-revize")?.addEventListener("click", async () => {  // TEKLIF_REVIZE_V1
    const _dl = (TEKLIF_DURUM[t.durum] || [t.durum])[0];
    if (!confirm(`"${t.firma}" teklifinin yeni bir sürümü (düzenlenebilir taslak) oluşturulacak.\\n\\nOrijinal "${_dl}" olarak KALIR; kopyası taslak olarak Teklifler listesinin başına eklenir. Devam edilsin mi?`)) return;
    try {
      const r = await api(`/api/saha/teklifler/${t.id}`, { method: "PUT", body: JSON.stringify({ action: "revize" }) });
      kapatModal();
      uyari(`✓ Rev.${r.revizyon_no || ""} taslağı oluşturuldu — Teklifler listesinin başında düzenleyip yeniden gönderebilirsiniz.`, true);
      loadView("iskonto");
    } catch (e) { uyari(e.message); }
  });'''
if h_anchor not in src:
    print("HATA: td-duzenle handler anchor bulunamadi"); sys.exit(1)
src = src.replace(h_anchor, h_new, 1)
print("[+] Revize handler eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
