#!/usr/bin/env python3
# MUSTERI_HATIRLATMA_DUZENLE_V1 (server) — Ozellik (Eftal Yildiz 03.08): Musteri Kartindaki
#   "Hareketler" listesinde bir hatirlatmaya (saha_sinyal not/takip) tiklayinca o kayda gidip
#   duzenleyebilme (metin + takip tarihi + tamamla). Mevcut: saha_sinyal not/takip kayitlari
#   /olaylar timeline'inda gorunuyor ama (a) client'a id donmuyor, (b) duzenleme/kapatma ucu YOK
#   (detay.kapandi sadece OKUNUYOR, hicbir yerde set edilmiyordu).
#   Fix:
#     1) /olaylar sinyal sorgusuna id ekle + push()'a extra alan (sid/sozet/stakip) tasi.
#     2) Yeni uc: PUT /api/saha/sinyal/:id -> ozet + detay.takip_tarihi + detay.kapandi guncelle.
#   Idempotent (marker: MUSTERI_HATIRLATMA_DUZENLE_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_HATIRLATMA_DUZENLE_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# 1a) push() closure: extra alan destegi (sadece /olaylar icindeki tanim)
old_push = '''      const push = (ts, tip, ikon, baslik, alt, kim) => { if (ts) ev.push({ ts: (ts instanceof Date ? ts.toISOString() : ts), tip, ikon, baslik, alt: alt || null, kim: kim || null }); };'''
new_push = '''      const push = (ts, tip, ikon, baslik, alt, kim, extra) => { if (ts) ev.push({ ts: (ts instanceof Date ? ts.toISOString() : ts), tip, ikon, baslik, alt: alt || null, kim: kim || null, ...(extra || {}) }); };  /* ''' + MARK + ''' */'''
if old_push not in src:
    print("HATA: push() closure anchor bulunamadi"); sys.exit(1)
src = src.replace(old_push, new_push, 1)
print("[+] push() extra alan destegi eklendi")

# 1b) sinyal sorgusu: id ekle
old_sigq = '''      const sig = await q(`SELECT created_at ts, tip, onem, ozet, rep_id::text rid, detay FROM saha_sinyal
          WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY created_at DESC LIMIT 25`, [tid, mid]);'''
new_sigq = '''      const sig = await q(`SELECT id, created_at ts, tip, onem, ozet, rep_id::text rid, detay FROM saha_sinyal
          WHERE tenant_id=$1 AND musteri_id=$2 ORDER BY created_at DESC LIMIT 25`, [tid, mid]);'''
if old_sigq not in src:
    print("HATA: sinyal SELECT anchor bulunamadi"); sys.exit(1)
src = src.replace(old_sigq, new_sigq, 1)
print("[+] sinyal sorgusuna id eklendi")

# 1c) sinyal push cagrisi: sid/sozet/stakip tasi
old_sigp = '''        push(x.ts, isNot ? "not" : x.tip, ik, (isNot ? "Not — " : (x.tip + " — ")) + String(x.ozet || "").slice(0, 130), takip ? "· takip" : null, x.rid); });'''
new_sigp = '''        push(x.ts, isNot ? "not" : x.tip, ik, (isNot ? "Not — " : (x.tip + " — ")) + String(x.ozet || "").slice(0, 130), takip ? "· takip" : null, x.rid, { sid: x.id, sozet: x.ozet || "", stakip: (x.detay && x.detay.takip_tarihi) || null, skapandi: !!(x.detay && x.detay.kapandi) }); });  /* ''' + MARK + ''' */'''
if old_sigp not in src:
    print("HATA: sinyal push cagri anchor bulunamadi"); sys.exit(1)
src = src.replace(old_sigp, new_sigp, 1)
print("[+] sinyal push cagrisina sid/sozet/stakip eklendi")

# 2) Yeni uc: PUT /api/saha/sinyal/:id (Musteri olustur handler'indan once)
anchor = '''    // ── Müşteri oluştur (ERP seçiminden veya sıfırdan) ──
    if (method === "POST" && path === "/api/saha/musteriler") {'''
endpoint = '''    // ── ''' + MARK + ''' — saha_sinyal (not/takip) düzenle: metin + takip tarihi + tamamla ──
    if ((method === "PUT" || method === "PATCH") && (m = path.match(new RegExp(`^/api/saha/sinyal/(${SAHA_UUID_RE})$`)))) {
      const session = await requireSahaAccess(request);
      const tid = session.tenantId, uid = session.userId, sid = m[1];
      const cur = await query(`SELECT id, musteri_id::text mid, tip, ozet, detay FROM saha_sinyal WHERE tenant_id=$1 AND id=$2`, [tid, sid]);
      if (!cur.rowCount) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      const row = cur.rows[0];
      if (row.mid && !(await _sahaScopeGuard(session, row.mid))) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      const b = await readJson(request);
      const detay = (row.detay && typeof row.detay === "object") ? row.detay : {};
      // tamamla (kapat) / geri aç
      if (b.tamamla === true || b.kapandi === true) {
        detay.kapandi = true; detay.kapatan = uid; detay.kapatma_ts = new Date().toISOString();
      } else if (b.tamamla === false || b.kapandi === false) {
        detay.kapandi = false; delete detay.kapatan; delete detay.kapatma_ts;
      }
      // metin
      let ozet = row.ozet;
      if (typeof b.metin === "string" || typeof b.ozet === "string") {
        ozet = (b.metin != null ? b.metin : b.ozet).toString().trim().slice(0, 400);
        if (!ozet) { sendJson(response, 400, { error: "Not metni boş olamaz." }); return; }
      }
      // takip tarihi (YYYY-MM-DD; boş → takibi kaldır)
      let tip = row.tip;
      if (b.takip_tarihi !== undefined) {
        const t = (b.takip_tarihi || "").toString().slice(0, 10);
        if (t) { detay.takip_tarihi = t; if (tip === "not" || !tip) tip = "takip"; }
        else { delete detay.takip_tarihi; if (tip === "takip") tip = "not"; }
      }
      await query(`UPDATE saha_sinyal SET ozet=$3, detay=$4::jsonb, tip=$5 WHERE tenant_id=$1 AND id=$2`,
        [tid, sid, ozet, JSON.stringify(detay), tip]);
      try {
        await query(`INSERT INTO saha_musteri_aksiyon (tenant_id,musteri_id,rapor,tur,aktor_id,aktor_rol,gerekce_metin)
            VALUES ($1,$2,$3,'NOT',$4,$5,$6)`,
          [tid, row.mid, detay.kapandi ? "hatirlatma-tamam" : "hatirlatma-guncelle", uid, session.sahaRole || "rep", String(ozet || "").slice(0, 200)]);
      } catch (e) { console.error("[sinyal duzenle aksiyon]", e && e.message); }
      sendJson(response, 200, { ok: true, id: sid, tip, kapandi: !!detay.kapandi });
      return;
    }

'''
if anchor not in src:
    print("HATA: 'Müşteri oluştur' anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor, endpoint + anchor, 1)
print("[+] PUT /api/saha/sinyal/:id ucu eklendi")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
