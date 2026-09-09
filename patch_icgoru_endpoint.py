#!/usr/bin/env python3
# OMURGA 55 — içgörü servisi endpoint'leri: GET /api/bi/icgoru (oku) + POST /api/bi/icgoru-yenile (motor+LLM)
import re, sys
F="server_container.mjs"; s=open(F,encoding="utf-8").read()
if "/api/bi/icgoru-yenile" in s:
    print("  ⏭ zaten var"); sys.exit(0)
m=re.search(r"^[ \t]*if \(request\.method === 'GET' && url\.pathname === '/api/bi/yukle/durum'\) \{", s, re.M)
if not m:
    print("  ❌ çapa yok"); sys.exit(1)
pos=m.start()

block = r'''    // İÇGÖRÜ SERVİSİ (omurga_55) — kalıcı, UI-bağımsız. Cockpit bunu tüketir.
    if (request.method === 'GET' && url.pathname === '/api/bi/icgoru') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const r = await query(`SELECT id, kanit->>'marka' AS marka, tip, ozet, anlati, oneri, guven, kaynak, surpriz_skoru, kanit
          FROM bi_icgoru WHERE tenant_id=$1::uuid AND bolum='marka-marj' AND durum='yeni' AND anlati IS NOT NULL
          ORDER BY surpriz_skoru DESC LIMIT 20`, [session.tenantId]);
        sendJson(response, 200, { icgoruler: r.rows });
      } catch (e) { console.error("[icgoru]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/bi/icgoru-yenile') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        await query(`SELECT icgoru_uret_finans($1::uuid)`, [T]);
        const rows = (await query(`SELECT id, kanit->>'marka' AS marka FROM bi_icgoru
          WHERE tenant_id=$1::uuid AND bolum='marka-marj' AND durum='yeni' AND anlati IS NULL
          ORDER BY surpriz_skoru DESC`, [T])).rows;
        const SYS = `Sen KRB adlı lastik toptancısının finans analistisin. İşletme sahibine bir markanın kâr marjı analizini anlatıyorsun.
Sana JSON verilecek. İçindeki "bulgular" listesi markaya ait DOĞRU ve KANITLI tespit cümleleridir.
Görevin: bunları doğal, akıcı Türkçe ile KISA (3-5 cümle) tek paragraf olarak, analist ağzıyla YENİDEN anlatmak.
KATI KURALLAR:
- SADECE bulgulardaki bilgiyi ve sayıları kullan. ASLA yeni sayı/oran/tarih/faktör UYDURMA. Bulgularda olmayan hiçbir rakamı veya yeni bir kalem EKLEME.
- Her markayı FARKLI kur; sabit şablon/sıra kullanma. En ağır etkenle başla.
- "guven" kismi ise temkinli konuş. Bir bulgu "seri kısa/kesin değil" diyorsa bunu koru.
- "saha_ipuclari" varsa "sahadan gelen, doğrulanması gereken sinyal" diye ver; yoksa sahadan hiç bahsetme.
- "tesvik_notu" varsa kısaca ekle. "cozulemeyen" doluysa "şu kısmı netleştiremedim, sana sormak isterim" de.
- Madde işareti/etiket/başlık YOK; düz paragraf. Sayıları Türkçe yaz (%13,9 gibi).`;
        let yaz = 0;
        for (const row of rows) {
          try {
            const sj = await query(`SELECT sebep_arastir_marj($1::uuid,$2) AS j`, [T, row.marka]);
            const j = (sj.rows[0] && sj.rows[0].j) || {};
            const facts = j.facts || {};
            const msg = await anthropic.messages.create({ model: "claude-sonnet-4-6", max_tokens: 450,
              messages: [{ role: "user", content: SYS + "\n\nJSON:\n" + JSON.stringify(facts) + "\n\nSadece anlatı paragrafını yaz." }] });
            const anlati = ((msg.content && msg.content[0] && msg.content[0].text) || "").trim();
            if (anlati) { await query(`UPDATE bi_icgoru SET anlati=$2, oneri=$3, guven=$4, kaynak='ai-taslak', anlati_at=now() WHERE id=$1`,
              [row.id, anlati, j.oneri || null, j.guven || 'yaklasik']); yaz++; }
          } catch (e) { console.error("[icgoru-anlat]", row.marka, e && e.message); }
        }
        sendJson(response, 200, { secilen: rows.length, anlatilan: yaz });
      } catch (e) { console.error("[icgoru-yenile]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }

'''
s = s[:pos] + block + s[pos:]
open(F,"w",encoding="utf-8").write(s)
print("  ✅ GET /api/bi/icgoru + POST /api/bi/icgoru-yenile eklendi")
