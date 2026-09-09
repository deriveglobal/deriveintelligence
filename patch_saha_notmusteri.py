#!/usr/bin/env python3
# saha_fix_3 (omurga_78) — not/hatirlatma -> MUSTERI ismi. Rep raporlari:
#   "hatirlatmada musteri isimleri gelmiyor" + "notlarin hangi carilere ait oldugu gorunmuyor".
# ONCE migrate_saha_rep_not.sql calistirilmali (musteri_id kolonu).
# 4 sunucu edit: (1) oto-takip insert (2) manuel POST (3) notlar GET (4) bugun hatirlatmalar.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

E = []
# 1) oto-takip insert
E.append((
'await pool.query("INSERT INTO saha_rep_not (id,tenant_id,rep_id,icerik,hatirlatma_tarihi) VALUES (gen_random_uuid(),$1,$2,$3,$4)", [ctx.tenantId, ctx.repId || null, "[oto] " + ozet, s.hatirlatma_tarihi]);',
'await pool.query("INSERT INTO saha_rep_not (id,tenant_id,rep_id,icerik,hatirlatma_tarihi,musteri_id) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5)", [ctx.tenantId, ctx.repId || null, "[oto] " + ozet, s.hatirlatma_tarihi, ctx.musteriId || null]);'))
# 2) manuel POST
E.append((
'''      const { icerik, hatirlatma_tarihi } = body;
      if (!icerik) { sendJson(response, 400, { error: 'icerik zorunlu' }); return; }
      const r = await pool.query(
        `INSERT INTO saha_rep_not (id, tenant_id, rep_id, icerik, hatirlatma_tarihi)
         VALUES (gen_random_uuid(), $1, $2, $3, $4) RETURNING *`,
        [session.tenantId, session.userId, icerik, hatirlatma_tarihi || null]
      );
      let _asistan = null;
      try { const _sg = await _extractIntent(icerik); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: null, kaynakTip: "not", kaynakId: r.rows[0].id, hamMetin: icerik }); _asistan = _ack && _ack.mesaj; } catch (e) {}''',
'''      const { icerik, hatirlatma_tarihi, musteri_id } = body;
      if (!icerik) { sendJson(response, 400, { error: 'icerik zorunlu' }); return; }
      const r = await pool.query(
        `INSERT INTO saha_rep_not (id, tenant_id, rep_id, icerik, hatirlatma_tarihi, musteri_id)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5) RETURNING *`,
        [session.tenantId, session.userId, icerik, hatirlatma_tarihi || null, musteri_id || null]
      );
      let _asistan = null;
      try { const _sg = await _extractIntent(icerik); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: musteri_id || null, kaynakTip: "not", kaynakId: r.rows[0].id, hamMetin: icerik }); _asistan = _ack && _ack.mesaj; } catch (e) {}'''))
# 3) notlar GET
E.append((
'''        `SELECT id, icerik, to_char(hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi, tamamlandi, created_at, updated_at
           FROM saha_rep_not
          WHERE tenant_id = $1 AND rep_id = $2
          ORDER BY created_at DESC LIMIT 100`,''',
'''        `SELECT n.id, n.icerik, to_char(n.hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi, n.tamamlandi, n.created_at, n.updated_at,
                n.musteri_id, m.firma AS musteri
           FROM saha_rep_not n LEFT JOIN saha_musteri m ON m.id = n.musteri_id
          WHERE n.tenant_id = $1 AND n.rep_id = $2
          ORDER BY n.created_at DESC LIMIT 100`,'''))
# 4) bugun hatirlatmalar
E.append((
'''        hatirlatmalar = (await pool.query("SELECT id, icerik, to_char(hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi FROM saha_rep_not WHERE tenant_id=$1 AND rep_id=$2 AND tamamlandi=false AND hatirlatma_tarihi IS NOT NULL AND hatirlatma_tarihi <= (CURRENT_DATE + INTERVAL '1 day') ORDER BY hatirlatma_tarihi ASC LIMIT 10", [tid, session.userId])).rows;''',
'''        hatirlatmalar = (await pool.query("SELECT n.id, n.icerik, to_char(n.hatirlatma_tarihi,'YYYY-MM-DD') AS hatirlatma_tarihi, m.firma AS musteri FROM saha_rep_not n LEFT JOIN saha_musteri m ON m.id=n.musteri_id WHERE n.tenant_id=$1 AND n.rep_id=$2 AND n.tamamlandi=false AND n.hatirlatma_tarihi IS NOT NULL AND n.hatirlatma_tarihi <= (CURRENT_DATE + INTERVAL '1 day') ORDER BY n.hatirlatma_tarihi ASC LIMIT 10", [tid, session.userId])).rows;'''))

if 'n.musteri_id, m.firma AS musteri' in srv:
    sys.exit("ZATEN VAR: saha_fix_3 uygulanmis gibi.")
for i, (o, n) in enumerate(E, 1):
    if o not in srv:
        sys.exit("HATA: %d. blok bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. blok %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".sahanot.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".sahanot.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .sahanot.bak)")
print("OK: not/hatirlatma musteri baglantisi eklendi. saha.js -> shells/, sonra build.")
