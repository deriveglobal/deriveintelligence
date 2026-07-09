import pg from 'pg';
const { Pool } = pg;
const p = new Pool({ connectionString: process.env.DATABASE_URL });

(async () => {
  const r1 = await p.query(`
    SELECT
      COUNT(*) as toplam,
      COUNT(satici_sayisi) as satici_dolu,
      MIN(satici_sayisi) as min_satici,
      MAX(satici_sayisi) as max_satici,
      AVG(satici_sayisi)::int as ort_satici
    FROM bi_rakip_fiyat WHERE kaynak='akakce'
  `);
  const s = r1.rows[0];
  console.log('Toplam kayıt:  ', s.toplam);
  console.log('Satıcı dolu:   ', s.satici_dolu, '/', s.toplam);
  console.log('Min satıcı:    ', s.min_satici);
  console.log('Max satıcı:    ', s.max_satici);
  console.log('Ort satıcı:    ', s.ort_satici);

  const r2 = await p.query(`
    SELECT marka, ebat, fiyat, satici_sayisi
    FROM bi_rakip_fiyat
    WHERE kaynak='akakce' AND satici_sayisi IS NOT NULL
    ORDER BY satici_sayisi DESC LIMIT 10
  `);
  console.log('\n=== En çok satıcılı ürünler ===');
  r2.rows.forEach(x =>
    console.log(
      String(x.satici_sayisi).padStart(4) + ' satıcı | ' +
      x.marka.padEnd(12) + ' | ' +
      x.ebat.substring(0, 40).padEnd(40) + ' | ' +
      x.fiyat + ' TL'
    )
  );
  process.exit(0);
})().catch(e => { console.error('HATA:', e.message); process.exit(1); });
