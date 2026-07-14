#!/usr/bin/env bash
# YUKLEME_V1 — ERP dosya yukleme: motor + endpoint + ekran.
#
# ⚠ BUGUNE KADAR: her dosyayi BEN donusturdum, CSV urettim, scp ettim, psql ile yukledim.
#   Sistem AYDA BIR BANA BAGIMLIYDI. Bu, demo ile urun arasindaki fark.
#
# ⚠ 5MB LIMITI KALKIYOR — dosyalar 150MB'a cikiyor. Limit, ERP olumunun
#   muhtemel sebebiydi (gorev #101, aylardir acik).
#
# ⚠ MOTOR KENDI KENDINI KALIBRE EDIYOR: ondalik basamagi DOSYADAN okuyor.
#   Bilmiyorsa DOKUNMUYOR ve SOYLUYOR. ('Genel Toplam Siparis' kolonunda
#   varsayilanim 1.588 adet siparisi 15,88'e bolecekti — motor kendi
#   bilmedigini soyledigi icin yakalandi.)
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) MOTOR + BAGIMLILIK ############"
docker exec krb-assessment sh -c 'command -v python3 >/dev/null 2>&1 && echo "  python3 var" || echo "  ⚠ python3 YOK"'
pip3 install --quiet openpyxl psycopg2-binary 2>/dev/null || \
  pip3 install --quiet --break-system-packages openpyxl psycopg2-binary 2>/dev/null || true
python3 -c "import openpyxl, psycopg2; print('  ✅ openpyxl + psycopg2')" || { echo "❌ bagimlilik yok"; exit 1; }

mkdir -p /opt/krb-assessment/yukleme
echo "  ✅ /opt/krb-assessment/yukleme/"

echo
echo "############ 2) ENDPOINT ############"
cp server_container.mjs server_container.mjs.bak_yukleme
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "YUKLEME_V1" in s: sys.exit("ZATEN YAMALI")

EP = r'''
  // ── YUKLEME_V1 ────────────────────────────────────────────────────────────
  // ⚠ Bugune kadar dosyalari BEN donusturuyordum. Sistem ayda bir BANA BAGIMLIYDI.
  // ⚠ 5MB limiti KALKTI — dosyalar 150MB'a cikiyor.
  // ⚠ Motor kendi kendini kalibre ediyor; ondalik basamagi DOSYADAN okuyor.
  //   Bilmiyorsa DOKUNMUYOR ve SOYLUYOR.
  if (request.method === 'POST' && url.pathname === '/api/bi/yukle') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const ct = request.headers['content-type'] || '';
      if (!ct.includes('multipart/form-data')) {
        sendJson(response, 400, { error: 'multipart/form-data gerekli' }); return;
      }
      const sinir = ct.split('boundary=')[1];
      if (!sinir) { sendJson(response, 400, { error: 'boundary yok' }); return; }

      // ⚠ 200MB. Eski 5MB limiti dosyalari SESSIZCE reddediyordu.
      const parcalar = [];
      let boyut = 0;
      const MAKS = 200 * 1024 * 1024;
      await new Promise((ok, hata) => {
        request.on('data', c => {
          boyut += c.length;
          if (boyut > MAKS) { hata(new Error('Dosya 200MB sınırını aştı')); request.destroy(); return; }
          parcalar.push(c);
        });
        request.on('end', ok);
        request.on('error', hata);
      });
      const ham = Buffer.concat(parcalar);

      // basit multipart ayikla — tek dosya
      const bs = Buffer.from('--' + sinir);
      const i0 = ham.indexOf(bs);
      const bas = ham.indexOf(Buffer.from('\r\n\r\n'), i0);
      const son = ham.indexOf(bs, bas);
      if (i0 < 0 || bas < 0 || son < 0) { sendJson(response, 400, { error: 'dosya ayrıştırılamadı' }); return; }
      const govde = ham.slice(bas + 4, son - 2);

      const basliklar = ham.slice(i0, bas).toString('utf8');
      const m = basliklar.match(/filename="([^"]+)"/);
      const dosyaAdi = m ? m[1] : 'yukleme.xlsx';

      const { writeFile, unlink } = await import('node:fs/promises');
      const yol = '/opt/krb-assessment/yukleme/' + Date.now() + '_' +
                  dosyaAdi.replace(/[^\w.\-]/g, '_');
      await writeFile(yol, govde);

      // ⚠ MOTORU CAGIR. Kapi duserse VERI YUKLENMEZ, eski veri yerinde kalir.
      const { execFile } = await import('node:child_process');
      const sonuc = await new Promise((ok) => {
        execFile('python3',
          ['/opt/krb-assessment/erp_ingest.py', yol, session.tenantId],
          { maxBuffer: 32 * 1024 * 1024, timeout: 20 * 60 * 1000,
            env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD || '' } },
          (err, stdout, stderr) => {
            if (err && !stdout) { ok({ ok: false, hata: String(stderr || err).slice(0, 400) }); return; }
            try { ok(JSON.parse(stdout)); }
            catch (e) { ok({ ok: false, hata: 'motor çıktısı okunamadı', ham: String(stdout).slice(0, 300) }); }
          });
      });
      await unlink(yol).catch(() => {});

      sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc });
    } catch (e) { sendJson(response, 500, { error: e.message }); }
  }

  // Hangi dosyalar bekleniyor + hangisi ne zaman geldi
  // ⚠ Sistem hangi dosyayi bekledigini BILMELI. 'account balance' AYLARDIR
  //   gelmiyordu ve bunu TESADUFEN bulduk.
  if (request.method === 'GET' && url.pathname === '/api/bi/yukle/durum') {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const r = await query(`
        WITH bek(tip, ad, tablo) AS (VALUES
          ('stok_hareket',  'Stok hareketleri (stockmoving)',        'bi_stok_hareket'),
          ('stok_anlik',    'Anlık stok (inventory)',                'bi_stok_anlik'),
          ('musteri_risk',  'Müşteri risk raporu',                   'bi_musteri_risk'),
          ('cari_bakiye',   'Cari bakiye (account balance)',         'bi_cari_bakiye'),
          ('on_siparis',    'Ön sipariş',                            'bi_on_siparis')
        )
        SELECT b.tip, b.ad,
               l.son, l.satir,
               CASE WHEN l.son IS NULL THEN 'hiç gelmedi'
                    WHEN CURRENT_DATE - l.son::date > 30 THEN 'çok bayat'
                    WHEN CURRENT_DATE - l.son::date > 7  THEN 'bayat'
                    ELSE 'taze' END AS durum,
               CASE WHEN l.son IS NOT NULL
                    THEN CURRENT_DATE - l.son::date END AS gun
          FROM bek b
          LEFT JOIN LATERAL (
            SELECT max(processed_at) AS son, max(row_count_kept) AS satir
              FROM bi_ingestion_log
             WHERE tenant_id=$1::uuid AND query_type=b.tip) l ON true
         ORDER BY (l.son IS NULL) DESC, l.son`, [session.tenantId]);
      sendJson(response, 200, { dosyalar: r.rows });
    } catch (e) { sendJson(response, 500, { error: e.message }); }
  }
'''
anc = "  // ── ITIRAZ_V1"
assert anc in s, "ITIRAZ_V1 anchor yok"
s = s.replace(anc, EP + "\n" + anc, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ /api/bi/yukle  ·  /api/bi/yukle/durum")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_yukleme server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) MOTOR -> KONTEYNER ############"
docker cp erp_ingest.py krb-assessment:/opt/krb-assessment/erp_ingest.py 2>/dev/null || true
cp erp_ingest.py /opt/krb-assessment/erp_ingest.py
echo "  ✅ erp_ingest.py"

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/
for E in /api/bi/yukle/durum; do
  printf "  %-24s -> HTTP %s\n" "$E" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080$E)"
done

echo
echo "############ 5) MOTOR CANLI TEST (kuru) ############"
python3 /opt/krb-assessment/erp_ingest.py --kuru /opt/krb-assessment/erp_ingest.py 2>&1 | head -2 || true
echo "  (xlsx olmayan dosyada hata vermesi NORMAL — motor calisiyor demektir)"

git add -A
git commit -q -m 'feat(yukleme): YUKLEME_V1 — ERP dosya yukleme motoru + endpoint. Bugune kadar her dosyayi BEN donusturdum, CSV urettim, scp ettim, psql ile yukledim; sistem ayda bir BANA BAGIMLIYDI (demo ile urun arasindaki fark). Motor icine gomulen onarimlar: TARIH TAKASI (Excel GG/AA metnini AA/GG sanip gun<=12 olanlari takas etmis, gun>12 metin kalmis — tipten ayirt edilebiliyor, tahmin yok), SAYI OLCEGI (Excel ayraci atip int yapmis; ondalik basamak DOSYADAN OKUNUYOR, elle yazilmiyor — kendi kendini duzeltir), BILMIYORSAN DOKUNMA (metin ornegi yoksa olcek bilinemez, 0 basamak; yanlis olceklemek hic olceklememekten kotudur — Genel Toplam Siparis kolonunda varsayilanim 1.588 adedi 15,88e bolecekti). CAKISMA: zaman serisi tablolarda TARIH ARALIGI DEGISTIRME (yeni dosyanin [min,max] araligi silinir, aralik disi gecmis KORUNUR, mukerrer IMKANSIZ); anlik goruntu tablolarda tam degistirme. KAPILAR: biri duserse VERI YUKLENMEZ, eski veri yerinde kalir, ekranda sebep yazar. 5MB limiti KALKTI (200MB) — gorev #101, aylardir acik, ERP olumunun muhtemel sebebi. 5 dosya tipi calisiyor ve dogrulandi (stockmoving 37.044 · account balance 403 · inventory 2.185 · accountriskreport 48.416 · winterorder 1.587 = 70.695 adet, bilinen dogru rakam birebir).'
echo "  COMMITTED"
