#!/usr/bin/env python3
"""
restore_rakip_handlers.py
Her saha handler'ı kapanan '}' bloğundan sonra
tam /api/rakip/piyasa handler'ını (EBAT_CONCAT_V1 ile) yeniden ekler.
"""

SRC = '/opt/krb-assessment/server_container.mjs'
DST_CONTAINER = '/opt/krb-assessment/server_container.mjs'
DST_HOST      = '/opt/krb-assessment/server.mjs'

with open(SRC, 'r', encoding='utf-8') as f:
    src = f.read()

# Saha handler'larının benzersiz bitiş deseni
SAHA_END = """    sendJson(response, 404, { error: "Bilinmeyen saha endpoint'i." });
  } catch (e) {
    sendJson(response, e.statusCode || 500, { error: e.message });
  }
}"""

# Tam /api/rakip/piyasa handler — EBAT_CONCAT_V1 ile
D = chr(36)  # $ karakteri — Python string sorunlarını önler
HANDLER = f"""
  // GET /api/rakip/piyasa — RAKIP_PIYASA_RESTORED_V1
  if (request.method === 'GET' && url.pathname === '/api/rakip/piyasa') {{
    const marka = (url.searchParams.get('marka') || '').trim();
    const ebat  = (url.searchParams.get('ebat')  || '').trim();
    const limit = Math.min(parseInt(url.searchParams.get('limit') || '200', 10), 500);
    const where = []; const vals = [];
    if (marka) {{ vals.push('%' + marka + '%'); where.push('marka ILIKE {D}' + vals.length); }}
    if (ebat)  {{ vals.push("%" + ebat + "%"); where.push("(ebat ILIKE {D}" + vals.length + " OR CONCAT(genislik,'/',profil,'R',cap) ILIKE {D}" + vals.length + ")"); }} // EBAT_CONCAT_V1
    const clause = where.length ? 'WHERE ' + where.join(' AND ') : '';
    vals.push(limit);
    const {{ rows }} = await pool.query(
      'SELECT kaynak, marka, model, ebat, genislik, profil, cap, fiyat, stok, url,' +
      ' satici_sayisi, yorum_sayisi, puan, scraped_at' +
      ' FROM bi_rakip_fiyat_son ' + clause +
      ' ORDER BY ebat, marka, fiyat LIMIT {D}' + vals.length,
      vals
    );
    sendJson(response, 200, {{ rows }}); return;
  }}"""

count = src.count(SAHA_END)
print(f'Saha handler sonu bulundu: {count} adet')

if count == 0:
    print('x Desen bulunamadı — kontrol et')
    exit(1)

# Her saha handler bitişinden sonra handler'ı ekle
src = src.replace(SAHA_END, SAHA_END + HANDLER)

with open(DST_CONTAINER, 'w', encoding='utf-8') as f:
    f.write(src)
with open(DST_HOST, 'w', encoding='utf-8') as f:
    f.write(src)

print(f'OK — {count} adet /api/rakip/piyasa handler eklendi (RAKIP_PIYASA_RESTORED_V1)')
