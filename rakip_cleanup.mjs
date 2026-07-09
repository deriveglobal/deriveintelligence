#!/usr/bin/env node
import pg from 'pg';
const { Pool } = pg;
const p = new Pool({ connectionString: process.env.DATABASE_URL });

(async () => {
  // 1. lastix + lastiksiparis sil
  const r1 = await p.query(`DELETE FROM bi_rakip_fiyat WHERE kaynak IN ('lastix','lastiksiparis') RETURNING id`);
  console.log('✓ Silindi:', r1.rowCount, 'kayıt (lastix + lastiksiparis)');

  // 2. Trendyol 4'lü takım fiyatlarını sil
  const r2 = await p.query(`DELETE FROM bi_rakip_fiyat WHERE kaynak='trendyol' AND (UPPER(ebat) LIKE '%TAKIM%' OR UPPER(model) LIKE '%TAKIM%') RETURNING id`);
  console.log('✓ Silindi:', r2.rowCount, "trendyol 4'lü takım kaydı");

  // 3. View'u yeniden oluştur
  await p.query(`
    CREATE OR REPLACE VIEW bi_rakip_fiyat_son AS
    SELECT DISTINCT ON (kaynak, marka, ebat, tenant_id)
      id, kaynak, marka, ebat, model, genislik, profil, cap,
      fiyat, stok, url, satici_sayisi, yorum_sayisi, puan,
      scraped_at, tenant_id
    FROM bi_rakip_fiyat
    ORDER BY kaynak, marka, ebat, tenant_id, scraped_at DESC
  `);
  console.log('✓ bi_rakip_fiyat_son view yeniden oluşturuldu');

  // 4. Güncel durum
  const r3 = await p.query(`SELECT kaynak, COUNT(*) as adet FROM bi_rakip_fiyat GROUP BY kaynak ORDER BY adet DESC`);
  console.log('\n=== Güncel durum ===');
  r3.rows.forEach(x => console.log(x.kaynak.padEnd(20), x.adet));

  process.exit(0);
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
