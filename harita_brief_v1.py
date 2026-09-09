#!/usr/bin/env python3
# HARITA_BRIEF_V1 — pin balonu icin hafif AI ziyaret ozeti.
#   GET /api/saha/harita-musteri-brief?id=<saha_musteri_id> -> o musterinin son ziyaret notlarindan
#   kisa yonetici ozeti + 2-3 aksiyon (claude-sonnet-4-6). saha-sesi deseni, ama popup icin hafif.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "HARITA_BRIEF_V1" in s:
    print("brief-ep: already present, skip"); print("DONE."); raise SystemExit

A = '    if (method === "GET" && path === "/api/saha/harita-musteri-ozet") { /* HARITA_MUSTERI_OZET_V1 */\n'
assert s.count(A) == 1, "harita-musteri-ozet anchor (count!=1)"

N = (
    '    if (method === "GET" && path === "/api/saha/harita-musteri-brief") { /* HARITA_BRIEF_V1 */\n'
    '      const session = await requireSahaAccess(request, ["manager","admin"]);\n'
    '      const bid = (new URL(request.url, "http://x").searchParams.get("id") || "");\n'
    '      if (!bid) { sendJson(response, 400, { error: "id zorunlu" }); return; }\n'
    '      const mr = (await query("SELECT firma, il, ilce, durum FROM saha_musteri WHERE tenant_id=$1 AND id=$2", [session.tenantId, bid])).rows[0];\n'
    '      if (!mr) { sendJson(response, 404, { error: "musteri yok" }); return; }\n'
    '      const nt = (await query("SELECT z.ziyaret_tarihi, COALESCE(u.full_name, z.rep_adi, \'?\') rep, z.notlar FROM saha_ziyaret z LEFT JOIN users u ON u.id=z.rep_id WHERE z.tenant_id=$1 AND z.musteri_id=$2 AND z.durum=\'TAMAMLANDI\' AND z.notlar IS NOT NULL AND z.notlar<>\'\' ORDER BY z.ziyaret_tarihi DESC NULLS LAST LIMIT 15", [session.tenantId, bid])).rows;\n'
    '      if (!nt.length) { sendJson(response, 200, { brief: "Bu musteride not girilmis ziyaret yok - ozet icin once saha notu gerekiyor.", aksiyonlar: [], not_sayisi: 0 }); return; }\n'
    '      const notMetni = nt.map(n => "[" + (n.ziyaret_tarihi ? new Date(n.ziyaret_tarihi).toLocaleDateString("tr-TR") : "?") + "] " + n.rep + ": " + String(n.notlar).slice(0, 300)).join("\\n");\n'
    '      const bprompt = "Sen KRB (lastik distributoru) saha analistisin. Asagida \\"" + (mr.firma || "") + "\\" musterisinin son ziyaret notlari var. Bu notlardan kisa, yonetici icin bir DURUM OZETI cikar.\\n\\nZIYARET NOTLARI:\\n" + notMetni + "\\n\\nSadece gecerli JSON dondur (markdown yok):\\n{\\"ozet\\":\\"3-4 cumle: bu musteride ne oluyor - iliski, fiyat/rakip baskisi, firsat/risk, son durum\\",\\"aksiyonlar\\":[\\"somut aksiyon\\"]}\\nAksiyon en fazla 3, notlardaki gercek gozlemlere dayansin.";\n'
    '      try {\n'
    '        const aiMsg = await anthropic.messages.create({ model: "claude-sonnet-4-6", max_tokens: 700, messages: [{ role: "user", content: bprompt }] });\n'
    '        let parsed = null;\n'
    '        try { const raw = (aiMsg.content[0] && aiMsg.content[0].text || "").replace(/^```json\\s*/m,"").replace(/^```\\s*/m,"").replace(/\\n?```\\s*$/,"").trim(); parsed = JSON.parse(raw); } catch (_) {}\n'
    '        if (parsed && parsed.ozet) { sendJson(response, 200, { brief: parsed.ozet, aksiyonlar: Array.isArray(parsed.aksiyonlar) ? parsed.aksiyonlar.slice(0,3) : [], not_sayisi: nt.length }); }\n'
    '        else { sendJson(response, 200, { brief: (aiMsg.content[0] && aiMsg.content[0].text) || "Ozet olusturulamadi.", aksiyonlar: [], not_sayisi: nt.length }); }\n'
    '      } catch (e) { console.error("[harita-brief]", e && e.message); sendJson(response, 500, { error: "AI ozeti alinamadi" }); }\n'
    '      return;\n'
    '    }\n\n'
)
s = s.replace(A, N + A, 1)
write(FP, s)
print("brief-ep: /api/saha/harita-musteri-brief eklendi")
print("marker count:", s.count("HARITA_BRIEF_V1"))
print("DONE.")
