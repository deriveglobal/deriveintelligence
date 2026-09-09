# -*- coding: utf-8 -*-
# ROSTER_V1 — Yonetici mesaj listesi = tenant'taki TUM aktif rep'ler (thread olsun olmasin);
#   admin'ler ve kisinin kendisi gizlenir. Boylece Ali Kemal gibi thread'siz rep de gorunur,
#   Fatih Bilen (admin) ve KRB Yonetim (kendisi) listeden dusr. Ayrica bir rep'in thread'i
#   yoksa :repId acilisinda yaratilir ki ILK mesaj gonderilebilsin.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "ROSTER_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) Yonetici liste sorgusu: konusma-tabanli -> rep-tabanli
OLD1 = """        const rows = await pool.query(
          `SELECT k.id, k.rep_id,
              COALESCE(u.name, k.rep_id::text) AS rep_adi,
              (SELECT row_to_json(sub) FROM (
                SELECT m2.icerik, m2.created_at, m2.gonderen_rol
                  FROM saha_konusma_mesaj m2 WHERE m2.konusma_id=k.id
                 ORDER BY m2.created_at DESC LIMIT 1
              ) sub) AS son_mesaj,
              (SELECT count(*) FROM saha_konusma_mesaj mm WHERE mm.konusma_id=k.id AND mm.gonderen_rol='rep' AND mm.created_at > COALESCE((SELECT son_okunan_at FROM saha_konusma_okundu o WHERE o.konusma_id=k.id AND o.user_id=$2),'epoch'::timestamptz))::int AS okunmamis  /* MESAJ_OKUNDU_V1 */
             FROM saha_konusma k
             LEFT JOIN users u ON u.id=k.rep_id
            WHERE k.tenant_id=$1 AND k.tip='BIREYSEL'
            ORDER BY (SELECT MAX(m3.created_at) FROM saha_konusma_mesaj m3 WHERE m3.konusma_id=k.id) DESC NULLS LAST
            LIMIT 100`,
          [tid, session.userId]  /* MESAJ_OKUNDU_V1 */
        );"""
NEW1 = """        const rows = await pool.query(  /* ROSTER_V1: tum aktif rep'ler; admin + kendisi haric */
          `SELECT u.id AS rep_id,
              COALESCE(u.full_name, u.email, u.id::text) AS rep_adi,
              (SELECT row_to_json(sub) FROM (
                SELECT m2.icerik, m2.created_at, m2.gonderen_rol
                  FROM saha_konusma k2 JOIN saha_konusma_mesaj m2 ON m2.konusma_id=k2.id
                 WHERE k2.tenant_id=$1 AND k2.rep_id=u.id AND k2.tip='BIREYSEL'
                 ORDER BY m2.created_at DESC LIMIT 1
              ) sub) AS son_mesaj,
              (SELECT count(*) FROM saha_konusma k3 JOIN saha_konusma_mesaj m3 ON m3.konusma_id=k3.id
                 LEFT JOIN saha_konusma_okundu o ON o.konusma_id=k3.id AND o.user_id=$2
                WHERE k3.tenant_id=$1 AND k3.rep_id=u.id AND k3.tip='BIREYSEL'
                  AND m3.gonderen_rol='rep' AND m3.created_at > COALESCE(o.son_okunan_at,'epoch'::timestamptz))::int AS okunmamis
             FROM users u
             JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.tenant_id=$1 AND um.active=true AND um.module_role='rep'
            WHERE u.status <> 'disabled' AND u.id <> $2
            ORDER BY okunmamis DESC,
                     (SELECT MAX(m4.created_at) FROM saha_konusma k4 JOIN saha_konusma_mesaj m4 ON m4.konusma_id=k4.id WHERE k4.tenant_id=$1 AND k4.rep_id=u.id AND k4.tip='BIREYSEL') DESC NULLS LAST,
                     rep_adi
            LIMIT 200`,
          [tid, session.userId]
        );"""
assert s.count(OLD1) == 1, "list anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) :repId acilisinda thread yoksa yarat (ilk mesaj gonderilebilsin)
OLD2 = """      let konusma_id = null, mesajlar = [];
      if (kRes.rows.length) {
        konusma_id = kRes.rows[0].id;
        const mRes = await pool.query(
          `SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2
             ORDER BY created_at ASC LIMIT 200`,
          [konusma_id, tid]
        );
        mesajlar = mRes.rows;
      }"""
NEW2 = """      let konusma_id = null, mesajlar = [];
      if (kRes.rows.length) { konusma_id = kRes.rows[0].id; }
      else {  /* ROSTER_V1: thread yoksa yarat ki ilk mesaj gonderilebilsin */
        const _ins = await pool.query(`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'BIREYSEL',$2) RETURNING id`, [tid, repId]);
        konusma_id = _ins.rows[0].id;
      }
      if (konusma_id) {
        const mRes = await pool.query(
          `SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2
             ORDER BY created_at ASC LIMIT 200`,
          [konusma_id, tid]
        );
        mesajlar = mRes.rows;
      }"""
assert s.count(OLD2) == 1, "repId anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] ROSTER_V1")
