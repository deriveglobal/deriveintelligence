# -*- coding: utf-8 -*-
# SAHA_SOR_V1 — bağlamsal sohbet motoru: POST /api/saha/ai/sor
#   Herhangi bir metrik/müşteri bağlamıyla rep beyinle konuşur; her soru+cevap saha_sinyal'e
#   akar (öğrenme/moat). Mevcut anthropic (sonnet-4-6) + saha_sinyal deseni (satır 31990) birebir.
#   Anchor: saha-sesi GET rotasının hemen öncesi. Idempotent, .sorbak yedekli.
import io, os, sys
BASE = sys.argv[1] if len(sys.argv) > 1 else "."
REL  = "server_container.mjs"
MARK = "SAHA_SOR_V1"
path = os.path.join(BASE, REL)
with io.open(path, encoding="utf-8") as f: orig = f.read()
if MARK in orig:
    print("SKIP (zaten var):", REL); raise SystemExit

ANCHOR = '    if (method === "GET" && path === "/api/saha/ai/saha-sesi") {'
assert orig.count(ANCHOR) == 1, "anchor=%d" % orig.count(ANCHOR)

NEW = r'''    /* SAHA_SOR_V1 — bağlamsal sohbet: her metrik/müşteride "sor/konuş"; cevap + saha_sinyal öğrenme izi */
    if (method === "POST" && path === "/api/saha/ai/sor") {
      const session = await requireSahaAccess(request);
      let body = {};
      try { body = await readJson(request); } catch (e) { body = {}; }
      const soru = (body.soru == null ? "" : String(body.soru)).trim().slice(0, 2000);
      if (!soru) { sendJson(response, 400, { error: "Soru boş." }); return; }
      const baglam   = (body.baglam == null ? "" : String(body.baglam)).slice(0, 6000);
      const ekran    = (body.ekran == null ? "" : String(body.ekran)).slice(0, 60);
      const hedefTip = (body.hedef_tip == null ? "" : String(body.hedef_tip)).slice(0, 40);
      const hedefRef = (body.hedef_ref == null ? "" : String(body.hedef_ref)).slice(0, 120);
      const gecmis   = Array.isArray(body.gecmis) ? body.gecmis.slice(-6) : [];
      const SYS = "Sen KRB saha satış zekâsının asistanısın. Rep'in açık olduğu ekrandaki metrik/müşteri BAĞLAMINI bilerek konuşursun. Kurallar: kısa ve net (2-5 cümle), doğal Türkçe, satışçıya yol gösteren ton; SAYI UYDURMA — yalnız verilen bağlamı ve genel ticari mantığı kullan; bağlamda olmayan bir veriyi sorarsa 'bu veri elimde yok' de; abartma/vaat yok, suçlayıcı dil yok. Uygunsa tek somut sonraki adım öner.";
      const msgs = [];
      msgs.push({ role: "user", content: "BAĞLAM (" + (ekran || "portfoyum") + (hedefTip ? " · " + hedefTip : "") + "):\n" + (baglam || "(bağlam verilmedi)") });
      msgs.push({ role: "assistant", content: "Bağlamı aldım, sorunu bekliyorum." });
      for (const g of gecmis) { if (g && g.rol && g.metin) msgs.push({ role: g.rol === "user" ? "user" : "assistant", content: String(g.metin).slice(0, 2000) }); }
      msgs.push({ role: "user", content: soru });
      let cevap = "";
      try {
        const m = await anthropic.messages.create({ model: "claude-haiku-4-5-20251001", max_tokens: 600, system: SYS, messages: msgs });  /* haiku = maliyet düşük; bağlamlı kısa Q&A için yeterli */
        cevap = (m.content || []).map(function (c) { return c.text || ""; }).join("").trim();
      } catch (e) {
        sendJson(response, 502, { error: "Asistan yanıt veremedi." }); return;
      }
      if (!cevap) cevap = "Şu an bir yanıt üretemedim, tekrar dener misin?";
      // öğrenme izi — saha_sinyal (kaynak_tip='ekran_sor'); müşteri bağlamında musteri_id çöz
      try {
        let mid = null;
        if (hedefTip === "musteri" && hedefRef) {
          try { const r = await query("SELECT id FROM saha_musteri WHERE tenant_id=$1 AND (id::text=$2 OR musteri_kodu=$2) LIMIT 1", [session.tenantId, hedefRef]); mid = (r.rows[0] && r.rows[0].id) || null; } catch (e) {}
        }
        await query("INSERT INTO saha_sinyal (tenant_id,tip,onem,ozet,detay,kaynak_tip,rep_id,musteri_id,ham_metin) VALUES ($1,'soru',1,$2,$3::jsonb,'ekran_sor',$4,$5,$6)",
          [session.tenantId, soru.slice(0, 300), JSON.stringify({ ekran: ekran, hedef_tip: hedefTip, hedef_ref: hedefRef, soru: soru, cevap: cevap.slice(0, 1500) }), session.userId, mid, soru]);
      } catch (e) { try { console.error("[ai/sor sinyal]", e && e.message); } catch (er) {} }
      sendJson(response, 200, { cevap: cevap });
      return;
    }

'''

s = orig.replace(ANCHOR, NEW + ANCHOR, 1)
if not os.path.exists(path + ".sorbak"):
    with io.open(path + ".sorbak", "w", encoding="utf-8") as f: f.write(orig)
with io.open(path, "w", encoding="utf-8") as f: f.write(s)
print("OK", REL, "| MARK:", s.count(MARK))
