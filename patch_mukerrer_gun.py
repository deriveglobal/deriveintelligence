import sys, io
path = sys.argv[1]
with io.open(path, encoding="utf-8") as f: src = f.read()
if "MUKERRER_GUN_V1" in src:
    print("[patch_mukerrer_gun] zaten uygulanmis, atlaniyor."); sys.exit(0)

OLD = '''      if (tamamla) {
        const _var = await query(`
          SELECT * FROM saha_ziyaret
           WHERE tenant_id=$1 AND musteri_id=$2 AND rep_id=$3
             AND ziyaret_tarihi=$4 AND durum='TAMAMLANDI'
             AND created_at > now() - interval '3 minutes'
           ORDER BY created_at DESC LIMIT 1`,
          [session.tenantId, p.musteri_id, session.userId, _tarih]);
        if (_var.rowCount) {
          console.warn("[saha] mukerrer ziyaret engellendi:", session.userId, p.musteri_id, _tarih);
          sendJson(response, 200, { ziyaret: _var.rows[0], asistan: null, mukerrer_engellendi: true });
          return;
        }
      }'''

NEW = '''      // MUKERRER_GUN_V1 — ayni musteriye ayni gun ikinci "tamamlandi" kaydini yonet.
      //   <3 dk: gercek cift-tik -> mevcut kaydi dondur; yeni not doluysa mevcudu GUNCELLE (metin kaybi yok).
      //   >3 dk ayni gun: sessiz kopya ACMA -> {mukerrer_gun:true, mevcut}; istemci sorar.
      //   p.force_yeni===true -> baypas (gercek ikinci ziyaret).
      const _force = p.force_yeni === true;
      if (tamamla && !_force) {
        const _var = await query(`
          SELECT *, (created_at > now() - interval '3 minutes') AS _cift_tik
            FROM saha_ziyaret
           WHERE tenant_id=$1 AND musteri_id=$2 AND rep_id=$3
             AND ziyaret_tarihi=$4 AND durum='TAMAMLANDI'
           ORDER BY created_at DESC LIMIT 1`,
          [session.tenantId, p.musteri_id, session.userId, _tarih]);
        if (_var.rowCount) {
          const _mevcut = _var.rows[0];
          if (_mevcut._cift_tik) {
            const _yeniNot = p.notlar && String(p.notlar).trim();
            if (_yeniNot && String(p.notlar).trim() !== String(_mevcut.notlar || "").trim()) {
              const _u = await query(
                `UPDATE saha_ziyaret SET notlar=$3, updated_at=now() WHERE tenant_id=$1 AND id=$2 RETURNING *`,
                [session.tenantId, _mevcut.id, p.notlar]);
              console.warn("[saha] mukerrer <3dk: mevcut not guncellendi:", session.userId, p.musteri_id, _tarih);
              sendJson(response, 200, { ziyaret: _u.rows[0], asistan: null, mukerrer_engellendi: true, not_guncellendi: true });
              return;
            }
            console.warn("[saha] mukerrer ziyaret engellendi (<3dk):", session.userId, p.musteri_id, _tarih);
            sendJson(response, 200, { ziyaret: _mevcut, asistan: null, mukerrer_engellendi: true });
            return;
          }
          delete _mevcut._cift_tik;
          console.warn("[saha] mukerrer_gun uyarisi:", session.userId, p.musteri_id, _tarih);
          sendJson(response, 200, { mukerrer_gun: true, mevcut: _mevcut });
          return;
        }
      }'''

n = src.count(OLD)
if n != 1:
    sys.stderr.write("[patch_mukerrer_gun] HATA: anchor %d kez bulundu (1 bekleniyordu).\n" % n); sys.exit(2)
src = src.replace(OLD, NEW, 1)
with io.open(path, "w", encoding="utf-8") as f: f.write(src)
print("[patch_mukerrer_gun] uygulandi.")
