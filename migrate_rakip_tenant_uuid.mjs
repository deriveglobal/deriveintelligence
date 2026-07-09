#!/usr/bin/env node
/**
 * migrate_rakip_tenant_uuid.mjs
 * Fixes tenant_id type in rakip tables: INTEGER → TEXT (UUID-compatible)
 * Runs inside the container using the same pg pool as the app.
 * Usage: node migrate_rakip_tenant_uuid.mjs
 */
import pg from 'pg';
const { Pool } = pg;

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

async function run() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Get real tenant UUID
    const tidRes = await client.query('SELECT id::text FROM platform_tenants ORDER BY created_at LIMIT 1');
    if (!tidRes.rows.length) throw new Error('platform_tenants tablosu boş');
    const tid = tidRes.rows[0].id;
    console.log('Tenant UUID:', tid);

    // Helper: check column type
    async function colType(table, col) {
      const r = await client.query(
        `SELECT data_type FROM information_schema.columns
          WHERE table_name=$1 AND column_name=$2`, [table, col]);
      return r.rows[0]?.data_type;
    }

    // ── bi_rakip_fiyat ──────────────────────────────────────────────────────
    const t1 = await colType('bi_rakip_fiyat', 'tenant_id');
    if (t1 === 'integer') {
      // Drop dependent view first
      await client.query(`DROP VIEW IF EXISTS bi_rakip_fiyat_son`);
      await client.query(`ALTER TABLE bi_rakip_fiyat ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT`);
      await client.query(`ALTER TABLE bi_rakip_fiyat ALTER COLUMN tenant_id SET DEFAULT '${tid}'`);
      await client.query(`UPDATE bi_rakip_fiyat SET tenant_id=$1 WHERE tenant_id='1'`, [tid]);
      // Recreate view
      await client.query(`
        CREATE VIEW bi_rakip_fiyat_son AS
        SELECT DISTINCT ON (kaynak, marka, model, ebat)
            id, scraped_at, kaynak, marka, model, ebat,
            genislik, profil, cap, mevsim,
            fiyat, para_birimi, stok, url,
            satici_sayisi, yorum_sayisi, puan,
            tenant_id
        FROM bi_rakip_fiyat
        ORDER BY kaynak, marka, model, ebat, scraped_at DESC
      `);
      console.log('✓ bi_rakip_fiyat.tenant_id: INTEGER → TEXT (view yeniden oluşturuldu)');
    } else {
      console.log('— bi_rakip_fiyat.tenant_id zaten TEXT, atlanıyor');
    }

    // ── bi_rakip_izle ───────────────────────────────────────────────────────
    const t2 = await colType('bi_rakip_izle', 'tenant_id');
    if (t2 === 'integer') {
      await client.query(`ALTER TABLE bi_rakip_izle ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT`);
      await client.query(`ALTER TABLE bi_rakip_izle ALTER COLUMN tenant_id SET DEFAULT '${tid}'`);
      await client.query(`UPDATE bi_rakip_izle SET tenant_id=$1 WHERE tenant_id='1'`, [tid]);
      console.log('✓ bi_rakip_izle.tenant_id: INTEGER → TEXT');
    } else {
      console.log('— bi_rakip_izle.tenant_id zaten TEXT, atlanıyor');
    }

    // ── bi_rakip_fiyat_alarm ────────────────────────────────────────────────
    const t3 = await colType('bi_rakip_fiyat_alarm', 'tenant_id');
    if (t3 === 'integer') {
      await client.query(`ALTER TABLE bi_rakip_fiyat_alarm ALTER COLUMN tenant_id TYPE TEXT USING tenant_id::TEXT`);
      await client.query(`ALTER TABLE bi_rakip_fiyat_alarm ALTER COLUMN tenant_id SET DEFAULT '${tid}'`);
      await client.query(`UPDATE bi_rakip_fiyat_alarm SET tenant_id=$1 WHERE tenant_id='1'`, [tid]);
      console.log('✓ bi_rakip_fiyat_alarm.tenant_id: INTEGER → TEXT');
    } else {
      console.log('— bi_rakip_fiyat_alarm.tenant_id zaten TEXT, atlanıyor');
    }

    // ── bi_rakip_izle_ayar: add tenant_id + new setting keys ───────────────
    const hasCol = await colType('bi_rakip_izle_ayar', 'tenant_id');
    if (!hasCol) {
      await client.query(`ALTER TABLE bi_rakip_izle_ayar ADD COLUMN IF NOT EXISTS tenant_id TEXT NOT NULL DEFAULT '${tid}'`);
      // Drop old single-key PK and add composite
      await client.query(`ALTER TABLE bi_rakip_izle_ayar DROP CONSTRAINT IF EXISTS bi_rakip_izle_ayar_pkey`);
      await client.query(`ALTER TABLE bi_rakip_izle_ayar ADD PRIMARY KEY (key, tenant_id)`);
      console.log('✓ bi_rakip_izle_ayar: tenant_id kolonu + composite PK eklendi');
    } else {
      console.log('— bi_rakip_izle_ayar.tenant_id zaten mevcut');
    }

    // Seed new setting keys (idempotent)
    const seedKeys = [
      ['alarm_esigi_varsayilan', '10.0'],
      ['max_izle_sayisi',        '50'],
      ['scraping_aktif',         'true'],
      ['scraping_sikligi',       '3'],
      ['scraping_saatleri',      '08:00,13:00,18:00'],
      ['scraping_markalar',      'Continental,Bridgestone,Michelin,Lassa,Pirelli'],
      ['scraping_kaynaklar',     'lastikborsasi,lastiksepeti,n11'],
    ];
    for (const [key, value] of seedKeys) {
      try {
        await client.query(
          `INSERT INTO bi_rakip_izle_ayar (key, value, tenant_id)
             VALUES ($1, $2, $3)
             ON CONFLICT (key, tenant_id) DO NOTHING`,
          [key, value, tid]
        );
      } catch (_) {
        // Pre-migration fallback (single PK)
        await client.query(
          `INSERT INTO bi_rakip_izle_ayar (key, value) VALUES ($1, $2) ON CONFLICT (key) DO NOTHING`,
          [key, value]
        );
      }
    }
    console.log('✓ bi_rakip_izle_ayar: varsayılan ayarlar eklendi');

    await client.query('COMMIT');
    console.log('\n✓ Migration tamamlandı. Tenant UUID:', tid);
  } catch (e) {
    await client.query('ROLLBACK');
    console.error('✗ HATA — rollback yapıldı:', e.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
