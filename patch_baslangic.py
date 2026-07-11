# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# GUNLUK_BASLANGIC — the check-in IS the signal. No picker, no morning ritual.
#
# The rep already taps "✓ Check-in" at the first customer of the day. That customer's
# city tells us exactly where he is — no geocoding needed, the city is already on the
# customer record. So the FIRST check-in of the day sets today's starting point.
# Later check-ins do not override it: the start is where you STARTED.
#
# rota_oner already resolves: today's start -> live GPS -> home base.
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
'''      if (action === "checkin") {
        result = await query(`
          UPDATE saha_ziyaret
          SET checkin_at = now(), checkin_lat = $3, checkin_lng = $4, updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1], p.lat ?? null, p.lng ?? null]);''',
'''      if (action === "checkin") {
        result = await query(`
          UPDATE saha_ziyaret
          SET checkin_at = now(), checkin_lat = $3, checkin_lng = $4, updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1], p.lat ?? null, p.lng ?? null]);
        // İLK check-in bugünkü başlangıç noktasını belirler (Asistan rota önerisi için).
        // Müşterinin şehri zaten kayıtlı — geocoding gerekmez. Sonraki check-in'ler
        // başlangıcı DEĞİŞTİRMEZ: başlangıç, gününe nereden başladığındır.
        try {
          const _z = result.rows[0];
          if (_z) {
            const _mc = await pool.query(
              "SELECT il, ilce FROM saha_musteri WHERE tenant_id=$1 AND id=$2",
              [session.tenantId, _z.musteri_id]);
            const _il   = _mc.rows[0] ? _mc.rows[0].il   : null;
            const _ilce = _mc.rows[0] ? _mc.rows[0].ilce : null;
            if (_il || p.lat != null) {
              await pool.query(
                `INSERT INTO saha_rep_gunluk_baslangic (tenant_id, rep_id, tarih, sehir, ilce, lat, lng, kaynak)
                 VALUES ($1,$2,CURRENT_DATE,$3,$4,$5,$6,'OTOMATIK')
                 ON CONFLICT (rep_id, tarih) DO NOTHING`,
                [session.tenantId, session.userId, _il, _ilce, p.lat ?? null, p.lng ?? null]);
            }
          }
        } catch (e) { console.error("[gunluk-baslangic/checkin]", e && e.message); }''',
        "checkin-sets-start")

elif which == "front":
    # strip slot, under the date
    rep(
'''        <div style="font-size:17px;font-weight:700;color:#0f172a;margin-bottom:18px;text-transform:capitalize">${tarihStr}</div>
        ${hatirlatmalar.length ? secBlock("⏰", "Hatırlatmalar", hatirlatmalar.length, "#7c3aed", hatirlatmaHtml) : ""}''',
'''        <div style="font-size:17px;font-weight:700;color:#0f172a;margin-bottom:10px;text-transform:capitalize">${tarihStr}</div>
        <div id="bugun-baslangic"></div>
        ${hatirlatmalar.length ? secBlock("⏰", "Hatırlatmalar", hatirlatmalar.length, "#7c3aed", hatirlatmaHtml) : ""}''',
        "baslangic-strip-slot")

    rep(
'''    // check-in (rep only)
    main().querySelectorAll("[data-checkin]").forEach(btn =>''',
'''    baslangicStripYukle();

    // check-in (rep only)
    main().querySelectorAll("[data-checkin]").forEach(btn =>''',
        "baslangic-strip-load")

    rep(
'''// ── BUGÜN (home) ─────────────────────────────────────────────────────────────
async function vBugun() {''',
'''// ── GÜNLÜK BAŞLANGIÇ NOKTASI ────────────────────────────────────────────────
// Sadece gösterim: ilk check-in bunu otomatik belirler. Rota önerisi buradan başlar.
async function baslangicStripYukle() {
  const box = document.getElementById("bugun-baslangic");
  if (!box) return;
  let d = {};
  try { d = await api("/api/saha/gunluk-baslangic"); } catch { box.innerHTML = ""; return; }
  const b = d.bugun, merkez = d.merkez;

  if (b) {
    const yer = [b.sehir, b.ilce].filter(Boolean).join(" / ") || (b.lat ? `${b.lat}, ${b.lng}` : "—");
    box.innerHTML = `
      <div style="background:#ecfdf5;border:1px solid #a7f3d0;border-radius:10px;padding:8px 12px;margin-bottom:14px;display:flex;align-items:center;gap:8px;font-size:12px;color:#065f46">
        <span>📍</span>
        <span style="flex:1"><b>Bugünkü başlangıç:</b> ${esc(yer)}${b.kaynak === "OTOMATIK" ? ` <span style="color:#059669">· ilk check-in'den</span>` : ""}</span>
        <button class="btn kucuk cizgili" id="bs-sifirla" style="font-size:11px;padding:3px 8px">Sıfırla</button>
      </div>`;
    document.getElementById("bs-sifirla")?.addEventListener("click", async () => {
      try {
        await api("/api/saha/gunluk-baslangic", { method: "DELETE" });
        uyari("✓ Sıfırlandı — merkez konumun kullanılacak.", true);
        baslangicStripYukle();
      } catch (e) { uyari(e.message); }
    });
  } else {
    const merkezYer = merkez && (merkez.base_adres || (merkez.base_lat ? "kayıtlı merkez konum" : null));
    box.innerHTML = `
      <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:8px 12px;margin-bottom:14px;font-size:12px;color:#64748b">
        📍 Başlangıç: <b>${merkezYer ? esc(merkezYer) : "ayarlanmamış"}</b> — bugünün ilk <b>check-in</b>'inde otomatik güncellenir.
      </div>`;
  }
}

// ── BUGÜN (home) ─────────────────────────────────────────────────────────────
async function vBugun() {''',
        "baslangic-strip-func")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
