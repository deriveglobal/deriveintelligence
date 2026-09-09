import sys, io
p = sys.argv[1]; s = io.open(p, encoding="utf-8").read()
if "ZIYARET_TARIH_GUARD_V1" in s:
    print("[patch_ziyaret_tarih_server] zaten uygulanmis, atlaniyor."); sys.exit(0)
OLD = '''      if (!mus.rowCount) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }
      const tamamla = p.tamamla === true;'''
NEW = OLD + '''
      // ZIYARET_TARIH_GUARD_V1 — tamamlanan ziyaret ileri (gelecek) tarihli olamaz (kirli veri korumasi)
      if (tamamla) {
        const _bugunTR = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
        if (String(p.ziyaret_tarihi || _bugunTR) > _bugunTR) { sendJson(response, 400, { error: "Ziyaret tarihi ileri (gelecek) tarihli olamaz." }); return; }
      }'''
if s.count(OLD) != 1:
    sys.stderr.write("[server] HATA anchor=%d (1 bekleniyordu)\n" % s.count(OLD)); sys.exit(2)
io.open(p,"w",encoding="utf-8").write(s.replace(OLD,NEW,1))
print("[patch_ziyaret_tarih_server] uygulandi.")
