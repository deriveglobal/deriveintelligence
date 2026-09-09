#!/usr/bin/env python3
# MUSTERI_OLAYLAR_ZIYARET_TIK_V1 (client) — Ozellik (Fatih): Musteri Karti "Hareketler"de ziyaret
#   satirlarina da dokunulabilsin. Fatih secimi: "kartin ustunde katman" (kart yerinde kalir).
#   Dokununca stacked overlay acilir: tarih/temsilci/konum/katilimcilar + tam not + FOTOGRAFLAR
#   (fotoUrl/fotoBuyut ile). "Ziyaret detayini ac" → tam ziyaretDetayModal (yorum/duzenle/sil/+Teklif).
#   Onkosul: MUSTERI_HATIRLATMA_DUZENLE_V1 (client, satir sablonu+wiring) + V2 (overlay _mkHatDuzenle)
#   ve server MUSTERI_OLAYLAR_ZIYARET_FIX_V1 (o.zid payload) CANLI.
#   Idempotent (marker: MUSTERI_OLAYLAR_ZIYARET_TIK_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_OLAYLAR_ZIYARET_TIK_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) Satir sablonu (V1 client hali) → ziyaret (o.zid) de tiklanabilir
old_row = '''          ${list.map(o => `<div class="mk-ev${o.sid ? " mk-ev-tik" + (o.skapandi ? " mk-ev-done" : "") : ""}"${o.sid ? ` data-sid="${o.sid}"` : ""}><div class="mk-ic">${o.sid && o.skapandi ? "✅" : (_mkIK[o.tip] || "•")}</div><div class="mk-c"><div class="mk-m">${esc(String(o.baslik || ""))}${o.sid && o.stakip ? ` <span class="mk-tkd">📅 ${esc(String(o.stakip))}</span>` : ""}</div>${(o.alt || o.kim) ? `<div class="mk-s">${[o.alt, o.kim].filter(Boolean).map(x => esc(String(x))).join(" · ")}</div>` : ""}</div><div class="mk-r">${_mkGun(o.ts)}${o.sid ? " ✎" : ""}</div></div>`).join("") || `<div class="mk-empty">Kayıt yok.</div>`}  <!-- MUSTERI_HATIRLATMA_DUZENLE_V1 -->'''
new_row = '''          ${list.map(o => `<div class="mk-ev${(o.sid || o.zid) ? " mk-ev-tik" : ""}${o.sid && o.skapandi ? " mk-ev-done" : ""}"${o.sid ? ` data-sid="${o.sid}"` : ""}${o.zid ? ` data-zid="${o.zid}"` : ""}><div class="mk-ic">${o.sid && o.skapandi ? "✅" : (_mkIK[o.tip] || "•")}</div><div class="mk-c"><div class="mk-m">${esc(String(o.baslik || ""))}${o.sid && o.stakip ? ` <span class="mk-tkd">📅 ${esc(String(o.stakip))}</span>` : ""}</div>${(o.alt || o.kim) ? `<div class="mk-s">${[o.alt, o.kim].filter(Boolean).map(x => esc(String(x))).join(" · ")}</div>` : ""}</div><div class="mk-r">${_mkGun(o.ts)}${o.sid ? " ✎" : o.zid ? " ›" : ""}</div></div>`).join("") || `<div class="mk-empty">Kayıt yok.</div>`}  <!-- MUSTERI_HATIRLATMA_DUZENLE_V1 / ''' + MARK + ''' -->'''
if old_row not in src:
    print("HATA: V1 satir sablonu anchor bulunamadi"); sys.exit(1)
src = src.replace(old_row, new_row, 1)
print("[+] satir sablonu: ziyaret (o.zid) tiklanabilir")

# 2) Tiklama wiring (V1 hali) → sid/zid dallanmasi
old_wire = '''      hare.querySelectorAll(".mk-ev-tik").forEach(el => el.addEventListener("click", (e) => {  /* MUSTERI_HATIRLATMA_DUZENLE_V1 */
        e.stopPropagation();
        const o = (d.olaylar || []).find(x => String(x.sid) === String(el.dataset.sid));
        if (o) _mkHatDuzenle(o);
      }));'''
new_wire = '''      hare.querySelectorAll(".mk-ev-tik").forEach(el => el.addEventListener("click", (e) => {  /* MUSTERI_HATIRLATMA_DUZENLE_V1 / ''' + MARK + ''' */
        e.stopPropagation();
        if (el.dataset.sid) { const o = (d.olaylar || []).find(x => String(x.sid) === String(el.dataset.sid)); if (o) _mkHatDuzenle(o); }
        else if (el.dataset.zid) { _mkZiyaretAc(el.dataset.zid); }
      }));'''
if old_wire not in src:
    print("HATA: V1 tiklama wiring anchor bulunamadi"); sys.exit(1)
src = src.replace(old_wire, new_wire, 1)
print("[+] wiring: sid→_mkHatDuzenle, zid→_mkZiyaretAc")

# 3) _mkZiyaretAc'i _mkHatDuzenle (V2) fonksiyonundan sonra ekle
old_end = '''      lay.querySelector("#mkd-geriac")?.addEventListener("click", () => put({ tamamla: false }, "↩︎ Geri açıldı."));
    }'''
new_end = old_end + '''
    async function _mkZiyaretAc(zid) {  /* ''' + MARK + ''' — kartin ustunde katman: ziyaret onizleme + foto */
      const kok = document.getElementById("saha-modal"); if (!kok) return;
      const lay = document.createElement("div");
      lay.className = "modal-fon mkz-fon";
      lay.style.zIndex = "70";
      lay.innerHTML = `<div class="modal-kutu" style="max-width:min(95vw,560px)">
        <h3>Ziyaret</h3>
        <div id="mkz-govde" style="font-size:13px;color:#334155">Yükleniyor…</div>
        <div class="modal-btnlar" style="flex-wrap:wrap;gap:8px;margin-top:12px">
          <button class="btn gri" id="mkz-kapat">Kapat</button>
          <button class="btn" id="mkz-detay">Ziyaret detayını aç</button>
        </div></div>`;
      kok.appendChild(lay);
      const kapat = () => { lay.remove(); };
      lay.addEventListener("click", (ev) => { if (ev.target === lay) kapat(); });
      lay.querySelector("#mkz-kapat")?.addEventListener("click", kapat);
      lay.querySelector("#mkz-detay")?.addEventListener("click", () => { kapat(); ziyaretDetayModal(zid); });
      let z = null;
      try { z = (await api(`/api/saha/ziyaretler/${zid}`)).ziyaret; } catch (e) {}
      const gov = lay.querySelector("#mkz-govde"); if (!gov) return;
      if (!z) { gov.textContent = "Ziyaret yüklenemedi."; return; }
      const d = z.detay || {};
      const satir = (l, v) => v ? `<div class="det-satir"><span>${esc(l)}</span><b>${esc(String(v))}</b></div>` : "";
      const tarih = z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" }) : "";
      gov.innerHTML = `
        ${satir("Tarih", tarih)}
        ${satir("Temsilci", z.rep_full_name || z.rep_adi)}
        ${satir("Konum", [z.il, z.ilce].filter(Boolean).join(" / "))}
        ${(Array.isArray(d.katilimcilar) && d.katilimcilar.length) ? satir("Katılımcılar", d.katilimcilar.join(", ")) : ""}
        ${z.notlar ? `<div class="det-not" style="margin-top:8px">${esc(z.notlar)}</div>` : `<div style="color:#94a3b8;margin-top:8px">Not yok.</div>`}
        <div id="mkz-fotolar" class="foto-izgara" style="margin-top:10px"></div>`;
      if (Number(z.foto_sayisi)) {
        try {
          const { fotolar } = await api(`/api/saha/ziyaretler/${zid}/fotolar`);
          const g = lay.querySelector("#mkz-fotolar");
          for (const f of (fotolar || [])) { const url = await fotoUrl(f.id); const im = document.createElement("img"); im.src = url; im.loading = "lazy"; g.appendChild(im); }
          if (g && !g._b) { g._b = true; g.addEventListener("click", (ev) => { const im = ev.target.closest("img"); if (im) fotoBuyut(im.src); }); }
        } catch (e) { /* foto yüklenemedi */ }
      }
    }'''
if old_end not in src:
    print("HATA: V2 _mkHatDuzenle son blok anchor bulunamadi (V2 uygulanmis mi?)"); sys.exit(1)
src = src.replace(old_end, new_end, 1)
print("[+] _mkZiyaretAc overlay fonksiyonu eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
