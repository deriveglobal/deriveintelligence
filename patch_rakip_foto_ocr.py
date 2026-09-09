# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAKIP_OCR_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) _rakipFotoCoz — fotoğraftaki rakip fiyat listesini vision ile oku → saha_rakip_teklif + sinyal
FUNC = r'''async function _rakipFotoCoz(tenantId, fotoId, ziyaretId, repId, mime, buf) {  /* RAKIP_OCR_V1 */
  try {
    if (!buf || !buf.length || buf.length > 4 * 1024 * 1024) return;
    const _mt = ["image/jpeg","image/png","image/webp","image/gif"].includes(mime) ? mime : "image/jpeg";
    const b64 = buf.toString("base64");
    const sys = "Bu bir saha satis fotografidir. EGER bir RAKIP / piyasa LASTIK FIYAT LISTESI ise her satiri cikar; degilse bos dizi dondur. SADECE JSON.\n" +
      "Cikti: {\"rakip\": \"liste sahibi rakip/firma adi (TATKO gibi) ya da null\", \"kalemler\": [{\"marka\":\"...\",\"model\":\"desen/tip ya da null\",\"ebat\":\"orn 23.5R25 ya da null\",\"birim_fiyat\": sayi_TL, \"kdv_haric\": true|false|null, \"adet\": null}]}\n" +
      "Fiyati okunamayan/olmayan satiri ATLA. Sayilari ondalik/nokta olmadan tam TL ver (115.000 -> 115000). Fiyat listesi degilse: {\"rakip\":null,\"kalemler\":[]}.";
    const msg = await anthropic.messages.create({
      model: "claude-sonnet-4-6", max_tokens: 1500,
      messages: [{ role: "user", content: [
        { type: "image", source: { type: "base64", media_type: _mt, data: b64 } },
        { type: "text", text: sys }
      ]}]
    });
    let out = (msg.content || []).filter(b => b.type === "text").map(b => b.text).join("").trim();
    const a = out.indexOf("{"), z = out.lastIndexOf("}");
    if (a < 0 || z < 0) return;
    const j = JSON.parse(out.slice(a, z + 1));
    const kalemler = Array.isArray(j.kalemler) ? j.kalemler : [];
    if (!kalemler.length) return;
    const rakipAd = j.rakip ? String(j.rakip).slice(0, 60) : null;
    const zr = await pool.query("SELECT musteri_id FROM saha_ziyaret WHERE id=$1 AND tenant_id=$2", [ziyaretId, tenantId]);
    const musteriId = zr.rows[0] ? zr.rows[0].musteri_id : null;
    let n = 0;
    for (const k of kalemler) {
      let fiyat = k.birim_fiyat != null ? Number(k.birim_fiyat) : null;
      if (fiyat == null || !isFinite(fiyat) || fiyat <= 0) continue;
      const kdvNot = k.kdv_haric === false ? " (KDV dahil)" : k.kdv_haric === true ? " (KDV haric)" : "";
      await pool.query(
        "INSERT INTO saha_rakip_teklif (tenant_id,kaynak,rakip_marka,rakip_model,ebat,rakip_fiyat,musteri_id,ziyaret_id,rep_id,notlar,created_by,dogrulanmis) " +
        "VALUES ($1,'FOTO',$2,$3,$4,$5,$6,$7,$8,$9,$8,false)",
        [tenantId, String(k.marka || rakipAd || "Bilinmiyor").slice(0,60), k.model ? String(k.model).slice(0,80) : null,
         k.ebat ? String(k.ebat).slice(0,40) : null, Math.round(fiyat), musteriId, ziyaretId, repId,
         ("[foto-okuma] " + (rakipAd ? rakipAd + " " : "") + kdvNot).slice(0, 200)]);
      n++;
    }
    if (n) {
      await pool.query(
        "INSERT INTO saha_sinyal (tenant_id,tip,onem,ozet,detay,kaynak_tip,kaynak_id,rep_id,musteri_id,owner_bildirildi) VALUES ($1,'rakip',3,$2,$3,'ziyaret_foto',$4,$5,$6,FALSE)",
        [tenantId, ("Rakip fiyat listesi fotograftan okundu: " + (rakipAd || "rakip") + " — " + n + " kalem").slice(0,500),
         JSON.stringify({ rakip: rakipAd, kalemler: kalemler.slice(0, 40) }), fotoId, repId, musteriId]);
      try { console.log("[rakip-foto] " + n + " kalem cikarildi, ziyaret " + ziyaretId); } catch (e) {}
    }
  } catch (e) { try { console.error("[rakip-foto]", e && e.message); } catch (er) {} }
}
'''
anchor = 'async function _extractIntent(text) {'
assert s.count(anchor) == 1, "extractIntent anchor count=%d" % s.count(anchor)
s = s.replace(anchor, FUNC + "\n" + anchor, 1)

# 2) Foto yükleme sonrası vision pass'i tetikle (fire-and-forget)
OLD = '''      sendJson(response, 200, { foto: result.rows[0] });
      return;
    }'''
NEW = '''      sendJson(response, 200, { foto: result.rows[0] });
      try { _rakipFotoCoz(session.tenantId, result.rows[0].id, m[1], session.userId, fotoMime, buf); } catch (e) {}  /* RAKIP_OCR_V1 */
      return;
    }'''
assert s.count(OLD) == 1, "foto upload anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAKIP_OCR_V1")
