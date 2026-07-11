# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# LOKASYON_FRONT — add "Şube olarak bağla" to Kontrol cards. Reuses the customer
# picker to choose the parent, then posts karar=LOKASYON.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) add the button (and let the row wrap)
rep(
'''          <div style="display:flex;gap:6px;margin-top:6px">
            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Saha müşterisi</button>
            <button class="btn" data-ke="${m.id}" style="font-size:12px;padding:5px 10px;background:#0891b2">🏢 ERP'den eşleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>
          </div>''',
'''          <div style="display:flex;gap:6px;margin-top:6px;flex-wrap:wrap">
            <button class="btn" data-kb="${m.id}" style="font-size:12px;padding:5px 10px">🔗 Saha müşterisi</button>
            <button class="btn" data-kl="${m.id}" style="font-size:12px;padding:5px 10px;background:#7c3aed">📍 Şube olarak bağla</button>
            <button class="btn" data-ke="${m.id}" style="font-size:12px;padding:5px 10px;background:#0891b2">🏢 ERP'den eşleştir</button>
            <button class="btn cizgili" data-ky="${m.id}" style="font-size:12px;padding:5px 10px">✓ Yeni müşteri</button>
          </div>''',
    "lokasyon-button")

# 2) wire the button
rep(
'''  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));
}''',
'''  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));
  box.querySelectorAll("[data-kl]").forEach(b => b.addEventListener("click", () => {
    const kid = b.dataset.kl;
    musteriSecModal(async target => {
      if (!target || target.id === kid) { uyari("Bağlanacak ana müşteriyi seç."); return; }
      if (!confirm(`Bu kayıt "${target.firma || "seçilen müşteri"}" firmasının şubesi/lokasyonu olarak bağlansın mı? Ziyaretleri o müşteriye taşınır.`)) return;
      try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: kid, karar: "LOKASYON", hedef_id: target.id }) }); uyari("✓ Şube olarak bağlandı.", true); await loadView("musteriler"); }
      catch (e) { uyari(e.message); }
    });
  }));
}''',
    "lokasyon-wire")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
