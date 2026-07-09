#!/usr/bin/env node
// add_saha_bugun.mjs — kalıcı patcher: /api/saha/bugun + /api/saha/reps
// Çalıştır: node /opt/krb-assessment/add_saha_bugun.mjs
import { readFileSync, writeFileSync } from "fs";

const TARGET = "/opt/krb-assessment/server.mjs";
const src = readFileSync(TARGET, "utf8");

// İdempotency
if (src.includes('path === "/api/saha/bugun"')) {
  console.log("✓ /api/saha/bugun zaten mevcut — atlanıyor");
  process.exit(0);
}

const ANCHOR = 'sendJson(response, 404, { error: "Bilinmeyen saha endpoint\'i." });';
if (!src.includes(ANCHOR)) {
  console.error("✗ Anchor bulunamadı");
  process.exit(1);
}

// Not: İç template literal'lar için \` kullanıyoruz, $1 PostgreSQL param (JS değişken değil)
const PATCH = [
  "",
  "    // ── /api/saha/bugun — ana ekran özeti ──────────────────────────────────",
  '    if (method === "GET" && path === "/api/saha/bugun") {',
  "      const today = new Date().toISOString().slice(0, 10);",
  "      const tid   = session.tenantId;",
  "",
  "      // Bugün planlanan ziyaretler",
  "      let ziyaretler = [];",
  "      try {",
  "        let zvSql = " +
    "`SELECT z.id, z.rep_adi, z.ziyaret_tarihi, z.durum," +
    " COALESCE(m.firma, '') AS musteri_adi," +
    " COALESCE(m.adres, '') AS adres" +
    " FROM saha_ziyaret z" +
    " LEFT JOIN saha_musteri m ON m.id = z.musteri_id" +
    " WHERE z.tenant_id = $1 AND z.durum = 'PLANLANDI'" +
    " AND z.ziyaret_tarihi::date = $2::date`;",
  "        const zvP = [tid, today];",
  '        if (sahaRole === "rep") { zvSql += " AND z.rep_id = $3"; zvP.push(session.userId); }',
  "        zvSql += \" ORDER BY z.ziyaret_tarihi ASC LIMIT 20\";",
  "        ziyaretler = (await pool.query(zvSql, zvP)).rows;",
  "      } catch (_) {}",
  "",
  "      // Bekleyen teklifler",
  "      let teklifler = [];",
  "      try {",
  "        let tSql = " +
    "`SELECT t.id, t.musteri_adi, t.durum, t.toplam_tutar, t.created_at" +
    " FROM saha_teklif t" +
    " WHERE t.tenant_id = $1 AND t.durum IN ('TASLAK','ONAY_BEKLIYOR')`;",
  "        const tP = [tid];",
  '        if (sahaRole === "rep") { tSql += " AND t.rep_id = $2"; tP.push(session.userId); }',
  "        tSql += \" ORDER BY t.created_at DESC LIMIT 10\";",
  "        teklifler = (await pool.query(tSql, tP)).rows;",
  "      } catch (_) {}",
  "",
  "      sendJson(response, 200, {",
  "        bugun: today,",
  "        ziyaretler,",
  "        duyurular_okunmamis: [],",
  "        mesaj_okunmamis: 0,",
  "        teklifler,",
  "        hatirlatmalar: []",
  "      });",
  "      return;",
  "    }",
  "",
  "    // ── /api/saha/reps — yönetici için temsilci listesi ─────────────────────",
  '    if (method === "GET" && path === "/api/saha/reps") {',
  "      const rows = await pool.query(",
  "        `SELECT u.id, u.name, u.email" +
    " FROM users u" +
    " JOIN user_modules um ON um.user_id = u.id AND um.module = 'saha'" +
    " WHERE u.tenant_id = $1 AND u.disabled IS NOT TRUE" +
    " ORDER BY u.name`,",
  "        [session.tenantId]",
  "      );",
  "      sendJson(response, 200, { reps: rows.rows });",
  "      return;",
  "    }",
  "",
].join("\n");

const patched = src.replace(ANCHOR, PATCH + "    " + ANCHOR);
writeFileSync(TARGET, patched, "utf8");

const lines = patched.split("\n").length;
console.log("✓ /api/saha/bugun eklendi");
console.log("✓ /api/saha/reps eklendi");
console.log(`  Toplam satır: ${lines}`);
