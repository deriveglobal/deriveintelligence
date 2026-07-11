# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ERP_MATCH_FRONT — add "ERP'den eşleştir" action (search full ERP master) to the
# rep Kontrol Bekleyen panel.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) add the ERP button in the row
rep(
'''            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Mevcutla birleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>''',
'''            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Saha müşterisi</button>
            <button class="btn" data-ke="${m.id}" style="font-size:12px;padding:5px 10px;background:#0891b2">🏢 ERP'den eşleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>''',
    "erp-button")

# 2) wire the ERP button + add erpEslesModal
rep(
'''      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "BIRLESTIR", hedef_id: target.id }) }); uyari("✓ Birleştirildi.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
}''',
'''      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "BIRLESTIR", hedef_id: target.id }) }); uyari("✓ Birleştirildi.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));
}

function erpEslesModal(kid) {
  modal(`
    <h3>🏢 ERP'den Eşleştir</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:6px">ERP müşteri veritabanında (tüm kayıtlar) doğru firmayı ara ve seç.</div>
    <input class="giris" id="erp-q" placeholder="Firma adı ara…" autocomplete="off">
    <div id="erp-sonuc" style="max-height:280px;overflow:auto;margin-top:8px"></div>
    <div class="modal-btnlar"><button class="btn gri" data-kapat>Vazgeç</button></div>`);
  const qEl = document.getElementById("erp-q");
  const rEl = document.getElementById("erp-sonuc");
  let t = null;
  qEl.focus();
  qEl.addEventListener("input", () => {
    clearTimeout(t);
    t = setTimeout(async () => {
      const q = qEl.value.trim();
      if (q.length < 2) { rEl.innerHTML = ""; return; }
      rEl.innerHTML = "<div style='color:#94a3b8;font-size:12px;padding:8px'>Aranıyor…</div>";
      try {
        const { sonuclar } = await api(`/api/saha/erp-ara?q=${encodeURIComponent(q)}`);
        rEl.innerHTML = sonuclar.length ? sonuclar.map(x => `
          <div class="kart" data-erp="${esc(x.kod)}" style="cursor:pointer;padding:8px 10px;margin-bottom:4px">
            <div style="font-weight:600;font-size:13px">${esc(x.musteri_adi)}</div>
            <div style="font-size:11px;color:#64748b">${esc(x.sehir || "")} · ${esc(x.kod)}</div>
          </div>`).join("") : "<div style='color:#94a3b8;font-size:12px;padding:8px'>Sonuç yok.</div>";
        rEl.querySelectorAll("[data-erp]").forEach(el => el.addEventListener("click", async () => {
          if (!confirm("Bu ERP müşterisiyle eşleştirilsin mi?")) return;
          try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "ERP_ESLE", erp_kod: el.dataset.erp }) }); kapatModal(); uyari("✓ ERP'den eşleştirildi.", true); await loadView("musteriler"); }
          catch (e) { uyari(e.message); }
        }));
      } catch (e) { rEl.innerHTML = "<div style='color:#ef4444;font-size:12px;padding:8px'>Hata: " + esc(e.message) + "</div>"; }
    }, 300);
  });
}''',
    "erp-modal")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
