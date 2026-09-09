#!/usr/bin/env python3
# MUSTERI_HATIRLATMA_DUZENLE_V1 (client) — Ozellik (Eftal Yildiz 03.08): Musteri Kartindaki
#   "Hareketler" listesinde bir hatirlatmaya (not/takip) tiklayinca o kayda gidip pratik
#   guncelleme (metin + takip tarihi + tamamla).
#   Mevcut: _mkYukle() draw() .mk-ev satirlari tiklanmiyor, id tasimiyor.
#   Fix:
#     1) not/takip satirlarina (o.sid varsa) data-sid + tiklanabilir sinif ekle.
#     2) Tiklaninca duzenleme modali ac (textarea + tarih + "✓ Tamamlandi" + "Kaydet"),
#        PUT /api/saha/sinyal/:sid, ardindan _mkYukle() ile yenile.
#     3) Kucuk CSS: tiklanabilir satir gorunumu.
#   Idempotent (marker: MUSTERI_HATIRLATMA_DUZENLE_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_HATIRLATMA_DUZENLE_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1) Satir sablonu: tiklanabilir + data-sid
old_row = '''          ${list.map(o => `<div class="mk-ev"><div class="mk-ic">${_mkIK[o.tip] || "•"}</div><div class="mk-c"><div class="mk-m">${esc(String(o.baslik || ""))}</div>${(o.alt || o.kim) ? `<div class="mk-s">${[o.alt, o.kim].filter(Boolean).map(x => esc(String(x))).join(" · ")}</div>` : ""}</div><div class="mk-r">${_mkGun(o.ts)}</div></div>`).join("") || `<div class="mk-empty">Kayıt yok.</div>`}'''
new_row = '''          ${list.map(o => `<div class="mk-ev${o.sid ? " mk-ev-tik" + (o.skapandi ? " mk-ev-done" : "") : ""}"${o.sid ? ` data-sid="${o.sid}"` : ""}><div class="mk-ic">${o.sid && o.skapandi ? "✅" : (_mkIK[o.tip] || "•")}</div><div class="mk-c"><div class="mk-m">${esc(String(o.baslik || ""))}${o.sid && o.stakip ? ` <span class="mk-tkd">📅 ${esc(String(o.stakip))}</span>` : ""}</div>${(o.alt || o.kim) ? `<div class="mk-s">${[o.alt, o.kim].filter(Boolean).map(x => esc(String(x))).join(" · ")}</div>` : ""}</div><div class="mk-r">${_mkGun(o.ts)}${o.sid ? " ✎" : ""}</div></div>`).join("") || `<div class="mk-empty">Kayıt yok.</div>`}  <!-- ''' + MARK + ''' -->'''
if old_row not in src:
    print("HATA: mk-ev satir sablonu anchor bulunamadi"); sys.exit(1)
src = src.replace(old_row, new_row, 1)
print("[+] mk-ev satirlari tiklanabilir hale getirildi (data-sid)")

# 2) draw() icindeki chip wiring'den hemen sonra tiklama handler'i + modal fonksiyonu
old_wire = '''      hare.querySelectorAll(".mk-chip").forEach(c => c.addEventListener("click", (e) => { e.stopPropagation(); filt = c.dataset.f; acik = true; draw(); }));
    };'''
new_wire = '''      hare.querySelectorAll(".mk-chip").forEach(c => c.addEventListener("click", (e) => { e.stopPropagation(); filt = c.dataset.f; acik = true; draw(); }));
      hare.querySelectorAll(".mk-ev-tik").forEach(el => el.addEventListener("click", (e) => {  /* ''' + MARK + ''' */
        e.stopPropagation();
        const o = (d.olaylar || []).find(x => String(x.sid) === String(el.dataset.sid));
        if (o) _mkHatDuzenle(o);
      }));
    };
    function _mkHatDuzenle(o) {  /* ''' + MARK + ''' */
      const kapandi = !!o.skapandi;
      modal(`
        <h3>${kapandi ? "Hatırlatma (tamamlandı)" : "Hatırlatmayı Düzenle"}</h3>
        <label>Not
          <textarea class="giris" id="mkd-metin" rows="4">${esc(String(o.sozet || ""))}</textarea>
        </label>
        <label style="margin-top:10px;display:block">Takip tarihi
          <input type="date" class="giris" id="mkd-tarih" value="${o.stakip || ""}">
        </label>
        <div class="modal-btnlar" style="flex-wrap:wrap;gap:8px">
          <button class="btn gri" data-kapat>Vazgeç</button>
          ${kapandi
            ? `<button class="btn" id="mkd-geriac">↩︎ Geri Aç</button>`
            : `<button class="btn" id="mkd-tamam" style="background:#106B4A;color:#fff">✓ Tamamlandı</button>`}
          <button class="btn" id="mkd-kaydet">Kaydet</button>
        </div>`);
      const put = async (body, msg) => {
        try {
          await api(`/api/saha/sinyal/${o.sid}`, { method: "PUT", body: JSON.stringify(body) });
          kapatModal(); uyari(msg, true); _mkYukle();
        } catch (e) { uyari(e.message); }
      };
      document.getElementById("mkd-kaydet")?.addEventListener("click", () => {
        const metin = (document.getElementById("mkd-metin")?.value || "").trim();
        if (!metin) { uyari("Not boş olamaz."); return; }
        const tarih = document.getElementById("mkd-tarih")?.value || "";
        put({ metin, takip_tarihi: tarih }, "✓ Güncellendi.");
      });
      document.getElementById("mkd-tamam")?.addEventListener("click", () => put({ tamamla: true }, "✓ Tamamlandı."));
      document.getElementById("mkd-geriac")?.addEventListener("click", () => put({ tamamla: false }, "↩︎ Geri açıldı."));
    }'''
if old_wire not in src:
    print("HATA: draw() chip wiring anchor bulunamadi"); sys.exit(1)
src = src.replace(old_wire, new_wire, 1)
print("[+] tiklama handler'i + _mkHatDuzenle modali eklendi")

# 3) CSS (mk-ev tiklanabilir gorunum) — .mk-ev tanimindan sonra ekle
css_anchor = '.mk-ev{'
if css_anchor in src:
    # ilk .mk-ev CSS blogunun oncesine kucuk stil ekle
    inject = '.mk-ev-tik{cursor:pointer}.mk-ev-tik:hover{background:#f1f5f9}.mk-ev-tik:active{background:#e2e8f0}.mk-ev-done{opacity:.62}.mk-tkd{font-size:11px;color:#0369a1;background:#e0f2fe;border-radius:6px;padding:0 5px;white-space:nowrap}/* ' + MARK + ' */\n'
    src = src.replace(css_anchor, inject + css_anchor, 1)
    print("[+] mk-ev-tik CSS eklendi")
else:
    print("[uyari] .mk-ev CSS anchor bulunamadi — stil atlandi (islevsel etkisi yok)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
