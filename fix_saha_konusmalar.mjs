#!/usr/bin/env node
// fix_saha_konusmalar.mjs — konusmalar endpoint'lerini frontend yapısına göre düzeltir
// Çalıştır: node /opt/krb-assessment/fix_saha_konusmalar.mjs
import { readFileSync, writeFileSync } from "fs";

const TARGET = "/opt/krb-assessment/server.mjs";
const src = readFileSync(TARGET, "utf8");

if (src.includes('// FIX_KONUSMALAR_V2')) {
  console.log("✓ Zaten düzeltilmiş — atlanıyor"); process.exit(0);
}

// Eski konusmalar bölümünü bul ve değiştir
const OLD_START = "    // ══ KONUŞMALAR (mesajlar) ════════════════════════════════════════════════";
const OLD_END   = "    // ══ ÖNERİLER ════════════════════════════════════════════════════════════";

const startIdx = src.indexOf(OLD_START);
const endIdx   = src.indexOf(OLD_END);

if (startIdx === -1 || endIdx === -1) {
  console.error("✗ Konusmalar bölümü bulunamadı"); process.exit(1);
}

const NEW_SECTION = `    // ══ KONUŞMALAR (mesajlar) ════════════════════════════════════════════════
    // FIX_KONUSMALAR_V2

    // POST coklu/yayim önce — statik path'ler dinamikten önce gelmeli
    if (method === "POST" && path === "/api/saha/konusmalar/coklu") {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const { rep_ids, icerik } = body;
      if (!Array.isArray(rep_ids) || !icerik) { sendJson(response, 400, { error: "rep_ids ve icerik zorunlu" }); return; }
      for (const rid of rep_ids) {
        let kRes = await pool.query(
          \`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='rep-manager' LIMIT 1\`,
          [session.tenantId, rid]
        );
        let kid;
        if (kRes.rows.length) { kid = kRes.rows[0].id; }
        else {
          const ins = await pool.query(
            \`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'rep-manager',$2) RETURNING id\`,
            [session.tenantId, rid]
          );
          kid = ins.rows[0].id;
        }
        await pool.query(
          \`INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik)
           VALUES (gen_random_uuid(),$1,$2,$3,$4,'manager',$5)\`,
          [session.tenantId, kid, session.userId, session.name || "Yönetici", icerik]
        );
      }
      sendJson(response, 200, { ok: true, sayi: rep_ids.length });
      return;
    }

    if (method === "POST" && path === "/api/saha/konusmalar/yayim") {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const { icerik } = body;
      if (!icerik) { sendJson(response, 400, { error: "icerik zorunlu" }); return; }
      // Yayım için ayrı konuşma kaydı (tip='yayim') her temsilci için
      const reps = await pool.query(
        \`SELECT DISTINCT u.id FROM users u
          JOIN user_modules um ON um.user_id=u.id AND um.module='saha'
          WHERE u.tenant_id=$1 AND u.disabled IS NOT TRUE\`,
        [session.tenantId]
      );
      for (const r of reps.rows) {
        let kRes = await pool.query(
          \`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='yayim' LIMIT 1\`,
          [session.tenantId, r.id]
        );
        let kid;
        if (kRes.rows.length) { kid = kRes.rows[0].id; }
        else {
          const ins = await pool.query(
            \`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'yayim',$2) RETURNING id\`,
            [session.tenantId, r.id]
          );
          kid = ins.rows[0].id;
        }
        await pool.query(
          \`INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik)
           VALUES (gen_random_uuid(),$1,$2,$3,$4,'manager',$5)\`,
          [session.tenantId, kid, session.userId, session.name || "Yönetici", icerik]
        );
      }
      sendJson(response, 200, { ok: true });
      return;
    }

    // GET /api/saha/konusmalar — rep: tek thread; manager: tüm rep listesi
    if (method === "GET" && path === "/api/saha/konusmalar") {
      const session = await requireSahaAccess(request);
      const tid = session.tenantId;

      if (session.sahaRole === "rep") {
        // Rep'in yönetici ile konuşması (veya oluştur)
        let kRes = await pool.query(
          \`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='rep-manager' LIMIT 1\`,
          [tid, session.userId]
        );
        let konusma_id;
        if (kRes.rows.length) {
          konusma_id = kRes.rows[0].id;
        } else {
          const ins = await pool.query(
            \`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'rep-manager',$2) RETURNING id\`,
            [tid, session.userId]
          );
          konusma_id = ins.rows[0].id;
        }
        const mRes = await pool.query(
          \`SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2
             ORDER BY created_at ASC LIMIT 200\`,
          [konusma_id, tid]
        );
        // Yayımlar — bu rep'e gönderilmiş broadcast'ler
        let yayimlar = [];
        try {
          const yRes = await pool.query(
            \`SELECT m.id, m.gonderen_adi, m.icerik, m.created_at
               FROM saha_konusma k
               JOIN saha_konusma_mesaj m ON m.konusma_id=k.id
              WHERE k.tenant_id=$1 AND k.rep_id=$2 AND k.tip='yayim'
              ORDER BY m.created_at DESC LIMIT 20\`,
            [tid, session.userId]
          );
          yayimlar = yRes.rows;
        } catch (_) {}
        sendJson(response, 200, { konusma_id, mesajlar: mRes.rows, yayimlar });
        return;
      } else {
        // Manager: rep konuşmalarının listesi
        const rows = await pool.query(
          \`SELECT k.id, k.rep_id,
              COALESCE(u.name, k.rep_id::text) AS rep_adi,
              (SELECT row_to_json(sub) FROM (
                SELECT m2.icerik, m2.created_at, m2.gonderen_rol
                  FROM saha_konusma_mesaj m2 WHERE m2.konusma_id=k.id
                 ORDER BY m2.created_at DESC LIMIT 1
              ) sub) AS son_mesaj,
              0::int AS okunmamis
             FROM saha_konusma k
             LEFT JOIN users u ON u.id=k.rep_id AND u.tenant_id=k.tenant_id
            WHERE k.tenant_id=$1 AND k.tip='rep-manager'
            ORDER BY (SELECT MAX(m3.created_at) FROM saha_konusma_mesaj m3 WHERE m3.konusma_id=k.id) DESC NULLS LAST
            LIMIT 100\`,
          [tid]
        );
        // Son yayımlar
        let yayimlar = [];
        try {
          const yRes = await pool.query(
            \`SELECT DISTINCT ON (m.icerik) m.icerik, m.created_at, m.gonderen_adi
               FROM saha_konusma k
               JOIN saha_konusma_mesaj m ON m.konusma_id=k.id
              WHERE k.tenant_id=$1 AND k.tip='yayim'
              ORDER BY m.icerik, m.created_at DESC
              LIMIT 5\`,
            [tid]
          );
          yayimlar = yRes.rows;
        } catch (_) {}
        sendJson(response, 200, { konusmalar: rows.rows, yayimlar });
        return;
      }
    }

    // GET /api/saha/konusmalar/:repId — yönetici bir rep'in thread'ini açar
    if (method === "GET" && (m = path.match(/^\\/api\\/saha\\/konusmalar\\/([^/]+)$/))) {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const repId = m[1];
      const tid = session.tenantId;
      let kRes = await pool.query(
        \`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='rep-manager' LIMIT 1\`,
        [tid, repId]
      );
      let konusma_id = null, mesajlar = [];
      if (kRes.rows.length) {
        konusma_id = kRes.rows[0].id;
        const mRes = await pool.query(
          \`SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2
             ORDER BY created_at ASC LIMIT 200\`,
          [konusma_id, tid]
        );
        mesajlar = mRes.rows;
      }
      sendJson(response, 200, { konusma_id, mesajlar });
      return;
    }

    // POST /api/saha/konusmalar/:konusmaId — mesaj gönder
    if (method === "POST" && (m = path.match(/^\\/api\\/saha\\/konusmalar\\/([^/]+)$/))) {
      const session = await requireSahaAccess(request);
      const konusmaId = m[1];
      const { icerik } = body;
      if (!icerik) { sendJson(response, 400, { error: "icerik zorunlu" }); return; }
      await pool.query(
        \`INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6)\`,
        [session.tenantId, konusmaId, session.userId, session.name || "Kullanıcı", session.sahaRole || "rep", icerik]
      );
      sendJson(response, 201, { ok: true });
      return;
    }

`;

const patched = src.slice(0, startIdx) + NEW_SECTION + src.slice(endIdx);
writeFileSync(TARGET, patched, "utf8");
console.log("✓ Konusmalar bölümü düzeltildi");
console.log(`  Toplam satır: ${patched.split("\n").length}`);
