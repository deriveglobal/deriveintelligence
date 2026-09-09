import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "FULL_CONTROL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '''      } else if (p.action === "gonder") {
        // ── Gönder: TASLAK → threshold check → ONAY_BEKLIYOR or ONAYLANDI ──
        if (eski.durum !== "TASLAK") {
          sendJson(response, 400, { error: "Sadece taslak teklifler gönderilebilir." }); return;
        }
        const ayarRes2 = await query(`SELECT oto_onay_max, mudur_max FROM saha_iskonto_ayar WHERE tenant_id = $1 LIMIT 1`, [session.tenantId]);
        const otoMax   = Number(ayarRes2.rows[0]?.oto_onay_max ?? 2);
        const mudurMax2 = Number(ayarRes2.rows[0]?.mudur_max   ?? 5);
        const ekIsk2   = Number(eski.musteri_ek_iskonto_pct ?? 0);
        let yeniDurum2, yeniOnayS2;
        if (ekIsk2 <= otoMax)    { yeniDurum2 = "ONAYLANDI";     yeniOnayS2 = null; }
        else if (ekIsk2 <= mudurMax2) { yeniDurum2 = "ONAY_BEKLIYOR"; yeniOnayS2 = "MUDUR"; }
        else                     { yeniDurum2 = "ONAY_BEKLIYOR"; yeniOnayS2 = "GM"; }
        result = await query(`
          UPDATE saha_teklif SET durum = $3, onay_seviyesi = $4, updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1], yeniDurum2, yeniOnayS2]);
        await query(`INSERT INTO saha_teklif_log (teklif_id,alan,eski_deger,yeni_deger,degistiren_kullanici) VALUES ($1,$2,$3,$4,$5)`,
          [m[1], 'Durum', 'TASLAK', yeniDurum2, session.userId]);

      } else if (p.action === "sun") {'''

NEW = '''      } else if (p.action === "gonder") {
        // ── Gönder: TASLAK → ONAY_BEKLIYOR (FULL_CONTROL_V1 — kademe/oto-onay KALDIRILDI) ──
        //   HER teklif "Gönder"de yöneticilere düşer; HERHANGİ bir yönetici (müdür/admin) onaylar.
        //   Eşik yok, oto-onay yok, müdür/GM ayrımı yok — tek akış.
        if (eski.durum !== "TASLAK") {
          sendJson(response, 400, { error: "Sadece taslak teklifler gönderilebilir." }); return;
        }
        result = await query(`
          UPDATE saha_teklif SET durum = 'ONAY_BEKLIYOR', onay_seviyesi = 'MUDUR', updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1]]);
        await query(`INSERT INTO saha_teklif_log (teklif_id,alan,eski_deger,yeni_deger,degistiren_kullanici) VALUES ($1,$2,$3,$4,$5)`,
          [m[1], 'Durum', 'TASLAK', 'ONAY_BEKLIYOR', session.userId]);
        // FULL_CONTROL_V1 — teklifi TÜM yöneticilere (müdür/admin) ANLIK bildir + inbox; dokun→teklife git
        try {
          const _tk = result.rows[0];
          sahaManagerIds(session.tenantId, session.userId).then(function (ids) {
            if (!ids.length) return;
            pool.query("SELECT firma FROM saha_musteri WHERE id=$1", [_tk.musteri_id]).then(function (mr) {
              const fn = (mr.rows[0] && mr.rows[0].firma) || "Müşteri";
              pushToUsers(session.tenantId, ids, "✅ Onay bekleyen teklif", fn + (_tk.marka ? " — " + _tk.marka : "") + (_tk.toplam_tutar ? " · ₺" + Math.round(Number(_tk.toplam_tutar)).toLocaleString("tr-TR") : ""), { room: "saha", type: "teklif_onay", id: _tk.id });
            }).catch(function () {});
          }).catch(function () {});
        } catch (e) {}

      } else if (p.action === "sun") {'''

assert s.count(OLD) == 1, "gonder anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] gonder → full-control (no tier, no auto-approve) + push to all managers")
print("[done] FULL_CONTROL_V1")
