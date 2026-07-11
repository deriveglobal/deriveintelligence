# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ONERI_SIL — delete a ticket (staff only). Reps cannot delete: a bug report must
# not be able to disappear after it has been read. Thread + read-state go with it
# via ON DELETE CASCADE.
import sys
which = sys.argv[1]
fn = sys.argv[2]
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

if which == "server":
    rep(
'''    if (method === "PUT" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request, ['manager','admin']);''',
'''    if (method === "DELETE" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request, ['manager','admin']);
      const r = await pool.query(
        "DELETE FROM saha_oneri WHERE id=$1 AND tenant_id=$2 RETURNING baslik", [m[1], session.tenantId]);
      if (!r.rowCount) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      sendJson(response, 200, { ok: true, silinen: r.rows[0].baslik });
      return;
    }
    if (method === "PUT" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request, ['manager','admin']);''',
        "oneri-delete-endpoint")

elif which == "front":
    rep(
'''    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="ot-gonder">Gönder</button>
    </div>`);

  const th = document.getElementById("ot-thread");''',
'''    <div class="modal-btnlar">
      ${staff ? `<button class="btn" id="ot-sil" style="background:#dc2626;margin-right:auto">🗑 Sil</button>` : ""}
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="ot-gonder">Gönder</button>
    </div>`);

  document.getElementById("ot-sil")?.addEventListener("click", async () => {
    if (!confirm(`"${o.baslik}" kaydı ve tüm mesajları kalıcı olarak silinecek. Geri alınamaz. Devam edilsin mi?`)) return;
    try {
      await api(`/api/saha/oneriler/${id}`, { method: "DELETE" });
      kapatModal();
      uyari("✓ Kayıt silindi.", true);
      if (S.view === "oneriler") await loadView("oneriler");
    } catch (e) { uyari(e.message); }
  });

  const th = document.getElementById("ot-thread");''',
        "oneri-delete-button")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
